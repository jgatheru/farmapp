import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addDeliveries.dart';
import 'deliveries.dart' hide FarmSession;
import 'deliverydetails.dart';

class DeliveryReport {
  final DateTime date;
  final String customerName;
  final double amQuantity;
  final double pmQuantity;
  final double pm2Quantity;
  final double amAQuantity;
  final double pmAQuantity;
  final double pm2AQuantity;
  final String? notes;

  DeliveryReport({
    required this.date,
    required this.customerName,
    required this.amQuantity,
    required this.pmQuantity,
    required this.pm2Quantity,
    required this.amAQuantity,
    required this.pmAQuantity,
    required this.pm2AQuantity,
    this.notes,
  });

  factory DeliveryReport.fromJson(Map<String, dynamic> json) {
    return DeliveryReport(
      date: DateTime.tryParse(json['period_date'] as String? ?? '')?.toLocal() ?? DateTime(2000),
      customerName: json['customer_name'] as String? ?? 'Unknown',
      amQuantity: json['amqty'] != null
          ? (json['amqty'] is num
          ? (json['amqty'] as num).toDouble()
          : double.tryParse(json['amqty'].toString()) ?? 0.0)
          : 0.0,
      pmQuantity: json['pmqty'] != null
          ? (json['pmqty'] is num
          ? (json['pmqty'] as num).toDouble()
          : double.tryParse(json['pmqty'].toString()) ?? 0.0)
          : 0.0,
      pm2Quantity: json['pm2qty'] != null
          ? (json['pm2qty'] is num
          ? (json['pm2qty'] as num).toDouble()
          : double.tryParse(json['pm2qty'].toString()) ?? 0.0)
          : 0.0,
      amAQuantity: json['amaqty'] != null
          ? (json['amaqty'] is num
          ? (json['amaqty'] as num).toDouble()
          : double.tryParse(json['amaqty'].toString()) ?? 0.0)
          : 0.0,
      pmAQuantity: json['pmaqty'] != null
          ? (json['pmaqty'] is num
          ? (json['pmaqty'] as num).toDouble()
          : double.tryParse(json['pmaqty'].toString()) ?? 0.0)
          : 0.0,
      pm2AQuantity: json['pm2aqty'] != null
          ? (json['pm2aqty'] is num
          ? (json['pm2aqty'] as num).toDouble()
          : double.tryParse(json['pm2aqty'].toString()) ?? 0.0)
          : 0.0,
      notes: json['notes'] as String?,
    );
  }
}

class DeliveriesListPage extends StatefulWidget {
  const DeliveriesListPage({super.key});

  @override
  State<DeliveriesListPage> createState() => _DeliveriesListPageState();
}

class _DeliveriesListPageState extends State<DeliveriesListPage> {
  List<DeliveryReport> _records = [];
  List<CustomerForFilter> _customers = [];
  List<FarmSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int? _selectedCustomerId;
  int? _selectedSessionId;

  final String _fetchEndpoint = 'http://213.136.81.123/farm/reports/deliveries.php';
  final String _fetchCustomersEndpoint = '${Config.baseUrl}/modules/crm/customers/';
  final String _fetchSessionsEndpoint = '${Config.baseUrl}/modules/farm/sessions/';

