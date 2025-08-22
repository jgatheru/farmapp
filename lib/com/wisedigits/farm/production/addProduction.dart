import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../deliveries/addDeliveries.dart';
import 'BluetoothScaleService.dart';
import 'model.dart';

class MilkProductionRecordFormPage extends StatefulWidget {
  final MilkProductionRecord? record;

  const MilkProductionRecordFormPage({super.key, this.record});

  @override
  State<MilkProductionRecordFormPage> createState() => _MilkProductionRecordFormPageState();
}

class _MilkProductionRecordFormPageState extends State<MilkProductionRecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animalController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();

  DateTime _selectedProductionDate = DateTime.now();
  int? _selectedSessionId;
  String? _selectedQualityGrade;
  int? _selectedAnimalId;
  List<AnimalForFilter> _allAnimals = [];
  List<FarmSession> _allSessions = [];
  bool _isLoadingAnimals = false;
  bool _isLoadingSessions = false;
  String? _animalFetchError;
  String? _sessionFetchError;
  bool _isSaving = false;
  bool _isReadingBluetooth = false;
  String _bluetoothStatus = 'Not connected';
  StreamSubscription<double>? _weightSubscription;
  StreamSubscription<String>? _errorSubscription;
  final _bluetoothService = BluetoothScaleService();

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/milk-production/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/milk-production/';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchSessionsEndpoint = '${Config.baseUrl}/modules/farm/sessions/';

  @override
  void initState() {
    super.initState();
    _checkBluetoothPermissions();
    _fetchAnimals();
    _fetchSessions();
    _weightSubscription = _bluetoothService.weightStream.listen((weight) {
      if (!mounted) {
        print('Gatheru Widget not mounted, ignoring weight event');
        return;
      }
      setState(() {
        _quantityController.text = weight.toStringAsFixed(2);
        _bluetoothStatus = 'Weight: ${weight.toStringAsFixed(2)} kg';
        _isReadingBluetooth = false;
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
  }

  @override
  void dispose() {
    print('Gatheru Disposing MilkProductionRecordFormPage...');
    _animalController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _sessionController.dispose();
    _weightSubscription?.cancel();
    _errorSubscription?.cancel();
    _bluetoothService.stopScaleReader();
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
      );

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
          _animalFetchError = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          print('WAMBUI : Animal API response not valid: $decodedResponse');
        }
      } else {
        _animalFetchError = 'Failed to load animals: Server returned status ${response.statusCode}';
        print('WAMBUI : Animal fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnimals = false;
        _animalFetchError = 'Could not connect to fetch animals: $e';
      });
      print('WAMBUI : Error fetching animals: $e');
    }
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingSessions = false;
        _sessionFetchError = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchSessionsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingSessions = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allSessions = decodedResponse.map((json) => FarmSession.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allSessions = (decodedResponse['data'] as List).map((json) => FarmSession.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _sessionFetchError = decodedResponse['message'] ?? 'Failed to load sessions: Invalid API format.';
          print('WAMBUI : Session API response not valid: $decodedResponse');
        }
      } else {
        _sessionFetchError = 'Failed to load sessions: Server returned status ${response.statusCode}';
        print('WAMBUI : Session fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSessions = false;
        _sessionFetchError = 'Could not connect to fetch sessions: $e';
      });
      print('WAMBUI : Error fetching sessions: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedProductionDate,
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
    if (picked != null && picked != _selectedProductionDate) {
      setState(() {
        _selectedProductionDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAnimalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid animal')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> recordData = {
          'farm_animal_id': _selectedAnimalId,
          'date': DateFormat('yyyy-MM-dd').format(_selectedProductionDate),
          'quantity': double.parse(_quantityController.text),
          'quality_grade': _selectedQualityGrade?.toLowerCase(),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
          'farm_session_id': _selectedSessionId,
        };

        if (widget.record != null) {
          recordData['id'] = widget.record!.id;
          _updateEndpoint += "/${recordData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        print(jsonEncode(recordData));
        final response = await http.post(
          Uri.parse(widget.record == null ? _addEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(recordData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        print(response.body);
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.record == null ? 'Record added successfully!' : 'Record updated successfully!')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Failed to ${widget.record == null ? 'add' : 'update'} record')),
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
        print('Error ${widget.record == null ? 'adding' : 'updating'} milk record: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'Add Milk Production Record' : 'Edit Milk Production Record'),
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
                  decorationBuilder: (context, child) {
                    return Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: child,
                      ),
                    );
                  },
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Animal',
                        hintText: 'Start typing animal tag number or ID...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter or select an animal';
                        }
                        final exists = _allAnimals.any((animal) =>
                        animal.tagNumber.toLowerCase() == value.toLowerCase() ||
                            animal.id.toString() == value);
                        if (!exists) {
                          return 'Please select a valid animal from the suggestions';
                        }
                        final selectedAnimal = _allAnimals.firstWhere(
                              (animal) =>
                          animal.tagNumber.toLowerCase() == value.toLowerCase() ||
                              animal.id.toString() == value,
                          orElse: () => AnimalForFilter(id: -1, tagNumber: ''),
                        );
                        if (selectedAnimal.id != -1) {
                          setState(() {
                            _selectedAnimalId = selectedAnimal.id;
                          });
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    print('WAMBUI : Animal search pattern: $pattern');
                    if (pattern.isEmpty) {
                      return _allAnimals;
                    }
                    return _allAnimals.where((animal) =>
                    animal.tagNumber.toLowerCase().contains(pattern.toLowerCase()) ||
                        animal.id.toString().contains(pattern)).toList();
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
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  emptyBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No animals found', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isLoadingSessions)
                const Center(child: CircularProgressIndicator())
              else if (_sessionFetchError != null)
                Center(
                  child: Text(
                    _sessionFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<FarmSession>(
                  controller: _sessionController,
                  decorationBuilder: (context, child) {
                    return Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: child,
                      ),
                    );
                  },
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Session',
                        hintText: 'Start typing',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter or select a session';
                        }
                        final exists = _allSessions.any((farmSession) =>
                        farmSession.name.toLowerCase() == value.toLowerCase() ||
                            farmSession.id.toString() == value);
                        if (!exists) {
                          return 'Please select a valid session from the suggestions';
                        }
                        final selectedSession = _allSessions.firstWhere(
                              (farmSession) =>
                          farmSession.name.toLowerCase() == value.toLowerCase() ||
                              farmSession.id.toString() == value,
                          orElse: () => FarmSession(id: -1, name: ''),
                        );
                        if (selectedSession.id != -1) {
                          setState(() {
                            _selectedSessionId = selectedSession.id;
                          });
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    print('WAMBUI : Session search pattern: $pattern');
                    if (pattern.isEmpty) {
                      return _allSessions;
                    }
                    return _allSessions.where((farmSession) =>
                    farmSession.name.toLowerCase().contains(pattern.toLowerCase()) ||
                        farmSession.id.toString().contains(pattern)).toList();
                  },
                  itemBuilder: (context, FarmSession suggestion) {
                    return ListTile(
                      title: Text(suggestion.name),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (FarmSession suggestion) {
                    setState(() {
                      _sessionController.text = suggestion.name;
                      _selectedSessionId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Session: ${suggestion.name}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  emptyBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No sessions found', style: TextStyle(color: Colors.grey)),
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
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
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
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Production Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedProductionDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedQualityGrade,
                decoration: const InputDecoration(
                  labelText: 'Quality Grade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star),
                ),
                hint: const Text('Select Quality Grade'),
                items: <String>['A', 'B', 'C'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedQualityGrade = newValue;
                  });
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
                label: Text(_isSaving ? 'Saving...' : widget.record == null ? 'Add Record' : 'Update Record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}