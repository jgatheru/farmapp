import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../production/BluetoothScaleService.dart';
import 'feeding.dart';

class InventoryItem {
  final int id;
  final String name;

  InventoryItem({required this.id, required this.name});

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class ShadeForFilter {
  final int id;
  final String name;

  ShadeForFilter({required this.id, required this.name});

  factory ShadeForFilter.fromJson(Map<String, dynamic> json) {
    return ShadeForFilter(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class FeedingFormPage extends StatefulWidget {
  final Feeding? feeding;

  const FeedingFormPage({super.key, this.feeding});

  @override
  State<FeedingFormPage> createState() => _FeedingFormPageState();
}

class _FeedingFormPageState extends State<FeedingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animalController = TextEditingController();
  final TextEditingController _shadeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedFeedingDate = DateTime.now();
  int? _selectedAnimalId;
  int? _selectedShadeId;
  int? _selectedItemId;
  List<AnimalForFilter> _allAnimals = [];
  List<ShadeForFilter> _allShades = [];
  List<InventoryItem> _allInventoryItems = [];
  bool _isLoadingAnimals = false;
  bool _isLoadingShades = false;
  bool _isLoadingItems = false;
  String? _animalFetchError;
  String? _shadeFetchError;
  String? _itemFetchError;
  bool _isSaving = false;
  String _bluetoothStatus = 'Not connected';
  bool _isReadingBluetooth = false;
  StreamSubscription<double>? _weightSubscription;
  StreamSubscription<String>? _errorSubscription;
  BluetoothDevice? _connectedDevice;
  final List<double> _readings = [];
  double _totalWeight = 0.0;
  bool _isFirstWeightReceived = false;
  final _bluetoothService = BluetoothScaleService();

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/feedings/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/feedings/';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchShadesEndpoint = '${Config.baseUrl}/modules/farm/shades/';
  final String _fetchItemsEndpoint = '${Config.baseUrl}/modules/inv/items/';
  final String _targetCharacteristicUuid = '2a05'; // Attempted UUID, may not be correct

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
    _fetchShades();
    _fetchInventoryItems();
    _checkBluetoothPermissions();
    _weightSubscription = _bluetoothService.weightStream.listen((weight) {
      if (!mounted) {
        print('Gatheru Widget not mounted, ignoring weight event');
        return;
      }
      setState(() {
        if (!_isFirstWeightReceived) {
          _quantityController.text = weight.toStringAsFixed(2);
          _isFirstWeightReceived = true;
        }
        _quantityController.text = weight.toStringAsFixed(2);
        _bluetoothStatus = 'Weight: ${weight.toStringAsFixed(2)} kg';
        _isReadingBluetooth = false;
        print('Gatheru: Received weight: $weight, First weight received: $_isFirstWeightReceived');
      });
    });
    _errorSubscription = _bluetoothService.errorStream.listen((error) {
      if (!mounted) {
        print('Gatheru Widget not mounted, ignoring error event');
        return;
      }
      setState(() {
        _bluetoothStatus = 'Error: $error';
        _isReadingBluetooth = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.contains('ScaleReader is not initialized')
              ? 'Scale not initialized. Please try again.'
              : 'Bluetooth error: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    });
    if (widget.feeding != null) {
      _animalController.text = widget.feeding!.farmAnimalId.toString();
      _shadeController.text = widget.feeding!.shadeId?.toString() ?? '';
      _itemController.text = widget.feeding!.invItemId.toString();
      _quantityController.text = widget.feeding!.quantity.toStringAsFixed(2);
      _costController.text = widget.feeding!.cost != null ? widget.feeding!.cost!.toStringAsFixed(2) : '';
      _notesController.text = widget.feeding!.notes ?? '';
      _selectedFeedingDate = widget.feeding!.feedingDate;
      _selectedAnimalId = widget.feeding!.farmAnimalId;
      _selectedShadeId = widget.feeding!.shadeId;
      _selectedItemId = widget.feeding!.invItemId;
    } else {
      _selectedFeedingDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _animalController.dispose();
    _shadeController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _notesController.dispose();
    _weightSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> _checkBluetoothPermissions() async {
    try {
      if (Platform.isAndroid) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        if (!statuses[Permission.bluetoothScan]!.isGranted ||
            !statuses[Permission.bluetoothConnect]!.isGranted) {
          print('Gatheru Bluetooth permissions denied');
          setState(() {
            _bluetoothStatus = 'Permissions denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant Bluetooth permissions')),
          );
          return;
        }
      }
      bool isBluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
      print('Gatheru Bluetooth enabled: $isBluetoothEnabled');
      if (!isBluetoothEnabled) {
        setState(() {
          _bluetoothStatus = 'Please enable Bluetooth';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth in settings')),
        );
        return;
      }
      setState(() {
        _bluetoothStatus = 'Ready to scan';
      });
    } catch (e) {
      print('Gatheru Error checking Bluetooth permissions: $e');
      setState(() {
        _bluetoothStatus = 'Error checking Bluetooth: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth error: $e')),
      );
    }
  }

  Future<void> _selectBluetoothDevice() async {
    if (_isReadingBluetooth) {
      print('Gatheru Already reading Bluetooth, ignoring request');
      return;
    }

    setState(() {
      _isReadingBluetooth = true;
      _bluetoothStatus = 'Checking Bluetooth...';
      _isFirstWeightReceived = false; // Reset to allow new first reading
    });

    try {
      if (Platform.isAndroid) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        if (!statuses[Permission.bluetoothScan]!.isGranted ||
            !statuses[Permission.bluetoothConnect]!.isGranted) {
          print('Gatheru Bluetooth permissions denied');
          setState(() {
            _isReadingBluetooth = false;
            _bluetoothStatus = 'Permissions denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant Bluetooth permissions')),
          );
          return;
        }
      }

      bool isBluetoothEnabled = await _bluetoothService.isBluetoothEnabled();
      print('Gatheru Bluetooth enabled: $isBluetoothEnabled');
      if (!isBluetoothEnabled) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'Please enable Bluetooth';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth in settings')),
        );
        return;
      }

      final List<Map<String, dynamic>> deviceList = await _bluetoothService.getPairedDevices();
      if (deviceList.isEmpty) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'No paired devices found';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired devices found. Please pair the scale in Bluetooth settings.'),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      final Map<String, dynamic>? selectedDevice = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Paired Bluetooth Device'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: deviceList.length,
              itemBuilder: (context, index) {
                final device = deviceList[index];
                final name = device['name'] ?? 'Unknown';
                final address = device['address'];
                final type = device['type'];
                final model = device['model'] ?? 'default';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('MAC: $address, Type: $type, Model: $model'),
                  onTap: () => Navigator.pop(context, device),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedDevice == null) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'No device selected';
        });
        return;
      }

      final String deviceAddress = selectedDevice['address'];
      final String deviceName = selectedDevice['name'] ?? deviceAddress;
      final String scaleModel = selectedDevice['model'] ?? 'default';
      print('Gatheru Selected device: $deviceName, address: $deviceAddress, model: $scaleModel');
      setState(() {
        _bluetoothStatus = 'Connecting to $deviceName...';
      });

      try {
        await _bluetoothService.startScaleReader(deviceAddress, scaleModel: scaleModel).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout connecting to Bluetooth scale');
          },
        );
        setState(() {
          _bluetoothStatus = 'Reading weight... Step on the scale';
        });