  double _totalQuantity = 0.0;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchCustomers();
    _fetchSessions();
    _fetchRecords();
  }

  Future<void> _fetchCustomers() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchCustomersEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        final List<dynamic> customersData = decodedResponse is List ? decodedResponse : decodedResponse['data'] ?? [];
        setState(() {
          _customers = customersData.map((json) => CustomerForFilter.fromJson(json as Map<String, dynamic>)).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load customers (Status: ${response.statusCode})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching customers: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Future<void> _fetchSessions() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
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

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        final List<dynamic> sessionsData = decodedResponse is List ? decodedResponse : decodedResponse['data'] ?? [];
        setState(() {
          _sessions = sessionsData.map((json) => FarmSession.fromJson(json as Map<String, dynamic>)).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load sessions (Status: ${response.statusCode})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching sessions: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _totalQuantity = 0.0;
    });

    try {

      final Map<String, dynamic> filterData = {

        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),

        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),

        if (_selectedCustomerId != null) 'crm_customer_id': _selectedCustomerId,

        if (_selectedSessionId != null) 'farm_session_id': _selectedSessionId,
      };

      final Map<String, dynamic> requestBody = {'filter': filterData};

      String url = _fetchEndpoint;

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(filterData),
      ).timeout(const Duration(seconds: 100));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> recordsData = responseData['body'] is List ? responseData['body'] : [];
        setState(() {
          _records = recordsData.map((json) => DeliveryReport.fromJson(json)).toList();
          _totalQuantity = _records.fold(
            0.0,
                (sum, record) => sum + record.amQuantity + record.pmQuantity + record.pm2Quantity,
          );
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
        _isLoading = false;
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
        return DeliveryFilterDialog(
          initialFromDate: _fromDate,
          initialToDate: _toDate,
          initialCustomerId: _selectedCustomerId,
          initialSessionId: _selectedSessionId,
          customers: _customers,
          sessions: _sessions,
        );
      },
    );

    if (filters != null) {
      setState(() {
        _fromDate = filters['fromDate'];
        _toDate = filters['toDate'];
        _selectedCustomerId = filters['customerId'];
        _selectedSessionId = filters['sessionId'];
      });
      _fetchRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Delivery Records'),
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
                  '${_selectedCustomerId != null ? ' for Customer ID: $_selectedCustomerId' : ''}'
                  '${_selectedSessionId != null ? ' for Session ID: $_selectedSessionId' : ''}',
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
                'No delivery records found for the selected filters. Add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                dataRowMinHeight: 38.0,
                dataRowMaxHeight: 40.0,
                headingRowColor:
                WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.1)),
                columns: const <DataColumn>[
                  DataColumn(
                      label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                      label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(
                    label: Text(
                      'AM',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'PM',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Evening',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  ..._records.asMap().entries.map((entry) {
                    int index = entry.key;
                    var record = entry.value;
                    final total = record.amQuantity + record.pmQuantity + record.pm2Quantity;
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeliveryDetailsPage(
                                    delivery: record, // Pass the entire record
                                  ),
                                ),
                              ).then((result) {
                                if (result == true) {
                                  _fetchRecords();
                                }
                              });
                            },
                            child: Text(record.customerName),
                          ),
                        ),
                        DataCell(
                          Text(DateFormat('yyyy-MM-dd').format(record.date)),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(record.amQuantity.toStringAsFixed(2)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(record.pmQuantity.toStringAsFixed(2)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(record.pm2Quantity.toStringAsFixed(2)),
                          ),
                        ),
                        DataCell(
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(total.toStringAsFixed(2)),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.25),
                            child: Text(
                              record.notes ?? 'N/A',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  DataRow(
                    color: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.05)),
                    cells: <DataCell>[
                      DataCell(Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Config.themeColor))),
                      const DataCell(Text('')),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _records.fold(0.0, (sum, r) => sum + r.amQuantity).toStringAsFixed(2),
                            style:
                            TextStyle(fontWeight: FontWeight.bold, color: Config.themeColor),
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _records.fold(0.0, (sum, r) => sum + r.pmQuantity).toStringAsFixed(2),
                            style:
                            TextStyle(fontWeight: FontWeight.bold, color: Config.themeColor),
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _records.fold(0.0, (sum, r) => sum + r.pm2Quantity).toStringAsFixed(2),
                            style:
                            TextStyle(fontWeight: FontWeight.bold, color: Config.themeColor),
                          ),
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _totalQuantity.toStringAsFixed(2),
                            style:
                            TextStyle(fontWeight: FontWeight.bold, color: Config.themeColor),
                          ),
                        ),
                      ),
                      const DataCell(Text('')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DeliveryFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchRecords();
            }
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add New Delivery',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DeliveryFilterDialog extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final int? initialCustomerId;
  final int? initialSessionId;
  final List<CustomerForFilter> customers;
  final List<FarmSession> sessions;

  const DeliveryFilterDialog({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    this.initialCustomerId,
    this.initialSessionId,
    required this.customers,
    required this.sessions,
  });

  @override
  State<DeliveryFilterDialog> createState() => _DeliveryFilterDialogState();
}

