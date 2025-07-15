import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addHealthRecord.dart';

class HealthRecord {
  final int id;
  final int farmAnimalId;
  final DateTime checkupDate;
  final String? diagnosis;
  final String? veterinarianName;
  final double? cost;
  final String? notes;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;
  final List<HealthRecordDrug> drugs;
  final Map<String, dynamic>? animal;

  HealthRecord({
    required this.id,
    required this.farmAnimalId,
    required this.checkupDate,
    this.diagnosis,
    this.veterinarianName,
    this.cost,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
    this.drugs = const [],
    this.animal,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      farmAnimalId: (json['farm_animal_id'] is num) ? (json['farm_animal_id'] as num).toInt() : 0,
      checkupDate: DateTime.tryParse(json['checkup_date'] as String? ?? '') ?? DateTime(2000),
      diagnosis: json['diagnosis'] as String?,
      veterinarianName: json['veterinarian_name'] as String?,
      cost: json['cost'] != null
          ? (json['cost'] is num
          ? (json['cost'] as num).toDouble()
          : double.tryParse(json['cost'].toString()) ?? null)
          : null,
      notes: json['notes'] as String?,
      ipAddress: json['ipaddress'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: (json['updated_by'] is num) ? (json['updated_by'] as num).toInt() : null,
      createdBy: (json['created_by'] is num) ? (json['created_by'] as num).toInt() : null,
      drugs: (json['drugs'] as List<dynamic>?)?.map((drug) => HealthRecordDrug.fromJson(drug as Map<String, dynamic>)).toList() ?? [],
      animal: json['animal'] as Map<String, dynamic>?,
    );
  }
}

class HealthRecordDrug {
  final int id;
  final int farmHealthRecordId;
  final int farmDrugId;
  final double dosage;
  final String dosageUnit;
  final String administrationMethod;
  final DateTime administrationDate;
  final String? notes;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  HealthRecordDrug({
    required this.id,
    required this.farmHealthRecordId,
    required this.farmDrugId,
    required this.dosage,
    required this.dosageUnit,
    required this.administrationMethod,
    required this.administrationDate,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  factory HealthRecordDrug.fromJson(Map<String, dynamic> json) {
    return HealthRecordDrug(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      farmHealthRecordId: (json['farm_health_record_id'] is num) ? (json['farm_health_record_id'] as num).toInt() : 0,
      farmDrugId: (json['farm_drug_id'] is num) ? (json['farm_drug_id'] as num).toInt() : 0,
      dosage: json['dosage'] != null
          ? (json['dosage'] is num
          ? (json['dosage'] as num).toDouble()
          : double.tryParse(json['dosage'].toString()) ?? 0.0)
          : 0.0,
      dosageUnit: json['dosage_unit'] as String? ?? 'other',
      administrationMethod: json['administration_method'] as String? ?? 'other',
      administrationDate: DateTime.tryParse(json['administration_date'] as String? ?? '') ?? DateTime(2000),
      notes: json['notes'] as String?,
      ipAddress: json['ipaddress'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: (json['updated_by'] is num) ? (json['updated_by'] as num).toInt() : null,
      createdBy: (json['created_by'] is num) ? (json['created_by'] as num).toInt() : null,
    );
  }
}

class AnimalForFilter {
  final int id;
  final String tagNumber;

  AnimalForFilter({required this.id, required this.tagNumber});

  factory AnimalForFilter.fromJson(Map<String, dynamic> json) {
    return AnimalForFilter(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      tagNumber: json['tag_number'] as String? ?? 'Unknown',
    );
  }
}

class HealthRecordsListPage extends StatefulWidget {
  const HealthRecordsListPage({super.key});

  @override
  State<HealthRecordsListPage> createState() => _HealthRecordsListPageState();
}

class _HealthRecordsListPageState extends State<HealthRecordsListPage> {
  List<HealthRecord> _records = [];
  List<AnimalForFilter> _allAnimals = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int? _selectedAnimalId;

  final String _fetchEndpoint = '${Config.baseUrl}/modules/farm/health-records/';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchRecords();
    _fetchAnimals();
  }

  Future<void> _fetchAnimals() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
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

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allAnimals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allAnimals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _errorMessage = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect to fetch animals: $e';
      });
    }
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String url = _fetchEndpoint;
      url += '?from_date=${DateFormat('yyyy-MM-dd').format(_fromDate)}';
      url += '&to_date=${DateFormat('yyyy-MM-dd').format(_toDate)}';
      if (_selectedAnimalId != null) {
        url += '&farm_animal_id=$_selectedAnimalId';
      }

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print('DEBUG: Health records response: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> recordsData = responseData['data'];
        _records = recordsData.map((json) => HealthRecord.fromJson(json)).toList();
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
      print('Error fetching health records: $e');
    }
  }

  String _getAnimalTagNumber(int animalId, Map<String, dynamic>? animal) {
    if (animal != null && animal['tag_number'] != null) {
      return animal['tag_number'] as String;
    }
    return _allAnimals.firstWhere(
          (animal) => animal.id == animalId,
      orElse: () => AnimalForFilter(id: 0, tagNumber: 'N/A'),
    ).tagNumber;
  }

  Future<void> _showFilterDialog() async {
    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return HealthRecordFilterDialog(
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Health Records'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Health Records',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchRecords,
            tooltip: 'Refresh Health Records',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Showing health records from ${DateFormat('yyyy-MM-dd').format(_fromDate)} '
                  'to ${DateFormat('yyyy-MM-dd').format(_toDate)}'
                  '${_selectedAnimalId != null ? ' for Animal: ${_getAnimalTagNumber(_selectedAnimalId!, null)}' : ''}',
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
                'No health records found for the selected filters. Add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16.0,
                dataRowMinHeight: 38.0,
                dataRowMaxHeight: 40.0,
                headingRowColor: WidgetStateProperty.resolveWith((states) => Config.themeColor.withOpacity(0.1)),
                columns: const <DataColumn>[
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Animal', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Checkup Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Veterinarian', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Drug Count', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _records.asMap().entries.map((entry) {
                  int index = entry.key;
                  HealthRecord record = entry.value;
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(Text((index + 1).toString())),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.2),
                            child: Text(
                              _getAnimalTagNumber(record.farmAnimalId, record.animal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(record.checkupDate)),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.25),
                            child: Text(
                              record.diagnosis ?? 'N/A',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: Text(record.veterinarianName ?? 'N/A'),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: Text(record.cost != null ? record.cost!.toStringAsFixed(2) : 'N/A'),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HealthRecordFormPage(healthRecord: record),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _fetchRecords();
                              }
                            });
                          },
                          child: Text(record.drugs.length.toString()),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HealthRecordFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchRecords();
            }
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add New Health Record',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HealthRecordFilterDialog extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final int? initialAnimalId;

  const HealthRecordFilterDialog({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    this.initialAnimalId,
  });

  @override
  State<HealthRecordFilterDialog> createState() => _HealthRecordFilterDialogState();
}

class _HealthRecordFilterDialogState extends State<HealthRecordFilterDialog> {
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
          orElse: () => AnimalForFilter(id: 0, tagNumber: 'Unknown'),
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
      setState(() {
        _isLoadingAnimals = false;
        _animalErrorMessage = 'User not authenticated';
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
          _animals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _animals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _animalErrorMessage = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          print('DEBUG: Animal API response not valid: $decodedResponse');
        }
      } else {
        _animalErrorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
        print('DEBUG: Animal fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnimals = false;
        _animalErrorMessage = 'Could not connect to fetch animals: $e';
      });
      print('DEBUG: Error fetching animals: $e');
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
      title: const Text('Filter Health Records'),
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
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
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