        await _bluetoothService.weightStream.first.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('No weight received from scale within 30 seconds');
          },
        );
      } catch (e) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'Error: $e';
        });
        String errorMessage = e.toString();
        if (errorMessage.contains('Connection error')) {
          errorMessage = 'Failed to connect to scale. Ensure it is powered on and in range.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 6)),
        );
      }
    } catch (e) {
      print('Gatheru Error in selectBluetoothDevice: $e');
      setState(() {
        _isReadingBluetooth = false;
        _bluetoothStatus = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 6)),
      );
    }
  }

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoadingAnimals = true;
      _animalFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingAnimals = false;
        _animalFetchError = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchAnimalsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingAnimals = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allAnimals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allAnimals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _animalFetchError = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          });
          print('DEBUG: Animal API response not valid: $decodedResponse');
        }
      } else {
        setState(() {
          _animalFetchError = 'Failed to load animals: Server returned status ${response.statusCode}';
        });
        print('DEBUG: Animal fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnimals = false;
        _animalFetchError = 'Could not connect to fetch animals: $e';
      });
      print('DEBUG: Error fetching animals: $e');
    }
  }

  Future<void> _fetchShades() async {
    setState(() {
      _isLoadingShades = true;
      _shadeFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingShades = false;
        _shadeFetchError = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchShadesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingShades = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allShades = decodedResponse.map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allShades = (decodedResponse['data'] as List).map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _shadeFetchError = decodedResponse['message'] ?? 'Failed to load shades: Invalid API format.';
          });
          print('DEBUG: Shade API response not valid: $decodedResponse');
        }
      } else {
        setState(() {
          _shadeFetchError = 'Failed to load shades: Server returned status ${response.statusCode}';
        });
        print('DEBUG: Shade fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingShades = false;
        _shadeFetchError = 'Could not connect to fetch shades: $e';
      });
      print('DEBUG: Error fetching shades: $e');
    }
  }

  Future<void> _fetchInventoryItems() async {
    setState(() {
      _isLoadingItems = true;
      _itemFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingItems = false;
        _itemFetchError = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchItemsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingItems = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allInventoryItems = decodedResponse.map((json) => InventoryItem.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allInventoryItems = (decodedResponse['data'] as List).map((json) => InventoryItem.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _itemFetchError = decodedResponse['message'] ?? 'Failed to load inventory items: Invalid API format.';
          });
          print('DEBUG: Inventory Item API response not valid: $decodedResponse');
        }
      } else {
        setState(() {
          _itemFetchError = 'Failed to load inventory items: Server returned status ${response.statusCode}';
        });
        print('DEBUG: Inventory Item fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _itemFetchError = 'Could not connect to fetch inventory items: $e';
      });
      print('DEBUG: Error fetching inventory items: $e');
    }
  }

  void _addReading() {
    final value = _quantityController.text;
    if (value.isNotEmpty && double.tryParse(value) != null && double.parse(value) > 0) {
      setState(() {
        final weight = double.parse(value);
        _readings.add(weight);
        _totalWeight = _readings.fold(0.0, (sum, item) => sum + item);
        _quantityController.clear();
        _bluetoothStatus = 'Ready to scan';
        _isFirstWeightReceived = false; // Allow new first reading after adding
        print('Gatheru: Added reading: $weight, Total weight: $_totalWeight, Readings: $_readings');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive number')),
      );
    }
  }

  Future<void> _selectFeedingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFeedingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Config.themeColor,
            colorScheme: ColorScheme.light(primary: Config.themeColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedFeedingDate) {
      setState(() {
        _selectedFeedingDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAnimalId == null && _selectedShadeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select either an animal or a shade')),
        );
        return;
      }
      if (_selectedAnimalId != null && _selectedShadeId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select only one: either an animal or a shade')),
        );
        return;
      }
      if (_selectedItemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid inventory item')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> feedingData = {
          'farm_animal_id': _selectedAnimalId,
          'farm_shade_id': _selectedShadeId,
          'inv_item_id': _selectedItemId,
          'feeding_date': DateFormat('yyyy-MM-dd').format(_selectedFeedingDate),
          'quantity': double.parse(_totalWeight.toString()),
          'cost': _costController.text.isEmpty ? null : double.parse(_costController.text),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
        };

        if (widget.feeding != null) {
          feedingData['id'] = widget.feeding!.id;
          _updateEndpoint += "${feedingData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
          return;
        }

        print('Submitting to: ${widget.feeding == null ? _addEndpoint : _updateEndpoint}');
        print('Feeding Data: $feedingData');

        final response = await http.post(
          Uri.parse(widget.feeding == null ? _addEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(feedingData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        print('Response: ${response.body}');
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.feeding == null ? 'Feeding record added successfully!' : 'Feeding record updated successfully!')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Failed to ${widget.feeding == null ? 'add' : 'update'} feeding record')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        print('Error ${widget.feeding == null ? 'adding' : 'updating'} feeding record: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feeding == null ? 'Add Feeding Record' : 'Edit Feeding Record'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoadingAnimals)
                const Center(child: CircularProgressIndicator())
              else if (_animalFetchError != null)
                Center(
                  child: Text(
                    _animalFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<AnimalForFilter>(
                  controller: _animalController,
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Animal (Optional if Shade is selected)',
                        hintText: 'Start typing animal tag number...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (_selectedShadeId != null && (value == null || value.isEmpty || _selectedAnimalId == null)) {
                          return null;
                        }
                        if (_selectedAnimalId == null || !_allAnimals.any((animal) => animal.id == _selectedAnimalId && animal.tagNumber == value)) {
                          return 'Please select a valid animal from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allAnimals.where((animal) => animal.tagNumber.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, AnimalForFilter suggestion) {
                    return ListTile(
                      title: Text(suggestion.tagNumber),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (AnimalForFilter suggestion) {
                    setState(() {
                      _animalController.text = suggestion.tagNumber;
                      _selectedAnimalId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Animal: ${suggestion.tagNumber}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading animals...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isLoadingShades)
                const Center(child: CircularProgressIndicator())
              else if (_shadeFetchError != null)
                Center(
                  child: Text(
                    _shadeFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<ShadeForFilter>(
                  controller: _shadeController,
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Shade (Optional if Animal is selected)',
                        hintText: 'Start typing shade name...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.roofing),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && _selectedShadeId == null) {
                          return 'Please select a valid shade from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allShades.where((shade) => shade.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, ShadeForFilter suggestion) {
                    return ListTile(
                      title: Text(suggestion.name),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (ShadeForFilter suggestion) {
                    setState(() {
                      _shadeController.text = suggestion.name;
                      _selectedShadeId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Shade: ${suggestion.name}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading shades...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isLoadingItems)
                const Center(child: CircularProgressIndicator())
              else if (_itemFetchError != null)
                Center(
                  child: Text(
                    _itemFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<InventoryItem>(
                  controller: _itemController,
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Inventory Item',
                        hintText: 'Start typing item name...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an inventory item';
                        }
                        if (_selectedItemId == null || !_allInventoryItems.any((item) => item.id == _selectedItemId && item.name == value)) {
                          return 'Please select a valid item from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allInventoryItems.where((item) => item.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, InventoryItem suggestion) {
                    return ListTile(
                      title: Text(suggestion.name),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (InventoryItem suggestion) {
                    setState(() {
                      _itemController.text = suggestion.name;
                      _selectedItemId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Item: ${suggestion.name}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading items...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Feeding Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedFeedingDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () => _selectFeedingDate(context),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (Kg)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.scale),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isReadingBluetooth)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.bluetooth),
                          onPressed: _selectBluetoothDevice,
                        ),
                    ],
                  ),
                ),
                readOnly: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (_totalWeight == 0.0) {
                    return 'Please add at least one valid reading';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Bluetooth Status: $_bluetoothStatus',
                  style: TextStyle(
                    fontSize: 12,
                    color: _bluetoothStatus.contains('Error') ||
                        _bluetoothStatus.contains('failed') ||
                        _bluetoothStatus.contains('No scales')
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ),
              if (_bluetoothStatus.contains('Error') || _bluetoothStatus.contains('No scales'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ElevatedButton(
                    onPressed: _selectBluetoothDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Config.themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry Bluetooth Scan'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: _addReading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Config.themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add Reading'),
                ),
              ),
              if (_readings.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Total Weight: ${_totalWeight.toStringAsFixed(2)} Kg',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        color: Colors.grey[200],
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 1,
                              child: Text(
                                'Reading #',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Weight (Kg)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          itemCount: _readings.length,
                          itemBuilder: (context, index) {
                            return Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text('Reading ${index + 1}'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _readings[index].toStringAsFixed(2),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Padding(
                //   padding: const EdgeInsets.symmetric(vertical: 8.0),
                //   child: ElevatedButton(
                //     onPressed: _saveTotal,
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Config.themeColor,
                //       foregroundColor: Colors.white,
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(8),
                //       ),
                //     ),
                //     child: const Text('Save Total'),
                //   ),
                // ),
              ],
              const SizedBox(height: 8),
              Text(
                _bluetoothStatus,
                style: TextStyle(
                  color: _bluetoothStatus.contains('error') ? Colors.red : Colors.grey,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)) {
                    return 'Please enter a valid non-negative number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : widget.feeding == null ? 'Add Feeding Record' : 'Update Feeding Record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}