class _DeliveryFilterDialogState extends State<DeliveryFilterDialog> {
  late DateTime _selectedFromDate;
  late DateTime _selectedToDate;
  CustomerForFilter? _selectedCustomer;
  FarmSession? _selectedSession;
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _sessionSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFromDate = widget.initialFromDate;
    _selectedToDate = widget.initialToDate;
    if (widget.initialCustomerId != null) {
      _selectedCustomer = widget.customers.firstWhere(
            (customer) => customer.id == widget.initialCustomerId,
        orElse: () => CustomerForFilter(id: 0, name: 'Unknown'),
      );
      _customerSearchController.text = _selectedCustomer!.name;
    }
    if (widget.initialSessionId != null) {
      _selectedSession = widget.sessions.firstWhere(
            (session) => session.id == widget.initialSessionId,
        orElse: () => FarmSession(id: 0, name: 'Unknown'),
      );
      _sessionSearchController.text = _selectedSession!.name;
    }
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _sessionSearchController.dispose();
    super.dispose();
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
      'customerId': _selectedCustomer?.id == 0 ? null : _selectedCustomer?.id,
      'sessionId': _selectedSession?.id == 0 ? null : _selectedSession?.id,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedToDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedCustomer = null;
      _selectedSession = null;
      _customerSearchController.clear();
      _sessionSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Deliveries'),
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
            Autocomplete<CustomerForFilter>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<CustomerForFilter>.empty();
                }
                return widget.customers.where((CustomerForFilter customer) {
                  return customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (CustomerForFilter option) => option.name,
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                if (_selectedCustomer != null && fieldTextEditingController.text.isEmpty) {
                  fieldTextEditingController.text = _selectedCustomer!.name;
                }
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Filter by Customer Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person),
                    suffixIcon: fieldTextEditingController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        fieldTextEditingController.clear();
                        setState(() {
                          _selectedCustomer = null;
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (text) {
                    if (text.isEmpty) {
                      setState(() {
                        _selectedCustomer = null;
                      });
                    }
                  },
                );
              },
              onSelected: (CustomerForFilter selection) {
                setState(() {
                  _selectedCustomer = selection;
                  if (_selectedCustomer?.id == 0) {
                    _selectedCustomer = null;
                    _customerSearchController.text = '';
                  } else {
                    _customerSearchController.text = selection.name;
                  }
                });
                FocusScope.of(context).unfocus();
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<CustomerForFilter> onSelected,
                  Iterable<CustomerForFilter> options) {
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
                          final CustomerForFilter option = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(option.name),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Autocomplete<FarmSession>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<FarmSession>.empty();
                }
                return widget.sessions.where((FarmSession session) {
                  return session.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (FarmSession option) => option.name,
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                if (_selectedSession != null && fieldTextEditingController.text.isEmpty) {
                  fieldTextEditingController.text = _selectedSession!.name;
                }
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Filter by Session Name',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.event),
                    suffixIcon: fieldTextEditingController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        fieldTextEditingController.clear();
                        setState(() {
                          _selectedSession = null;
                        });
                      },
                    )
                        : null,
                  ),
                  onChanged: (text) {
                    if (text.isEmpty) {
                      setState(() {
                        _selectedSession = null;
                      });
                    }
                  },
                );
              },
              onSelected: (FarmSession selection) {
                setState(() {
                  _selectedSession = selection;
                  if (_selectedSession?.id == 0) {
                    _selectedSession = null;
                    _sessionSearchController.text = '';
                  } else {
                    _sessionSearchController.text = selection.name;
                  }
                });
                FocusScope.of(context).unfocus();
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<FarmSession> onSelected,
                  Iterable<FarmSession> options) {
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
                          final FarmSession option = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(option.name),
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