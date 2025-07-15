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
import '../deliveries/addDeliveries.dart';
import '../animals/animals.dart';
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
  List<AnimalForFilter> _allAnimals = [];
  List<FarmSession> _allSessions = [];
  bool _isLoadingAnimals = false;
  bool _isLoadingSessions = false;
  String? _animalFetchError;
  String? _sessionFetchError;
  bool _isSaving = false;

  // Bluetooth properties
  String _bluetoothStatus = 'Not connected';
  bool _isReadingBluetooth = false;
  StreamSubscription<List<int>>? _weightSubscription;
  BluetoothDevice? _connectedDevice;

  int? _selectedAnimalId;

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/milk-production/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/milk-production/';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchSessionsEndpoint = '${Config.baseUrl}/modules/farm/sessions/';

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
    _fetchSessions();
    if (widget.record != null) {
      _animalController.text = widget.record!.farmAnimalId.toString();
      _quantityController.text = widget.record!.quantityLiters.toStringAsFixed(2);
      _notesController.text = widget.record!.notes ?? '';
      _selectedProductionDate = widget.record!.productionDate;
      _selectedQualityGrade = widget.record!.qualityGrade;
      _selectedAnimalId = widget.record!.farmAnimalId;
      _selectedSessionId = widget.record!.farmSessionId;
    } else {
      _selectedProductionDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _animalController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _weightSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> _checkBluetoothPermissions() async {
    if (await FlutterBluePlus.isAvailable == false) {
      setState(() {
        _bluetoothStatus = 'Bluetooth is not available on this device';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth is not available')),
      );
      return;
    }

    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      setState(() {
        _bluetoothStatus = 'Bluetooth is not enabled';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable Bluetooth')),
      );
      return;
    }

    setState(() {
      _bluetoothStatus = 'Bluetooth is ready';
    });
  }

  Future<void> _selectBluetoothDevice() async {
    try {
      // Check Bluetooth adapter state
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'Bluetooth is not enabled';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth')),
        );
        return;
      }

      // Request permissions on Android
      if (Platform.isAndroid) {
        var status = await Permission.bluetoothScan.request();
        if (!status.isGranted) {
          setState(() {
            _isReadingBluetooth = false;
            _bluetoothStatus = 'Bluetooth scan permission denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant Bluetooth scan permission')),
          );
          return;
        }
        status = await Permission.bluetoothConnect.request();
        if (!status.isGranted) {
          setState(() {
            _isReadingBluetooth = false;
            _bluetoothStatus = 'Bluetooth connect permission denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant Bluetooth connect permission')),
          );
          return;
        }
        status = await Permission.location.request();
        if (!status.isGranted) {
          setState(() {
            _isReadingBluetooth = false;
            _bluetoothStatus = 'Location permission denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant location permission for Bluetooth scanning')),
          );
          return;
        }
      }

      setState(() {
        _isReadingBluetooth = true;
        _bluetoothStatus = 'Scanning for devices... Please ensure the scale is powered on and in pairing mode (e.g., step on it).';
      });

      List<ScanResult> scanResults = [];
      StreamSubscription<List<ScanResult>>? scanSubscription;

      // Listen for scan results and process advertisement data
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
        for (var result in results) {
          final device = result.device;
          final advData = result.advertisementData;
          print('Device: ${advData.advName.isNotEmpty ? advData.advName : device.platformName.isNotEmpty ? device.platformName : 'Unknown'} (${device.remoteId})');
          print('  Manufacturer Data: ${advData.manufacturerData.entries.map((e) => 'ID: ${e.key}, Data: ${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}').join(', ')}');
          print('  Service Data: ${advData.serviceData.entries.map((e) => 'UUID: ${e.key}, Data: ${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}').join(', ')}');
          print('  Service UUIDs: ${advData.serviceUuids}');

          // Attempt to parse weight from manufacturerData or serviceData
          double? measuredWeight = _parseWeightFromAdvertisement(advData);
          if (measuredWeight != null) {
            setState(() {
              _quantityController.text = measuredWeight.toStringAsFixed(2);
              _bluetoothStatus = 'Weight: ${measuredWeight.toStringAsFixed(2)} L (from advertisement)';
              _isReadingBluetooth = false;
            });
            FlutterBluePlus.stopScan();
            scanSubscription?.cancel();
            return;
          }
        }
      }, onError: (e) {
        print('Scan Error: $e');
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'Scan error: $e';
        });
      });

      // Start scanning with a filter for weight scale service (optional)
      await FlutterBluePlus.startScan(
        androidLegacy: true,
      );

      // Wait for scan to complete or weight to be found
      await Future.any([
        Future.delayed(const Duration(seconds: 15)),
        // Add a condition to stop if weight is found (handled in the listener)
      ]);

      await FlutterBluePlus.stopScan();
      scanSubscription?.cancel();

      if (!mounted) return;

      if (scanResults.isEmpty) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'No Bluetooth devices found. Ensure the scale is powered on and in pairing mode.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Bluetooth devices found. Please ensure the scale is powered on and in pairing mode (e.g., step on it or press a button).'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // If no weight was found in advertisements, show dialog to select device for GATT connection
      final BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Bluetooth Scale'),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final result = scanResults[index];
                final device = result.device;
                final name = result.advertisementData.advName.isNotEmpty
                    ? result.advertisementData.advName
                    : device.platformName.isNotEmpty
                    ? device.platformName
                    : 'Scale (${device.remoteId})';
                return ListTile(
                  title: Text(name),
                  subtitle: Text('${device.remoteId} (RSSI: ${result.rssi})'),
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

      if (selectedDevice != null && mounted) {
        setState(() {
          _bluetoothStatus = 'Connecting to ${selectedDevice.platformName.isNotEmpty ? selectedDevice.platformName : 'Scale'}...';
        });
        await _connectedDevice?.disconnect();
        _connectedDevice = selectedDevice;
        await selectedDevice.connect(timeout: const Duration(seconds: 15));

        // Read Device Name characteristic (2a00) from Generic Access service (1800)
        String deviceName = selectedDevice.platformName.isNotEmpty
            ? selectedDevice.platformName
            : 'Scale (${selectedDevice.remoteId})';
        try {
          List<BluetoothService> services = await selectedDevice.discoverServices();
          for (var service in services) {
            //print("=================${service}");
            if (service.uuid.toString().toLowerCase() == 'ffe0') {

              for (var characteristic in service.characteristics) {
                print("===========${characteristic}");
                if (characteristic.uuid.toString().toLowerCase() == 'ffe1') {
                  List<int> value = await characteristic.read();
                  deviceName = String.fromCharCodes(value).trim();
                  print('Device Name from 2a00: $deviceName');
                  break;
                }
              }
              break;
            }
          }
        } catch (e) {
          print('Error reading Device Name characteristic: $e');
        }

        setState(() {
          _bluetoothStatus = 'Connected to $deviceName';
        });

        // Try GATT connection for weight data
        await _discoverServicesAndReadWeight(selectedDevice);
      } else {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'No device selected';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReadingBluetooth = false;
          _bluetoothStatus = 'Bluetooth error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bluetooth error: $e')),
        );
      }
    }
  }

  double? _parseWeightFromAdvertisement(AdvertisementData advData) {
    print('Attempting to parse weight from advertisement data...');
    print('Manufacturer Data: ${advData.manufacturerData.entries.map((e) => 'ID: ${e.key.toRadixString(16)}, Data: ${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}').join('; ')}');
    print('Service Data: ${advData.serviceData.entries.map((e) => 'UUID: ${e.key.str}, Data: ${e.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}').join('; ')}');

    // Check Service Data for FFE0 (your scale’s service UUID)
    final customServiceUuid = Guid('0000ffe0-0000-1000-8000-00805f9b34fb');
    if (advData.serviceData.containsKey(customServiceUuid)) {
      final data = advData.serviceData[customServiceUuid]!;
      if (data.isNotEmpty) {
        try {
          // Try parsing "ST,GS,12.34KG" format
          String decoded = utf8.decode(data, allowMalformed: true).trim();
          print('Service Data (FFE0) Decoded: "$decoded"');

          // Match "ST,GS,12.34KG" or similar
          RegExp regExp = RegExp(r"ST,GS,(\d+\.\d{2})(KG)?", caseSensitive: false);
          Match? match = regExp.firstMatch(decoded);

          if (match != null && match.group(1) != null) {
            double? weight = double.tryParse(match.group(1)!);
            if (weight != null && weight >= 0 && weight <= 1000) { // Adjust range for feed quantities
              print('Parsed weight from FFE0 Service Data: $weight kg');
              return weight;
            }
          }

          // Fallback: Generic numeric string
          regExp = RegExp(r"(\d+\.\d*)", caseSensitive: false);
          match = regExp.firstMatch(decoded);
          if (match != null && match.group(1) != null) {
            double? weight = double.tryParse(match.group(1)!);
            if (weight != null && weight >= 0 && weight <= 1000) {
              print('Parsed fallback weight from FFE0 Service Data: $weight kg');
              return weight;
            }
          }
        } catch (e) {
          print('Error parsing FFE0 service data: $e');
        }
      }
    }

    // Check Manufacturer Data (less likely for your scale)
    for (var entry in advData.manufacturerData.entries) {
      final data = entry.value;
      if (data.isNotEmpty) {
        try {
          String decoded = utf8.decode(data, allowMalformed: true).trim();
          print('Manufacturer Data (ID: ${entry.key.toRadixString(16)}) Decoded: "$decoded"');

          // Try "ST,GS,12.34KG" format
          RegExp regExp = RegExp(r"ST,GS,(\d+\.\d{2})(KG)?", caseSensitive: false);
          Match? match = regExp.firstMatch(decoded);

          if (match != null && match.group(1) != null) {
            double? weight = double.tryParse(match.group(1)!);
            if (weight != null && weight >= 0 && weight <= 1000) {
              print('Parsed weight from Manufacturer Data: $weight kg');
              return weight;
            }
          }

          // Fallback: Generic numeric string
          regExp = RegExp(r"(\d+\.\d*)", caseSensitive: false);
          match = regExp.firstMatch(decoded);
          if (match != null && match.group(1) != null) {
            double? weight = double.tryParse(match.group(1)!);
            if (weight != null && weight >= 0 && weight <= 1000) {
              print('Parsed fallback weight from Manufacturer Data: $weight kg');
              return weight;
            }
          }
        } catch (e) {
          print('Error parsing Manufacturer Data (ID: ${entry.key.toRadixString(16)}): $e');
        }
      }
    }

    print('No parsable weight found in advertisement data.');
    return null;
  }

  Future<void> _discoverServicesAndReadWeight(BluetoothDevice device) async {
    try {
      setState(() {
        _isReadingBluetooth = true;
        _bluetoothStatus = 'Discovering services...';
      });

      List<BluetoothService> services = await device.discoverServices();

      // Try Weight Scale Service (0x181D)
      const String weightServiceUuid = 'ffe0';
      const String weightCharacteristicUuid = 'ffe2';

      for (var service in services) {
        print('Service UUID: ${service.uuid.str}');
        if (service.uuid.toString().toLowerCase() == weightServiceUuid) {
          print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
          for (var characteristic in service.characteristics) {
            print('  Characteristic UUID: ${characteristic.uuid.str}');
            print('    Properties: ${characteristic.properties}');
            // if (characteristic.uuid.toString().toLowerCase() == weightCharacteristicUuid) {
            if(true){
              if (characteristic.properties.indicate || characteristic.properties.notify) {
                print('Subscribing to Weight Measurement characteristic: ${characteristic.uuid}');
                await characteristic.setNotifyValue(true);
                _weightSubscription?.cancel();
                _weightSubscription = characteristic.lastValueStream.listen(
                      (value) {
                    // print('Received data (hex): ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                    if (value.isNotEmpty) {
                      double measuredWeight = _parseWeightFromCharacteristic(value);
                      setState(() {
                        _quantityController.text = measuredWeight.toStringAsFixed(2);
                        _bluetoothStatus = 'Weight: ${measuredWeight.toStringAsFixed(2)} L';
                      });
                    }
                  },
                  onError: (e) {
                    print('Stream error: $e');
                    setState(() {
                      _bluetoothStatus = 'Stream error: $e';
                    });
                  },
                );
                // Wait for data
                await Future.any([
                  Future.delayed(const Duration(seconds: 10)),
                  characteristic.lastValueStream.firstWhere((value) => value.isNotEmpty, orElse: () => []),
                ]);
                return;
              } else if (characteristic.properties.read) {
                print('Reading Weight Measurement characteristic: ${characteristic.uuid}');
                List<int> value = await characteristic.read();
                //print('Read data (hex): ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                if (value.isNotEmpty) {
                  double measuredWeight = _parseWeightFromCharacteristic(value);
                  setState(() {
                    _quantityController.text = measuredWeight.toStringAsFixed(2);
                    _bluetoothStatus = 'Weight: ${measuredWeight.toStringAsFixed(2)} L (read)';
                  });
                  return;
                }
              }
            }
          }
        }
      }

      // Fallback to any notify/indicate or read characteristic
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            print('Subscribing to characteristic: ${characteristic.uuid}');
            await characteristic.setNotifyValue(true);
            _weightSubscription?.cancel();
            _weightSubscription = characteristic.lastValueStream.listen(
                  (value) {
                print('Received data (hex): ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                if (value.isNotEmpty) {
                  double measuredWeight = _parseWeightFromCharacteristic(value);
                  setState(() {
                    _quantityController.text = measuredWeight.toStringAsFixed(2);
                    _bluetoothStatus = 'Weight: ${measuredWeight.toStringAsFixed(2)} L';
                  });
                }
              },
              onError: (e) {
                print('Stream error: $e');
                setState(() {
                  _bluetoothStatus = 'Stream error: $e';
                });
              },
            );
            await Future.any([
              Future.delayed(const Duration(seconds: 10)),
              characteristic.lastValueStream.firstWhere((value) => value.isNotEmpty, orElse: () => []),
            ]);
            return;
          } else if (characteristic.properties.read) {
            print('Reading characteristic: ${characteristic.uuid}');
            List<int> value = await characteristic.read();
            print('Read data (hex): ${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
            if (value.isNotEmpty) {
              double measuredWeight = _parseWeightFromCharacteristic(value);
              setState(() {
                _quantityController.text = measuredWeight.toStringAsFixed(2);
                _bluetoothStatus = 'Weight: ${measuredWeight.toStringAsFixed(2)} L (read)';
              });
              return;
            }
          }
        }
      }

      setState(() {
        _isReadingBluetooth = false;
        _bluetoothStatus = 'No suitable characteristics found. Weight may be in advertisements.';
      });
    } catch (e) {
      setState(() {
        _isReadingBluetooth = false;
        _bluetoothStatus = 'Service discovery error: $e';
      });
      print('Bluetooth Service Discovery Error: $e');
    } finally {
      setState(() {
        _isReadingBluetooth = false;
      });
    }
  }

  double _parseWeightFromCharacteristic(List<int> value) {

    try {
      if (value.isEmpty || value.every((b) => b == 0)) {
        return 0.0;
      }

      // Attempt 1: BLE Weight Scale Service format (UUID 0x2A9D)
      // This is for specific BLE devices adhering to the standard.
      // if (value.length >= 3) {
      //   // Check if the first byte (flags) indicates a valid measurement,
      //   // though for simplicity, we're just checking length here.
      //   // A more robust implementation would parse the flags.
      //   int rawWeight = (value[2] << 8) + value[1]; // Little-endian
      //   double weightKg = rawWeight * 0.005; // 0.005 kg resolution
      //   // Add a check for realistic values to avoid misinterpreting ASCII as BLE data
      //   if (weightKg > 0.01 && weightKg < 500) { // More robust range check for BLE
      //     print('Parsed as BLE Weight Scale: ${weightKg} kg');
      //     return weightKg;
      //   }
      // }

      // Attempt 2: Try ASCII decoding and robust unit extraction
      String decoded = utf8.decode(value, allowMalformed: true).trim(); // Trim whitespace
      print('Characteristic Decoded: "$decoded"');

      // Regex to capture numbers (integers or decimals) and an optional unit (KG, LBS, etc.)
      // It looks for a sequence of digits, optionally a dot and more digits, followed by optional spaces and letters.
      final RegExp weightRegex = RegExp(r'(\d+(\.\d+)?)\s*([a-zA-Z]+)?');
      final Match? match = weightRegex.firstMatch(decoded);

      if (match != null) {
        String? numericPart = match.group(1); // The numeric value (e.g., "1.2")
        String? unitPart = match.group(3);    // The unit (e.g., "KG", "LBS")

        double? weight = double.tryParse(numericPart ?? '');

        if (weight != null && weight > 0 && weight < 1000) { // Reasonable weight range
          if (unitPart != null) {
            final String upperCaseUnit = unitPart.toUpperCase();
            if (upperCaseUnit.contains('KG')) {
              print('Parsed as ASCII String (KG): $weight kg');
              return weight; // Already in kg
            } else if (upperCaseUnit.contains('LB') || upperCaseUnit.contains('LBS')) {
              // Convert pounds to kilograms (1 lb = 0.453592 kg)
              double weightKg = weight * 0.453592;
              print('Parsed as ASCII String (LBS): $weight lbs = ${weightKg} kg');
              return weightKg;
            }
            // Add more unit conversions here if needed (e.g., 'G' for grams)
          } else {
            // If no unit is specified, you might assume KG or return 0.0
            // based on your application's requirements. For now, we'll assume KG if in a reasonable range.
            print('Parsed as ASCII String (No Unit, assuming KG): $weight kg');
            return weight;
          }
        }
      }

      // If none of the above parsing methods work
      print('Failed to parse weight from characteristic: $value');
      return 0.0;
    } catch (e) {
      print('Error parsing characteristic data: $e');
      return 0.0;
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

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoadingAnimals = true;
      _animalFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
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
    print('DEBUG: Animal API response not valid: $decodedResponse');
    }
    } else {
    _animalFetchError = 'Failed to load animals: Server returned status ${response.statusCode}';
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
          'notes': _sessionController.text.isEmpty ? null : _notesController.text,
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
        ).timeout(const Duration(seconds: 100));

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
                    print('DEBUG: Animal search pattern: $pattern');
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
                    print('DEBUG: Animal search pattern: $pattern');
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
                  suffixIcon: IconButton(
                    icon: _isReadingBluetooth
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.bluetooth),
                    onPressed: _isReadingBluetooth ? null : _selectBluetoothDevice,
                  ),
                ),
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
                    color: _bluetoothStatus.contains('Error') || _bluetoothStatus.contains('failed') ? Colors.red : Colors.grey,
                  ),
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