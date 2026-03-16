import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addProduction.dart';

class MilkProductionRecord {
  final int id;
  final int farmAnimalId;
  final String farmAnimalName;
  final DateTime productionDate;
  final double session1; // AM
  final double session2; // PM
  final double session3; // Evening
  final double total;

  MilkProductionRecord({
    required this.id,
    required this.farmAnimalId,
    required this.farmAnimalName,
    required this.productionDate,
    required this.session1,
    required this.session2,
    required this.session3,
    required this.total,
  });

  factory MilkProductionRecord.fromJson(Map<String, dynamic> json) {
    double parseQuantity(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      } else if (raw is String) {
        return double.tryParse(raw) ?? 0.0;
      }
      return 0.0;
    }

    return MilkProductionRecord(
      id: json['farm_animal_id'] as int,
      farmAnimalId: json['farm_animal_id'] as int,
      farmAnimalName: json['animal'] as String,
      productionDate: DateTime.parse(json['date'] as String),
      session1: parseQuantity(json['session_1']),
      session2: parseQuantity(json['session_2']),
      session3: parseQuantity(json['session_3']),
      total: parseQuantity(json['total']),
    );
  }
}

class ProductionDeliveryRecord {
  final String periodDate;
  final String customerName;
  final int customerId;
  final double amqty;        // delivered quantity - AM
  final double pmqty;        // delivered quantity - PM
  final double pm2qty;       // delivered quantity - PM2
  final double amaqty;       // approved quantity (from farm) - AM
  final double pmaqty;       // approved quantity (from farm) - PM
  final double pm2aqty;      // approved quantity (from farm) - PM2
  final String notes;

  ProductionDeliveryRecord({
    required this.periodDate,
    required this.customerName,
    required this.customerId,
    required this.amqty,
    required this.pmqty,
    required this.pm2qty,
    required this.amaqty,
    required this.pmaqty,
    required this.pm2aqty,
    required this.notes,
  });

  factory ProductionDeliveryRecord.fromJson(Map<String, dynamic> json) {
    double parseQuantity(dynamic raw) {
      if (raw is num) {
        return raw.toDouble();
      } else if (raw is String) {
        return double.tryParse(raw) ?? 0.0;
      }
      return 0.0;
    }

    return ProductionDeliveryRecord(
      periodDate: json['period_date'] as String,
      customerName: json['customer_name'] as String,
      customerId: json['customer_id'] as int,
      amqty: parseQuantity(json['amqty']),
      pmqty: parseQuantity(json['pmqty']),
      pm2qty: parseQuantity(json['pm2qty']),
      amaqty: parseQuantity(json['amaqty']),
      pmaqty: parseQuantity(json['pmaqty']),
      pm2aqty: parseQuantity(json['pm2aqty']),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class AnimalForFilter {
  final int id;
  final String tagNumber;

  AnimalForFilter({required this.id, required this.tagNumber});

  factory AnimalForFilter.fromJson(Map<String, dynamic> json) {
    return AnimalForFilter(
      id: json['id'] as int,
      tagNumber: json['tag_number'] as String,
    );
  }
}

class MilkProductionRecordsPage extends StatefulWidget {
  const MilkProductionRecordsPage({super.key});

  @override
  State<MilkProductionRecordsPage> createState() => _MilkProductionRecordsPageState();
}

class _MilkProductionRecordsPageState extends State<MilkProductionRecordsPage> {
  List<MilkProductionRecord> _records = [];
  List<ProductionDeliveryRecord> _deliveryRecords = [];

  bool _isLoading = false;
  bool _isLoadingDelivery = false;
  String? _errorMessage;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int? _selectedAnimalId;

  final String _fetchEndpoint = 'http://213.136.81.123/farm/reports/milk-production.php';
  final String _fetchDeliveryEndpoint = 'http://213.136.81.123/farm/reports/deliveries.php';

  // For total quantities
  double _totalAM = 0.0;
  double _totalPM = 0.0;
  double _totalEvening = 0.0;
  double _totalQuantity = 0.0;

  // For delivery breakdowns - we'll use the APPROVED quantities (amaqty, pmaqty, pm2aqty) for display
  Map<String, double> _customerApprovedAM = {};
  Map<String, double> _customerApprovedPM = {};
  Map<String, double> _customerApprovedPM2 = {};
  Map<String, double> _customerApprovedTotal = {};

  // For delivered quantities (for variance calculation)
  Map<String, double> _customerDeliveredAM = {};
  Map<String, double> _customerDeliveredPM = {};
  Map<String, double> _customerDeliveredPM2 = {};
  Map<String, double> _customerDeliveredTotal = {};

  // Totals for approved quantities (for display)
  double _totalApprovedAM = 0.0;
  double _totalApprovedPM = 0.0;
  double _totalApprovedPM2 = 0.0;
  double _totalApprovedQuantity = 0.0;

  // Totals for non-customer1 approved quantities (for variance calculation)
  double _totalNApprovedAM = 0.0;
  double _totalNApprovedPM = 0.0;
  double _totalNApprovedPM2 = 0.0;
  double _totalNApprovedQuantity = 0.0;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _isLoadingDelivery = true;
      _errorMessage = null;
      _totalAM = 0.0;
      _totalPM = 0.0;
      _totalEvening = 0.0;
      _totalQuantity = 0.0;
    });

    try {
      final Map<String, dynamic> filterData = {
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
        if (_selectedAnimalId != null) 'farm_animal_id': _selectedAnimalId,
      };
      final Map<String, dynamic> requestBody = {'filter': filterData};
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(_fetchEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 100));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> recordsData = responseData['data'];
        _records = recordsData.map((json) => MilkProductionRecord.fromJson(json)).toList();
        _totalAM = _records.fold(0.0, (sum, record) => sum + record.session1);
        _totalPM = _records.fold(0.0, (sum, record) => sum + record.session2);
        _totalEvening = _records.fold(0.0, (sum, record) => sum + record.session3);
        _totalQuantity = _records.fold(0.0, (sum, record) => sum + record.total);
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to server: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }

