// add_animals_page.dart
import 'package:farmapp/com/wisedigits/sys/gender.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonEncode
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart'; // For Config
import '../../auth/SessionProvider.dart';
import '../animalcategory/animalcategory.dart';
import '../shades/shades.dart';
import 'animals.dart';

class ManageAnimalPage extends StatefulWidget {
  // Make animal optional. If provided, it's for editing.
  final Animal? animal;

  const ManageAnimalPage({super.key, this.animal});

  @override
  State<ManageAnimalPage> createState() => _ManageAnimalPageState();
}

class _ManageAnimalPageState extends State<ManageAnimalPage> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation
  final TextEditingController _tagNumberController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _acquisitionCostController = TextEditingController();

  String? _selectedSpecies;
  String? _selectedGender;
  DateTime? _birthDate;
  DateTime? _acquisitionDate;

  // --- New Shade-related State ---
  int? _selectedShadeId;
  int? _selectedCategoryId;
  int? _selectedGenderId;
  List<Shade> _shades = [];
  List<AnimalCategory> _categories = [];
  List<Gender> _gender = [];
  bool _isLoadingShades = false;
  bool _isLoadingCategories = false;
  bool _isLoadingGender = false;
  // ------------------------------

  bool _isLoading = false;
  bool _isEditing = false; // New state to determine if we are editing

  // Replace with your actual PHP endpoint URLs
  final String _addAnimalEndpoint = '${Config.baseUrl}/modules/farm/animals/create';
  final String _updateAnimalEndpoint = '${Config.baseUrl}/modules/farm/animals/create';
  final String _fetchShadesEndpoint = '${Config.baseUrl}/modules/farm/shades/';
  final String _fetchCategoriesEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/';
  final String _fetchGenderEndpoint = '${Config.baseUrl}/modules/sys/genders/';

  @override
  void initState() {
    super.initState();
    _fetchShades();
    _fetchGender();
    _fetchCategories();

    // Check if an animal was passed in (meaning we are in edit mode)
    if (widget.animal != null) {
      _isEditing = true;
      _populateFields(widget.animal!);
    }
  }

  // --- New Method: Fetch Shades ---
  Future<void> _fetchShades() async {
    setState(() {
      _isLoadingShades = true;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {

      final response = await http.get(
          Uri.parse(_fetchShadesEndpoint),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Directly check if 'data' key exists and is a List
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> shadesJsonList = responseData['data'];

          setState(() {
            _shades = shadesJsonList.map((json) => Shade.fromJson(json)).toList();
          });
        } else {
          // This handles cases where 'data' is missing or not a List,
          // or if the API returns a 'message' key for non-data responses
          _showSnackBar(responseData['message'] ?? 'Failed to load shades: Invalid data format or missing data.');
          print('DEBUG: API response for shades had invalid data format or missing data: $responseData');
        }
      } else {
        _showSnackBar('Failed to load shades: ${response.statusCode}');
      }

    } catch (e) {
      _showSnackBar('Error fetching shades: $e');
      print('Error fetching shades: $e'); // For debugging
    } finally {
      setState(() {
        _isLoadingShades = false;
      });
    }

  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {

      final response = await http.get(
        Uri.parse(_fetchCategoriesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Directly check if 'data' key exists and is a List
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> categoriesJsonList = responseData['data'];

          setState(() {
            _categories = categoriesJsonList.map((json) => AnimalCategory.fromJson(json)).toList();
          });
        } else {
          // This handles cases where 'data' is missing or not a List,
          // or if the API returns a 'message' key for non-data responses
          _showSnackBar(responseData['message'] ?? 'Failed to load shades: Invalid data format or missing data.');
          print('DEBUG: API response for shades had invalid data format or missing data: $responseData');
        }
      } else {
        _showSnackBar('Failed to load shades: ${response.statusCode}');
      }

    } catch (e) {
      _showSnackBar('Error fetching shades: $e');
      print('Error fetching shades: $e'); // For debugging
    } finally {
      setState(() {
        _isLoadingCategories = false;
      });
    }

  }

  Future<void> _fetchGender() async {
    setState(() {
      _isLoadingGender = true;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {

      final response = await http.get(
        Uri.parse(_fetchGenderEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);


        // Directly check if 'data' key exists and is a List
        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> genderJsonList = responseData['data'];

          setState(() {
            _gender = genderJsonList.map((json) => Gender.fromJson(json)).toList();
          });
        } else {
          // This handles cases where 'data' is missing or not a List,
          // or if the API returns a 'message' key for non-data responses
          _showSnackBar(responseData['message'] ?? 'Failed to load shades: Invalid data format or missing data.');
          print('DEBUG: API response for gender had invalid data format or missing data: $responseData');
        }
      } else {
        _showSnackBar('Failed to load gender: ${response.statusCode}');
      }

    } catch (e) {
      _showSnackBar('Error fetching gender: $e');
      print('Error fetching gender: $e'); // For debugging
    } finally {
      setState(() {
        _isLoadingGender = false;
      });
    }

  }
  // ------------------------------


  void _populateFields(Animal animal) {
    _tagNumberController.text = animal.tagNumber;
    _breedController.text = animal.breed ?? '';
    _weightController.text = animal.weight.toString();
    _acquisitionCostController.text = animal.acquisitionCost?.toStringAsFixed(2) ?? '';

    // --- Species field normalization (from previous discussion) ---
    final List<String> validSpecies = ['Cow', 'Goat', 'Sheep', 'Other'];
    String normalizedSpecies = animal.species.trim();
    if (validSpecies.contains(normalizedSpecies)) {
      _selectedSpecies = normalizedSpecies;
    } else {
      _selectedSpecies = 'Other';
    }
    // -------------------------------------------------------------

    _selectedGender = animal.gender;
    _selectedGenderId = animal.shadeId;
    _birthDate = animal.birthDate;
    _acquisitionDate = animal.acquisitionDate;

    // --- Populate Shade ID in edit mode ---
    _selectedShadeId = animal.shadeId;
    // ------------------------------------
  }

  @override
  void dispose() {
    _tagNumberController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _acquisitionCostController.dispose();
    super.dispose();
  }

  // Function to show date picker
  Future<void> _selectDate(BuildContext context, {required bool isBirthDate}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: (isBirthDate ? _birthDate : _acquisitionDate) ?? DateTime.now(),
      firstDate: DateTime(1900), // Allow older dates for birth
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        if (isBirthDate) {
          _birthDate = pickedDate;
        } else {
          _acquisitionDate = pickedDate;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Basic validation for dropdowns and dates
      if (_selectedSpecies == null || _selectedSpecies!.isEmpty) {
        _showSnackBar('Please select a species.');
        return;
      }
      if (_selectedGenderId == null) {
        _showSnackBar('Please select a gender.');
        return;
      }
      if (_birthDate == null) {
        _showSnackBar('Please select a birth date.');
        return;
      }
      if (_acquisitionDate == null) {
        _showSnackBar('Please select an acquisition date.');
        return;
      }
      // --- New: Validate Shade selection ---
      if (_selectedShadeId == null) {
        _showSnackBar('Please select a shade.');
        return;
      }
      // ------------------------------------

      setState(() {
        _isLoading = true;
      });

      try {
        final Map<String, dynamic> animalData = {
          'tag_number': _tagNumberController.text,
          'species': _selectedSpecies,
          'breed': _breedController.text.isEmpty ? null : _breedController.text,
          'birth_date': _birthDate!.toIso8601String().split('T')[0],
          'sys_gender_id': _selectedGenderId,
          'weight': double.tryParse(_weightController.text),
          'acquisition_date': _acquisitionDate!.toIso8601String().split('T')[0],
          'acquisition_cost': double.tryParse(_acquisitionCostController.text),
          'farm_shade_id': _selectedShadeId,
          'status': "active",
        };

        http.Response response;
        String endpoint;

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        print(jsonEncode(animalData));
        if (_isEditing) {
          // Add animal ID for update
          animalData['animal_id'] = widget.animal!.animalId;
          endpoint = _updateAnimalEndpoint;
          response = await http.post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(animalData),
          );
        } else {
          endpoint = _addAnimalEndpoint;
          response = await http.post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken'
            },
            body: jsonEncode(animalData),
          );

          debugPrint('Animal submission response status: ${response.statusCode}');
          debugPrint('Animal submission response body: ${response.body}');

        }


        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });

          final Map<String, dynamic> responseData = jsonDecode(response.body);
          _showSnackBar(responseData['message'] ?? 'Operation failed!');

          if (response.statusCode == 200 && responseData['success'] == true) {
            // If editing, pop back to details page. If adding, clear form.
            if (_isEditing) {
              Navigator.pop(context, true); // Pop with true to indicate success/update needed
            } else {
              _clearForm();
            }
          }
        }
      } catch (e) {
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Network error: $e');
        }
        print('Error submitting animal data: $e');
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _tagNumberController.clear();
    _breedController.clear();
    _weightController.clear();
    _acquisitionCostController.clear();
    setState(() {
      _selectedSpecies = null;
      _selectedGenderId = null;
      _birthDate = null;
      _acquisitionDate = null;
      _selectedShadeId = null; // --- New: Clear selected shade ---
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Animal: ${widget.animal!.tagNumber}' : 'Add New Animal'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Tag Number
              TextFormField(
                controller: _tagNumberController,
                decoration: const InputDecoration(
                  labelText: 'Tag Number (Unique)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a tag number';
                  }
                  return null;
                },
                enabled: !_isEditing, // Prevent changing tag number when editing (optional)
              ),
              const SizedBox(height: 20),

              _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>( // Value is int (shadeId)
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Select Category'),
                items: _categories.map<DropdownMenuItem<int>>((AnimalCategory animalCategory) {
                  return DropdownMenuItem<int>(
                    value: animalCategory.id, // The ID is the value
                    child: Text(animalCategory.name), // The name is what the user sees
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedCategoryId = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a Category' : null,
              ),
              const SizedBox(height: 30),

              // Species Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSpecies,
                decoration: const InputDecoration(
                  labelText: 'Species',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Select Species'),
                items: <String>['cow', 'goat', 'sheep', 'other']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSpecies = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a species' : null,
              ),
              const SizedBox(height: 20),

              // Breed (Optional)
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Breed (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
              ),
              const SizedBox(height: 20),

              // Birth Date
              InkWell(
                onTap: () => _selectDate(context, isBirthDate: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Birth Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  baseStyle: Theme.of(context).textTheme.titleMedium,
                  child: Text(
                    _birthDate == null
                        ? 'Select Birth Date'
                        : DateFormat('yyyy-MM-dd').format(_birthDate!),
                    style: TextStyle(color: _birthDate == null ? Colors.grey[700] : Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- New: Shade Dropdown ---
              _isLoadingShades
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>( // Value is int (shadeId)
                value: _selectedShadeId,
                decoration: const InputDecoration(
                  labelText: 'Shade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.house),
                ),
                hint: const Text('Select Shade'),
                items: _shades.map<DropdownMenuItem<int>>((Shade shade) {
                  return DropdownMenuItem<int>(
                    value: shade.id, // The ID is the value
                    child: Text(shade.name), // The name is what the user sees
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedShadeId = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a shade' : null,
              ),
              const SizedBox(height: 30),

              // Gender Dropdown
              _isLoadingGender
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
                value: _selectedGenderId,
                decoration: const InputDecoration(
                  labelText: 'Gender', // <-- This label text is still "Shade"
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.house), // <-- This icon is still "house"
                ),
                hint: const Text('Select Gender'),
                items: _gender.map<DropdownMenuItem<int>>((Gender gender) { // <-- HERE IS THE MAIN ERROR
                  return DropdownMenuItem<int>(
                    value: gender.id, // The ID is the value
                    child: Text(gender.name), // The name is what the user sees
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedGenderId = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a Gender' : null,
              ),
              const SizedBox(height: 20),

              // Weight
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (KG)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Acquisition Date
              InkWell(
                onTap: () => _selectDate(context, isBirthDate: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Acquisition Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  baseStyle: Theme.of(context).textTheme.titleMedium,
                  child: Text(
                    _acquisitionDate == null
                        ? 'Select Acquisition Date'
                        : DateFormat('yyyy-MM-dd').format(_acquisitionDate!),
                    style: TextStyle(color: _acquisitionDate == null ? Colors.grey[700] : Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Acquisition Cost (Optional)
              TextFormField(
                controller: _acquisitionCostController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Acquisition Cost (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),


              // --------------------------

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator(color: Config.themeColor)
                    : ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Save Changes' : 'Add Animal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Config.backgroundColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}