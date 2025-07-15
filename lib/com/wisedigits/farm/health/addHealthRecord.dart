import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'healthrecords.dart';

class FarmDrug {
  final int id;
  final String name;

  FarmDrug({required this.id, required this.name});

  factory FarmDrug.fromJson(Map<String, dynamic> json) {
    return FarmDrug(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class HealthRecordFormPage extends StatefulWidget {
  final HealthRecord? healthRecord;

  const HealthRecordFormPage({super.key, this.healthRecord});

  @override
  State<HealthRecordFormPage> createState() => _HealthRecordFormPageState();
}

class _HealthRecordFormPageState extends State<HealthRecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _animalController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _veterinarianController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _drugItems = [];
  final List<TextEditingController> _drugControllers = [];
  final List<TextEditingController> _dosageControllers = [];
  final List<TextEditingController> _drugNotesControllers = [];

  DateTime _selectedCheckupDate = DateTime.now();
  int? _selectedAnimalId;
  List<AnimalForFilter> _allAnimals = [];
  List<FarmDrug> _allDrugs = [];
  bool _isLoadingAnimals = false;
  bool _isLoadingDrugs = false;
  String? _animalFetchError;
  String? _drugFetchError;
  bool _isSaving = false;

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/health-records/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/health-records/';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchDrugsEndpoint = '${Config.baseUrl}/modules/farm/drug/';

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
    _fetchDrugs();
    if (widget.healthRecord != null) {
      // Edit mode: Populate fields with health record data
      _animalController.text = widget.healthRecord!.farmAnimalId.toString();
      _diagnosisController.text = widget.healthRecord!.diagnosis ?? '';
      _veterinarianController.text = widget.healthRecord!.veterinarianName ?? '';
      _costController.text = widget.healthRecord!.cost != null ? widget.healthRecord!.cost!.toStringAsFixed(2) : '';
      _notesController.text = widget.healthRecord!.notes ?? '';
      _selectedCheckupDate = widget.healthRecord!.checkupDate;
      _selectedAnimalId = widget.healthRecord!.farmAnimalId;
      // Populate drug items
      for (var drug in widget.healthRecord!.drugs) {
        _drugItems.add({
          'farmDrugId': drug.farmDrugId,
          'drugName': '', // Will be populated after fetching drugs
          'dosage': drug.dosage.toString(),
          'dosageUnit': drug.dosageUnit,
          'administrationMethod': drug.administrationMethod,
          'administrationDate': drug.administrationDate,
          'notes': drug.notes ?? '',
        });
        _drugControllers.add(TextEditingController(text: '')); // Text will be set after fetching drugs
        _dosageControllers.add(TextEditingController(text: drug.dosage.toString()));
        _drugNotesControllers.add(TextEditingController(text: drug.notes ?? ''));
      }
    }
  }

  @override
  void dispose() {
    _animalController.dispose();
    _diagnosisController.dispose();
    _veterinarianController.dispose();
    _costController.dispose();
    _notesController.dispose();
    for (var controller in _drugControllers) {
      controller.dispose();
    }
    for (var controller in _dosageControllers) {
      controller.dispose();
    }
    for (var controller in _drugNotesControllers) {
      controller.dispose();
    }
    super.dispose();
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
          _animalFetchError = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          print('DEBUG: Animal API response not valid: $decodedResponse');
        }
        // Update animal controller text for edit mode
        if (widget.healthRecord != null && _allAnimals.isNotEmpty) {
          final animal = _allAnimals.firstWhere(
                (a) => a.id == widget.healthRecord!.farmAnimalId,
            orElse: () => AnimalForFilter(id: 0, tagNumber: 'Unknown'),
          );
          _animalController.text = animal.tagNumber;
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

  Future<void> _fetchDrugs() async {
    setState(() {
      _isLoadingDrugs = true;
      _drugFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchDrugsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingDrugs = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allDrugs = decodedResponse.map((json) => FarmDrug.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allDrugs = (decodedResponse['data'] as List).map((json) => FarmDrug.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _drugFetchError = decodedResponse['message'] ?? 'Failed to load drugs: Invalid API format.';
          print('DEBUG: Drug API response not valid: $decodedResponse');
        }
        // Update drug controller texts for edit mode
        if (widget.healthRecord != null && _allDrugs.isNotEmpty) {
          for (int i = 0; i < _drugItems.length; i++) {
            final drug = _allDrugs.firstWhere(
                  (d) => d.id == _drugItems[i]['farmDrugId'],
              orElse: () => FarmDrug(id: 0, name: 'Unknown'),
            );
            _drugItems[i]['drugName'] = drug.name;
            _drugControllers[i].text = drug.name;
          }
        }
      } else {
        _drugFetchError = 'Failed to load drugs: Server returned status ${response.statusCode}';
        print('DEBUG: Drug fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDrugs = false;
        _drugFetchError = 'Could not connect to fetch drugs: $e';
      });
      print('DEBUG: Error fetching drugs: $e');
    }
  }

  Future<void> _selectCheckupDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedCheckupDate,
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
    if (picked != null && picked != _selectedCheckupDate) {
      setState(() {
        _selectedCheckupDate = picked;
      });
    }
  }

  Future<void> _selectAdministrationDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _drugItems[index]['administrationDate'] as DateTime? ?? DateTime.now(),
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
    if (picked != null && picked != _drugItems[index]['administrationDate']) {
      setState(() {
        _drugItems[index]['administrationDate'] = picked;
      });
    }
  }

  void _addDrugItem() {
    setState(() {
      _drugItems.add({
        'farmDrugId': null,
        'drugName': '',
        'dosage': '',
        'dosageUnit': 'ml',
        'administrationMethod': 'injection',
        'administrationDate': DateTime.now(),
        'notes': '',
      });
      _drugControllers.add(TextEditingController());
      _dosageControllers.add(TextEditingController());
      _drugNotesControllers.add(TextEditingController());
    });
  }

  void _removeDrugItem(int index) {
    setState(() {
      _drugItems.removeAt(index);
      _drugControllers[index].dispose();
      _drugControllers.removeAt(index);
      _dosageControllers[index].dispose();
      _dosageControllers.removeAt(index);
      _drugNotesControllers[index].dispose();
      _drugNotesControllers.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAnimalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid animal')),
        );
        return;
      }
      for (var item in _drugItems) {
        if (item['farmDrugId'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a valid drug for all drug items')),
          );
          return;
        }
        if (item['dosage'].isEmpty || double.tryParse(item['dosage']) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid dosage for all drug items')),
          );
          return;
        }
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> recordData = {
          'farm_animal_id': _selectedAnimalId,
          'checkup_date': DateFormat('yyyy-MM-dd').format(_selectedCheckupDate),
          'diagnosis': _diagnosisController.text.isEmpty ? null : _diagnosisController.text,
          'veterinarian_name': _veterinarianController.text.isEmpty ? null : _veterinarianController.text,
          'cost': _costController.text.isEmpty ? null : double.parse(_costController.text),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
          'drugs': _drugItems.map((item) => {
            'farm_drug_id': item['farmDrugId'],
            'dosage': double.parse(item['dosage']),
            'dosage_unit': item['dosageUnit'],
            'administration_method': item['administrationMethod'],
            'administration_date': DateFormat('yyyy-MM-dd').format(item['administrationDate'] as DateTime),
            'notes': item['notes'].isEmpty ? null : item['notes'],
          }).toList(),
        };

        if (widget.healthRecord != null) {
          recordData['id'] = widget.healthRecord!.id;
          _updateEndpoint += "${recordData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        print(recordData);
        final response = await http.post(
          Uri.parse(widget.healthRecord == null ? _addEndpoint : _updateEndpoint),
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
              SnackBar(content: Text(widget.healthRecord == null ? 'Health record added successfully!' : 'Health record updated successfully!')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Failed to ${widget.healthRecord == null ? 'add' : 'update'} health record')),
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
        print('Error ${widget.healthRecord == null ? 'adding' : 'updating'} health record: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.healthRecord == null ? 'Add Health Record' : 'Edit Health Record'),
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
                        labelText: 'Animal',
                        hintText: 'Start typing animal tag number...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pets),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select or enter an animal';
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
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Checkup Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedCheckupDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    TextButton(
                      onPressed: () => _selectCheckupDate(context),
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _veterinarianController,
                decoration: const InputDecoration(
                  labelText: 'Veterinarian Name (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                keyboardType: TextInputType.text,
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
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Please enter a valid number';
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
              const Text(
                'Drug Records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._drugItems.asMap().entries.map((entry) {
                int index = entry.key;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        if (_isLoadingDrugs)
                          const Center(child: CircularProgressIndicator())
                        else if (_drugFetchError != null)
                          Center(
                            child: Text(
                              _drugFetchError!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          TypeAheadField<FarmDrug>(
                            controller: _drugControllers[index],
                            builder: (context, controller, focusNode) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Drug',
                                  hintText: 'Start typing drug name...',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medication),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a drug';
                                  }
                                  if (!_allDrugs.any((drug) => drug.name == value)) {
                                    return 'Please select a valid drug from the suggestions.';
                                  }
                                  return null;
                                },
                              );
                            },
                            suggestionsCallback: (pattern) async {
                              if (pattern.isEmpty) {
                                return [];
                              }
                              return _allDrugs.where((drug) => drug.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                            },
                            itemBuilder: (context, FarmDrug suggestion) {
                              return ListTile(
                                title: Text(suggestion.name),
                                subtitle: Text('ID: ${suggestion.id}'),
                              );
                            },
                            onSelected: (FarmDrug suggestion) {
                              setState(() {
                                _drugItems[index]['farmDrugId'] = suggestion.id;
                                _drugItems[index]['drugName'] = suggestion.name;
                                _drugControllers[index].text = suggestion.name;
                              });
                            },
                            loadingBuilder: (context) => const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Loading drugs...', style: TextStyle(color: Colors.grey)),
                            ),
                            errorBuilder: (context, error) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _dosageControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Dosage',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.scale),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter dosage';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            _drugItems[index]['dosage'] = value;
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _drugItems[index]['dosageUnit'],
                          decoration: const InputDecoration(
                            labelText: 'Dosage Unit',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_pharmacy),
                          ),
                          items: ['ml', 'mg', 'tablet', 'other'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _drugItems[index]['dosageUnit'] = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _drugItems[index]['administrationMethod'],
                          decoration: const InputDecoration(
                            labelText: 'Administration Method',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.medical_services),
                          ),
                          items: ['injection', 'oral', 'topical', 'other'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _drugItems[index]['administrationMethod'] = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Administration Date',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.calendar_today),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy-MM-dd').format(_drugItems[index]['administrationDate'] as DateTime),
                                style: const TextStyle(fontSize: 16),
                              ),
                              TextButton(
                                onPressed: () => _selectAdministrationDate(context, index),
                                child: const Text('Select Date'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _drugNotesControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes),
                          ),
                          maxLines: 2,
                          onChanged: (value) {
                            _drugItems[index]['notes'] = value;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _removeDrugItem(index),
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text('Remove Drug', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _addDrugItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Drug Record'),
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
                label: Text(_isSaving ? 'Saving...' : widget.healthRecord == null ? 'Add Health Record' : 'Update Health Record'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}