    // Fetch delivery records after production records
    _fetchDeliveryRecords();
  }

  Future<void> _fetchDeliveryRecords() async {
    setState(() {
      _isLoadingDelivery = true;
      _errorMessage = null;

      // Reset ALL delivery data completely
      _customerApprovedAM.clear();
      _customerApprovedPM.clear();
      _customerApprovedPM2.clear();
      _customerApprovedTotal.clear();

      _customerDeliveredAM.clear();
      _customerDeliveredPM.clear();
      _customerDeliveredPM2.clear();
      _customerDeliveredTotal.clear();

      _totalApprovedAM = 0.0;
      _totalApprovedPM = 0.0;
      _totalApprovedPM2 = 0.0;
      _totalApprovedQuantity = 0.0;

      _totalNApprovedAM = 0.0;
      _totalNApprovedPM = 0.0;
      _totalNApprovedPM2 = 0.0;
      _totalNApprovedQuantity = 0.0;
    });

    try {
      final Map<String, dynamic> filterData = {
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
        'from_production': '1',
        if (_selectedAnimalId != null) 'farm_animal_id': _selectedAnimalId,
      };

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(_fetchDeliveryEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(filterData),
      ).timeout(const Duration(seconds: 100));

      if (!mounted) return;

      setState(() {
        _isLoadingDelivery = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> recordsData = responseData['body'] is List ? responseData['body'] : [];

        setState(() {
          _deliveryRecords = recordsData.map((item) => ProductionDeliveryRecord.fromJson(item as Map<String, dynamic>)).toList();

          // Reset totals again before processing to ensure no accumulation
          _totalApprovedAM = 0.0;
          _totalApprovedPM = 0.0;
          _totalApprovedPM2 = 0.0;
          _totalNApprovedAM = 0.0;
          _totalNApprovedPM = 0.0;
          _totalNApprovedPM2 = 0.0;

          // Calculate totals per customer for approved quantities
          for (var record in _deliveryRecords) {
            String customer = record.customerName;

            // Store approved quantities (amaqty, pmaqty, pm2aqty) for display
            _customerApprovedAM[customer] = (_customerApprovedAM[customer] ?? 0.0) + record.amaqty;
            _customerApprovedPM[customer] = (_customerApprovedPM[customer] ?? 0.0) + record.pmaqty;
            _customerApprovedPM2[customer] = (_customerApprovedPM2[customer] ?? 0.0) + record.pm2aqty;
            _customerApprovedTotal[customer] = (_customerApprovedTotal[customer] ?? 0.0) + record.amaqty + record.pmaqty + record.pm2aqty;

            // Store delivered quantities (amqty, pmqty, pm2qty) for variance calculation
            _customerDeliveredAM[customer] = (_customerDeliveredAM[customer] ?? 0.0) + record.amqty;
            _customerDeliveredPM[customer] = (_customerDeliveredPM[customer] ?? 0.0) + record.pmqty;
            _customerDeliveredPM2[customer] = (_customerDeliveredPM2[customer] ?? 0.0) + record.pm2qty;
            _customerDeliveredTotal[customer] = (_customerDeliveredTotal[customer] ?? 0.0) + record.amqty + record.pmqty + record.pm2qty;

            // Update overall approved totals for customer_id=1 (delivered quantities)
            _totalApprovedAM += record.amqty;
            _totalApprovedPM += record.pmqty;
            _totalApprovedPM2 += record.pm2qty;

            // Update non-customer1 approved totals (approved quantities)
            if (record.customerId != 1) {
              _totalNApprovedAM += record.amaqty;
              _totalNApprovedPM += record.pmaqty;
              _totalNApprovedPM2 += record.pm2aqty;
            }
          }

          _totalApprovedQuantity = _totalApprovedAM + _totalApprovedPM + _totalApprovedPM2;
          _totalNApprovedQuantity = _totalNApprovedAM + _totalNApprovedPM + _totalNApprovedPM2;
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDelivery = false;
        _errorMessage = 'Could not connect to server: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Future<void> _showFilterDialog() async {
    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return MilkProductionFilterDialog(
          initialFromDate: _fromDate,
          initialToDate: _toDate,
          initialAnimalId: _selectedAnimalId,
        );
      },
    );

    if (filters != null) {
      setState(() {
        _fromDate = filters['fromDate'];
        _toDate = filters['toDate'];
        _selectedAnimalId = filters['animalId'];
      });
      _fetchRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate variance: total production - (customer1 delivered quantities + non-customer1 approved quantities)
    final double varianceAM = _totalAM - (_totalApprovedAM + _totalNApprovedAM);
    final double variancePM = _totalPM - (_totalApprovedPM + _totalNApprovedPM);
    final double varianceEvening = _totalEvening - (_totalApprovedPM2 + _totalNApprovedPM2);
    final double varianceTotal = _totalQuantity - (_totalApprovedQuantity + _totalNApprovedQuantity);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Milk Production Records'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Records',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchRecords,
            tooltip: 'Refresh Records',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Showing records from ${DateFormat('yyyy-MM-dd').format(_fromDate)} '
                  'to ${DateFormat('yyyy-MM-dd').format(_toDate)}'
                  '${_selectedAnimalId != null ? ' for Animal ID: $_selectedAnimalId' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Config.themeColor))
                : _errorMessage != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchRecords,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : _records.isEmpty
                ? const Center(
              child: Text(
                'No milk production records found for the selected filters. Add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16.0,
                  dataRowMinHeight: 38.0,
                  dataRowMaxHeight: 40.0,
                  headingRowColor: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.1)),
                  columns: const <DataColumn>[
                    DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Animal', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('AM', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                    DataColumn(label: Text('PM', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                    DataColumn(label: Text('Evening', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                  ],
                  rows: [
                    // Production records
                    ..._records.asMap().entries.map((entry) {
                      int index = entry.key;
                      MilkProductionRecord record = entry.value;
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(Text((index + 1).toString())),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MilkProductionRecordFormPage(),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(record.farmAnimalName),
                            ),
                          ),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text(record.session1.toStringAsFixed(2)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text(record.session2.toStringAsFixed(2)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text(record.session3.toStringAsFixed(2)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text(record.total.toStringAsFixed(2)))),
                        ],
                      );
                    }).toList(),

                    // Total Production Row
                    DataRow(
                      color: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.05)),
                      cells: <DataCell>[
                        const DataCell(Text('')),
                        DataCell(Text('Total Production', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(_totalAM.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(_totalPM.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(_totalEvening.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(_totalQuantity.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                      ],
                    ),

                    // Customer Breakdown Rows - Show APPROVED quantities
                    ..._customerApprovedTotal.entries.map((entry) {
                      String customer = entry.key;
                      double total = entry.value;

                      return DataRow(
                        color: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.03)),
                        cells: <DataCell>[
                          const DataCell(Text('')),
                          DataCell(Text(customer, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text((_customerApprovedAM[customer] ?? 0.0).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text((_customerApprovedPM[customer] ?? 0.0).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text((_customerApprovedPM2[customer] ?? 0.0).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                          DataCell(Align(alignment: Alignment.centerRight, child: Text(total.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                        ],
                      );
                    }).toList(),

                    // Total Approved Row
                    DataRow(
                      color: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.05)),
                      cells: <DataCell>[
                        const DataCell(Text('')),
                        DataCell(Text('Sold', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text((_totalApprovedAM + _totalNApprovedAM).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text((_totalApprovedPM + _totalNApprovedPM).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text((_totalApprovedPM2 + _totalNApprovedPM2).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text((_totalApprovedQuantity + _totalNApprovedQuantity).toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)))),
                      ],
                    ),

                    // Variance Row
                    DataRow(
                      color: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.05)),
                      cells: <DataCell>[
                        const DataCell(Text('')),
                        DataCell(Text('Variance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(varianceAM.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(variancePM.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(varianceEvening.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))),
                        DataCell(Align(alignment: Alignment.centerRight, child: Text(varianceTotal.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MilkProductionRecordFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchRecords();
            }
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add New Record',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// MilkProductionFilterDialog remains the same as in your original code
class MilkProductionFilterDialog extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final int? initialAnimalId;

  const MilkProductionFilterDialog({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    this.initialAnimalId,
  });

  @override
  State<MilkProductionFilterDialog> createState() => _MilkProductionFilterDialogState();
}

class _MilkProductionFilterDialogState extends State<MilkProductionFilterDialog> {
  late DateTime _selectedFromDate;
  late DateTime _selectedToDate;
  AnimalForFilter? _selectedAnimal;
  List<AnimalForFilter> _animals = [];
  bool _isLoadingAnimals = false;
  String? _animalErrorMessage;

  final TextEditingController _animalSearchController = TextEditingController();

  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';

  @override
  void initState() {
    super.initState();
    _selectedFromDate = widget.initialFromDate;
    _selectedToDate = widget.initialToDate;
    _fetchAnimals().then((_) {
      if (widget.initialAnimalId != null) {
        _selectedAnimal = _animals.firstWhere(
              (animal) => animal.id == widget.initialAnimalId,
          orElse: () => AnimalForFilter(id: 0, tagNumber: 'All Animals'),
        );
        _animalSearchController.text = _selectedAnimal!.tagNumber;
      }
    });
  }

  @override
  void dispose() {
    _animalSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoadingAnimals = true;
      _animalErrorMessage = null;
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
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingAnimals = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);

        if (decodedResponse is List) {
          _animals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _animals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _animalErrorMessage = decodedResponse['message'] ?? 'Failed to load animals for autocomplete: Invalid API format.';
        }
      } else {
        _animalErrorMessage = 'Failed to load animals for autocomplete: Server returned status ${response.statusCode}';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnimals = false;
        _animalErrorMessage = 'Could not connect to fetch animals: $e';
      });
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedFromDate) {
      setState(() {
        _selectedFromDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedToDate,
      firstDate: _selectedFromDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedToDate) {
      setState(() {
        _selectedToDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'fromDate': _selectedFromDate,
      'toDate': _selectedToDate,
      'animalId': _selectedAnimal?.id == 0 ? null : _selectedAnimal?.id,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedToDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedAnimal = null;
      _animalSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Milk Production'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'From Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedFromDate),
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectFromDate(context),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'To Date',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedToDate),
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectToDate(context),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _isLoadingAnimals
                ? const CircularProgressIndicator()
                : _animalErrorMessage != null
                ? Text(
              'Error loading animals: $_animalErrorMessage',
              style: const TextStyle(color: Colors.red),
            )
                : Autocomplete<AnimalForFilter>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<AnimalForFilter>.empty();
                }
                return _animals.where((AnimalForFilter animal) {
                  return animal.tagNumber.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (AnimalForFilter option) => option.tagNumber,
              fieldViewBuilder: (BuildContext context,
                  TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode,
                  VoidCallback onFieldSubmitted) {
                if (_selectedAnimal != null && fieldTextEditingController.text.isEmpty) {
                  fieldTextEditingController.text = _selectedAnimal!.tagNumber;
                }
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Filter by Animal Tag Number',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.pets),
                    suffixIcon: fieldTextEditingController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        fieldTextEditingController.clear();
                        setState(() {
                          _selectedAnimal = null;
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (text) {
                    if (text.isEmpty) {
                      setState(() {
                        _selectedAnimal = null;
                      });
                    }
                  },
                );
              },
              onSelected: (AnimalForFilter selection) {
                setState(() {
                  _selectedAnimal = selection;
                  if (_selectedAnimal?.id == 0) {
                    _selectedAnimal = null;
                    _animalSearchController.text = '';
                  } else {
                    _animalSearchController.text = selection.tagNumber;
                  }
                });
                FocusScope.of(context).unfocus();
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<AnimalForFilter> onSelected, Iterable<AnimalForFilter> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: SizedBox(
                      height: 200.0,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final AnimalForFilter option = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(option.tagNumber),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _clearFilters();
            _applyFilters();
          },
          child: const Text('Clear Filters'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}