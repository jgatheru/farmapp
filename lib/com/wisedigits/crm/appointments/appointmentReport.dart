import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';

class AppointmentReportPage extends StatefulWidget {
  const AppointmentReportPage({super.key});

  @override
  State<AppointmentReportPage> createState() => _AppointmentReportPageState();
}

class _AppointmentReportPageState extends State<AppointmentReportPage> {
  List<Map<String, dynamic>> _reportData = [];
  List<Facility> _facilities = [];
  List<Person> _persons = [];
  List<String> _specialities = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Store filter values in the parent widget
  Facility? _selectedFacility;
  Person? _selectedPerson;
  Person? _selectedAgent;
  String? _selectedSpeciality;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final employeeid = sessionProvider.currentUser?.employeeid;

    _fetchReport(
      fromDate: DateTime.now(),
      toDate: DateTime.now(),
    );
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;
    final employeeid = sessionProvider.currentUser?.employeeid;

    await Future.wait([
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/facilitys/getFacilitys.php?employeeid=$employeeid!',
        listSetter: (list) => _facilities = list.cast<Facility>(),
        fromJson: Facility.fromJson,
      ),
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/persons/getPersons.php?employeeid=$employeeid!',
        listSetter: (list) => _persons = list.cast<Person>(),
        fromJson: Person.fromJson,
      ),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchEntityList({
    required String endpoint,
    required void Function(List<dynamic>) listSetter,
    required dynamic Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${sessionProvider.currentUser?.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            listSetter(responseData['data']
                .map((json) => fromJson(json as Map<String, dynamic>))
                .toList());
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load data from $endpoint';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _fetchReport({
    Facility? selectedFacility,
    Person? selectedPerson,
    Person? selectedAgent,
    String? selectedSpeciality,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFacility = selectedFacility;
      _selectedPerson = selectedPerson;
      _selectedAgent = selectedAgent;
      _selectedSpeciality = selectedSpeciality;
      _fromDate = fromDate;
      _toDate = toDate;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;
      final employeeid = sessionProvider.currentUser?.employeeid;

      final queryParams = {
        if (selectedFacility != null) 'facilityid': selectedFacility.id.toString(),
        if (selectedPerson != null) 'personid': selectedPerson.id.toString(),
        if(selectedAgent != null) 'agentid': selectedAgent.id.toString(),
        if (selectedSpeciality != null) 'speciality': selectedSpeciality,
        if (fromDate != null) 'fromdate': DateFormat('yyyy-MM-dd').format(fromDate),
        if (toDate != null) 'todate': DateFormat('yyyy-MM-dd').format(toDate),
        'employeeid': employeeid,
              };
      final uri = Uri.parse('${Config.sisiUrl}/appointments/getAppointmentReport.php')
          .replace(queryParameters: queryParams);
      print(uri);
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${sessionProvider.currentUser?.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {print(response.body);
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _reportData = List<Map<String, dynamic>>.from(responseData['data']);
            _specialities = List<String>.from(responseData['specialities'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load report data';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching report: $e';
      });
    }
  }

  Future<void> _showFilterDialog() async {
    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AppointmentFilterDialog(
          facilities: _facilities,
          persons: _persons,
          specialities: _specialities,
          initialFacility: _selectedFacility,
          initialPerson: _selectedPerson,
          initialSpeciality: _selectedSpeciality,
          initialFromDate: _fromDate,
          initialToDate: _toDate,
        );
      },
    );

    if (filters != null && mounted) {
      await _fetchReport(
        selectedFacility: filters['facility'],
        selectedPerson: filters['person'],
        selectedSpeciality: filters['speciality'],
        fromDate: filters['fromDate'],
        toDate: filters['toDate'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final textScaleFactor = isLargeScreen ? 1.0 : 0.9;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Report'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            if (_reportData.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: isLargeScreen ? 24 : 16,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowHeight: 56,
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    verticalInside: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  headingRowColor: WidgetStateProperty.all(
                    (Config.themeColor ?? Colors.teal).withOpacity(0.1),
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Config.themeColor ?? Colors.teal,
                          fontSize: 16 * textScaleFactor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Config.themeColor ?? Colors.teal,
                          fontSize: 16 * textScaleFactor,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Scheduled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Config.themeColor ?? Colors.teal,
                          fontSize: 16 * textScaleFactor,
                        ),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Attended',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Config.themeColor ?? Colors.teal,
                          fontSize: 16 * textScaleFactor,
                        ),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Not Closed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Config.themeColor ?? Colors.teal,
                          fontSize: 16 * textScaleFactor,
                        ),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: _reportData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        index % 2 == 0
                            ? Colors.white
                            : (Config.backgroundColor ?? Colors.blueGrey)
                            .withOpacity(0.05),
                      ),
                      cells: [
                        DataCell(
                          Container(
                            constraints: BoxConstraints(maxWidth: isLargeScreen ? 200 : 150),
                            child: InkWell(
                              onTap: () {
                                final args = {
                                  'personid': data['personid']?.toString(),
                                  'agentid': data['agentid']?.toString(),
                                  'appointmentdate': data['appointmentdate'],
                                  'fromDate': _fromDate != null
                                      ? DateFormat('yyyy-MM-dd').format(_fromDate!)
                                      : null,
                                  'toDate': _toDate != null
                                      ? DateFormat('yyyy-MM-dd').format(_toDate!)
                                      : null,
                                };
                                print('Navigating with args: $args');
                                Navigator.pushNamed(
                                  context,
                                  '/viewCompleteAppointments',
                                  arguments: args,
                                );
                              },
                              child: Text(
                                data['employee_name'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 14 * textScaleFactor,
                                  color: Config.themeColor ?? Colors.teal,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            constraints:
                            BoxConstraints(maxWidth: isLargeScreen ? 120 : 100),
                            child: Text(
                              data['appointmentdate'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 14 * textScaleFactor,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            data['total_scheduled'].toString(),
                            style: TextStyle(
                              fontSize: 14 * textScaleFactor,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(
                          Text(
                            data['total_attended'].toString(),
                            style: TextStyle(
                              fontSize: 14 * textScaleFactor,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(
                          Text(
                            data['total_not_closed'].toString(),
                            style: TextStyle(
                              fontSize: 14 * textScaleFactor,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              )
            else
              const Center(
                child: Text(
                  'No records found. Apply filters to generate a report.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppointmentFilterDialog extends StatefulWidget {
  final List<Facility> facilities;
  final List<Person> persons;
  final List<String> specialities;
  final Facility? initialFacility;
  final Person? initialPerson;
  final String? initialSpeciality;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;

  const AppointmentFilterDialog({
    super.key,
    required this.facilities,
    required this.persons,
    required this.specialities,
    this.initialFacility,
    this.initialPerson,
    this.initialSpeciality,
    this.initialFromDate,
    this.initialToDate,
  });

  @override
  State<AppointmentFilterDialog> createState() => _AppointmentFilterDialogState();
}

class _AppointmentFilterDialogState extends State<AppointmentFilterDialog> {
  Facility? _selectedFacility;
  Person? _selectedPerson;
  String? _selectedSpeciality;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  final TextEditingController _facilityController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with parent widget's values if provided
    _selectedFacility = widget.initialFacility;
    _selectedPerson = widget.initialPerson;
    _selectedSpeciality = widget.initialSpeciality;
    _fromDate = widget.initialFromDate ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _toDate = widget.initialToDate ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Set controller texts
    _facilityController.text = _selectedFacility?.name ?? '';
    _personController.text = _selectedPerson?.name ?? '';
    _fromDateController.text = DateFormat('yyyy-MM-dd').format(_fromDate);
    _toDateController.text = DateFormat('yyyy-MM-dd').format(_toDate);
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'facility': _selectedFacility,
      'person': _selectedPerson,
      'speciality': _selectedSpeciality,
      'fromDate': _fromDate,
      'toDate': _toDate,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFacility = null;
      _selectedPerson = null;
      _selectedSpeciality = null;
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _facilityController.clear();
      _personController.clear();
      _fromDateController.text = DateFormat('yyyy-MM-dd').format(_fromDate);
      _toDateController.text = DateFormat('yyyy-MM-dd').format(_toDate);
    });
  }

  @override
  void dispose() {
    _facilityController.dispose();
    _personController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Appointment Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                return widget.facilities
                    .where((facility) => facility.name.toLowerCase().contains(query))
                    .map((facility) => facility.name)
                    .toList();
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedFacility =
                      widget.facilities.firstWhere((f) => f.name == selection);
                  _facilityController.text = selection;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _facilityController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Filter by Facility',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business, color: Config.themeColor),
                    suffixIcon: _selectedFacility != null
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedFacility = null;
                          controller.clear();
                        });
                      },
                    )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                return widget.persons
                    .where((person) => person.name.toLowerCase().contains(query))
                    .map((person) => person.name)
                    .toList();
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedPerson =
                      widget.persons.firstWhere((p) => p.name == selection);
                  _personController.text = selection;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _personController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Filter by Person',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, color: Config.themeColor),
                    suffixIcon: _selectedPerson != null
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _selectedPerson = null;
                          controller.clear();
                        });
                      },
                    )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'From Date',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                suffixIcon: _fromDateController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _fromDate = DateTime.now();
                      _fromDateController.text =
                          DateFormat('yyyy-MM-dd').format(_fromDate);
                    });
                  },
                )
                    : null,
              ),
              onTap: () => _selectDate(context, true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _toDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'To Date',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                suffixIcon: _toDateController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _toDate = DateTime.now();
                      _toDateController.text =
                          DateFormat('yyyy-MM-dd').format(_toDate);
                    });
                  },
                )
                    : null,
              ),
              onTap: () => _selectDate(context, false),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSpeciality,
              decoration: InputDecoration(
                labelText: 'Filter by Speciality',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services, color: Config.themeColor),
              ),
              items: widget.specialities
                  .map((speciality) => DropdownMenuItem(
                value: speciality,
                child: Text(speciality),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSpeciality = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _clearFilters,
          child: const Text('Clear Filters'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
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