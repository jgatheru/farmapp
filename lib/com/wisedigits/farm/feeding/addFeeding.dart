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
  StreamSubscription<List<int>>? _weightSubscription;
  BluetoothDevice? _connectedDevice;

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
          'quantity': double.parse(_quantityController.text),
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