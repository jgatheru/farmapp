import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../production/BluetoothScaleService.dart';
import 'deliveries.dart'; // Ensure this file contains the Delivery and CustomerForFilter models

class DeliveryFormPage extends StatefulWidget {
  final Delivery? delivery;

  const DeliveryFormPage({super.key, this.delivery});

  @override
  State<DeliveryFormPage> createState() => _DeliveryFormPageState();
}

class _DeliveryFormPageState extends State<DeliveryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDeliveryDate = DateTime.now();
  int? _selectedCustomerId;
  int? _selectedSessionId;
  List<CustomerForFilter> _allCustomers = [];
  List<FarmSession> _allSessions = [];
  bool _isLoadingCustomers = false;
  bool _isLoadingSessions = false;
  String? _customerFetchError;
  String? _sessionFetchError;
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

  // New state variables for milk cans
  List<MilkCan> _allMilkCans = [];
  MilkCan? _selectedMilkCan;
  bool _isLoadingMilkCans = false;
  String? _milkCanFetchError;

  // final String _addEndpoint = '${Config.baseUrl}/modules/farm/milk-deliveries/create';
  final String _addEndpoint = 'https://system.wisedigits.co.ke/wonnie_mobile/api/ajax/android_save_delivery.php';

  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/milk-deliveries/';
  final String _fetchCustomersEndpoint = '${Config.baseUrl}/modules/crm/customers/';
  final String _fetchSessionsEndpoint = '${Config.baseUrl}/modules/farm/sessions/';
  // final String _fetchMilkCansEndpoint = '${Config.baseUrl}/modules/farm/milk-cans/';
  final String _fetchMilkCansEndpoint = 'http://213.136.81.123/farm/milkproduction/getCans.php';

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchSessions();
    _fetchMilkCans();
    _weightSubscription = _bluetoothService.weightStream.listen((weight) {
      if (!mounted) {
        print('Gatheru Widget not mounted, ignoring weight event');
        return;
      }
      setState(() {
        double netWeight = weight;

        // Subtract tare weight if a milk can is selected
        if (_selectedMilkCan != null) {
          netWeight = weight - _selectedMilkCan!.tareWeight;
          if (netWeight < 0) netWeight = 0; // Ensure weight doesn't go negative
        }

        if (!_isFirstWeightReceived) {
          _quantityController.text = netWeight.toStringAsFixed(2);
          _isFirstWeightReceived = true;
        }
        _quantityController.text = netWeight.toStringAsFixed(2);

        // Update status to show both gross and net weight
        if (_selectedMilkCan != null) {
          _bluetoothStatus = 'Gross: ${weight.toStringAsFixed(2)} kg | Net: ${netWeight.toStringAsFixed(2)} kg (Tare: ${_selectedMilkCan!.tareWeight.toStringAsFixed(2)} kg)';
        } else {
          _bluetoothStatus = 'Weight: ${weight.toStringAsFixed(2)} kg';
        }

        _isReadingBluetooth = false;
        print('Gatheru: Received weight: $weight, Net weight: $netWeight, First weight received: $_isFirstWeightReceived');
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
    if (widget.delivery != null) {
      // Edit mode: Populate fields with delivery data
      _customerController.text = widget.delivery!.crmCustomerId.toString();
      _sessionController.text = widget.delivery!.farmSessionId.toString();
      _quantityController.text = widget.delivery!.quantity.toStringAsFixed(2);
      _notesController.text = widget.delivery!.notes ?? '';
      _selectedDeliveryDate = widget.delivery!.date;
      _selectedCustomerId = widget.delivery!.crmCustomerId;
      _selectedSessionId = widget.delivery!.farmSessionId;
    } else {
      // Add mode: Initialize with default values
      _selectedDeliveryDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _sessionController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
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

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _customerFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchCustomersEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingCustomers = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allCustomers = decodedResponse.map((json) => CustomerForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allCustomers = (decodedResponse['data'] as List).map((json) => CustomerForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _customerFetchError = decodedResponse['message'] ?? 'Failed to load customers: Invalid API format.';
          print('DEBUG: Customer API response not valid: $decodedResponse');
        }
      } else {
        _customerFetchError = 'Failed to load customers: Server returned status ${response.statusCode}';
        print('DEBUG: Customer fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCustomers = false;
        _customerFetchError = 'Could not connect to fetch customers: $e';
      });
      print('DEBUG: Error fetching customers: $e');
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
      throw Exception('User not authenticated');
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
          print('DEBUG: Session API response not valid: $decodedResponse');
        }
      } else {
        _sessionFetchError = 'Failed to load sessions: Server returned status ${response.statusCode}';
        print('DEBUG: Session fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSessions = false;
        _sessionFetchError = 'Could not connect to fetch sessions: $e';
      });
      print('DEBUG: Error fetching sessions: $e');
    }
  }

  Future<void> _fetchMilkCans() async {
    setState(() {
      _isLoadingMilkCans = true;
      _milkCanFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchMilkCansEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingMilkCans = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        print('DEBUG: Milk Can API response: $decodedResponse');

        if (decodedResponse is List) {
          _allMilkCans = decodedResponse.map((json) => MilkCan.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic>) {
          // Check for 'body' field instead of 'data'
          if (decodedResponse['body'] is List) {
            _allMilkCans = (decodedResponse['body'] as List).map((json) => MilkCan.fromJson(json as Map<String, dynamic>)).toList();
          } else if (decodedResponse['data'] is List) {
            _allMilkCans = (decodedResponse['data'] as List).map((json) => MilkCan.fromJson(json as Map<String, dynamic>)).toList();
          } else {
            _milkCanFetchError = 'Failed to load milk cans: No data found in response.';
            print('DEBUG: Milk Can API response has no body or data list: $decodedResponse');
          }
        } else {
          _milkCanFetchError = 'Failed to load milk cans: Invalid API format.';
          print('DEBUG: Milk Can API response not valid: $decodedResponse');
        }
      } else {
        _milkCanFetchError = 'Failed to load milk cans: Server returned status ${response.statusCode}';
        print('DEBUG: Milk Can fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMilkCans = false;
        _milkCanFetchError = 'Could not connect to fetch milk cans: $e';
      });
      print('DEBUG: Error fetching milk cans: $e');
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryDate,
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
    if (picked != null && picked != _selectedDeliveryDate) {
      setState(() {
        _selectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid customer')),
        );
        return;
      }
      if (_selectedSessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid farm session')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> deliveryData = {
          'crm_customer_id': _selectedCustomerId,
          'farm_session_id': _selectedSessionId,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate),
          'approved_quantity': double.parse(_totalWeight.toString()),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
        };

        // Add milk can ID if selected
        if (_selectedMilkCan != null) {
          deliveryData['milk_can_id'] = _selectedMilkCan!.id;
        }

        if (widget.delivery != null) {
          deliveryData['id'] = widget.delivery!.id;
          _updateEndpoint += "${deliveryData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        print(jsonEncode(deliveryData));
        print(_addEndpoint);

        final response = await http.post(
          Uri.parse(widget.delivery == null ? _addEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(deliveryData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        print('Body: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          // if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.delivery == null ? 'Delivery added successfully!' : 'Delivery updated successfully!')),
          );print("We are here!!!");
          // Clear all fields and reset state after successful save
          setState(() {
            _readings.clear();
            _totalWeight = 0.0;
            _quantityController.clear();
            _isFirstWeightReceived = false;
            _bluetoothStatus = 'Ready to scan';
            _customerController.clear();
            _sessionController.clear();
            _notesController.clear();
            _selectedCustomerId = null;
            _selectedSessionId = null;
            _selectedMilkCan = null;
            _selectedDeliveryDate = DateTime.now();
          });
          // Show confirmation dialog before navigating back
          bool? navigateBack = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: const Text('Delivery saved successfully. Do you want to return to the previous screen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), // Stay on the form
                  child: const Text('Stay'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), // Navigate back
                  child: const Text('Return'),
                ),
              ],
            ),
          );
          if (navigateBack == true) {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to ${widget.delivery == null ? 'add' : 'update'} delivery')),
          );
        }
        // } else {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Server error: ${response.statusCode}')),
        //   );
        // }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        print('Error ${widget.delivery == null ? 'adding' : 'updating'} delivery: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.delivery == null ? 'Add Delivery Record' : 'Edit Delivery Record'),
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
              if (_isLoadingCustomers)
                const Center(child: CircularProgressIndicator())
              else if (_customerFetchError != null)
                Center(
                  child: Text(
                    _customerFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<CustomerForFilter>(
                  controller: _customerController,
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        hintText: 'Start typing customer name...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select or enter a customer';
                        }
                        if (_selectedCustomerId == null || !_allCustomers.any((customer) => customer.id == _selectedCustomerId && customer.name == value)) {
                          return 'Please select a valid customer from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allCustomers.where((customer) => customer.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, CustomerForFilter suggestion) {
                    return ListTile(
                      title: Text(suggestion.name),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (CustomerForFilter suggestion) {
                    setState(() {
                      _customerController.text = suggestion.name;
                      _selectedCustomerId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Customer: ${suggestion.name}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading customers...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
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
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Farm Session',
                        hintText: 'Start typing session ID...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select or enter a farm session';
                        }
                        if (_selectedSessionId == null || !_allSessions.any((session) => session.id == _selectedSessionId && session.id.toString() == value)) {
                          return 'Please select a valid session from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allSessions.where((session) => session.id.toString().contains(pattern)).toList();
                  },
                  itemBuilder: (context, FarmSession suggestion) {
                    return ListTile(
                      title: Text('Session ${suggestion.id}'),
                      subtitle: suggestion.date != null
                          ? Text(DateFormat('yyyy-MM-dd').format(suggestion.date!))
                          : null,
                    );
                  },
                  onSelected: (FarmSession suggestion) {
                    setState(() {
                      _sessionController.text = suggestion.id.toString();
                      _selectedSessionId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Session: ${suggestion.id}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading sessions...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 16),
              // Milk Can Dropdown
              if (_isLoadingMilkCans)
                const Center(child: CircularProgressIndicator())
              else if (_milkCanFetchError != null)
                Center(
                  child: Text(
                    _milkCanFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                DropdownButtonFormField<MilkCan>(
                  value: _selectedMilkCan,
                  decoration: const InputDecoration(
                    labelText: 'Milk Can (Tare Weight)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_drink),
                  ),
                  items: _allMilkCans.map((MilkCan can) {
                    return DropdownMenuItem<MilkCan>(
                      value: can,
                      child: Text('${can.name} (Tare: ${can.tareWeight.toStringAsFixed(2)} kg)'),
                    );
                  }).toList(),
                  onChanged: (MilkCan? newValue) {
                    setState(() {
                      _selectedMilkCan = newValue;

                      // Recalculate current reading if there's a value in the quantity controller
                      if (_quantityController.text.isNotEmpty) {
                        final currentWeight = double.tryParse(_quantityController.text);
                        if (currentWeight != null && _selectedMilkCan != null) {
                          final netWeight = currentWeight - _selectedMilkCan!.tareWeight;
                          _quantityController.text = netWeight > 0 ? netWeight.toStringAsFixed(2) : '0.00';
                        }
                      }
                    });
                  },
                  validator: (value) {
                    // Make milk can selection optional or required based on your business logic
                    if (value == null) {
                      return 'Please select a milk can';
                    }
                    return null;
                  },
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
                // readOnly: true,
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
              ],
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Delivery Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate),
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
                label: Text(_isSaving ? 'Saving...' : widget.delivery == null ? 'Add Delivery' : 'Update Delivery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FarmSession {
  final int id;
  final String name;
  final DateTime? date;

  FarmSession({required this.id, required this.name, this.date});

  factory FarmSession.fromJson(Map<String, dynamic> json) {
    return FarmSession(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name']?.toString() ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}

class MilkCan {
  final int id;
  final String name;
  final String code;
  final double tareWeight;

  MilkCan({
    required this.id,
    required this.name,
    required this.code,
    required this.tareWeight,
  });

  factory MilkCan.fromJson(Map<String, dynamic> json) {
    return MilkCan(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      tareWeight: (json['tareweight'] is num) ? (json['tareweight'] as num).toDouble() : 0.0,
    );
  }

  @override
  String toString() => '$name (${tareWeight.toStringAsFixed(2)} kg)';
}