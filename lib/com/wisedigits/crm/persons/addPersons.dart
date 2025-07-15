import 'package:farmapp/com/wisedigits/crm/persons/persons.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/regions.dart';
import '../models/subregions.dart';

class AddPersonPage extends StatefulWidget {
  final Person? person;

  const AddPersonPage({super.key, this.person});

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();

  int? _selectedTitleId;
  int? _selectedPositionId;
  int? _selectedCadreId;
  int? _selectedSpecialityId;
  int? _selectedClasseId;
  int? _selectedRegionId;
  int? _selectedSubregionId;
  int? _selectedCategoryId;

  List<Title> _titles = [];
  List<Position> _positions = [];
  List<Cadre> _cadres = [];
  List<Speciality> _specialities = [];
  List<Classe> _classes = [];
  List<Region> _regions = [];
  List<Subregion> _subregions = [];
  List<Category> _categories = [];

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isLoadingTitles = false;
  bool _isLoadingPositions = false;
  bool _isLoadingCadres = false;
  bool _isLoadingSpecialities = false;
  bool _isLoadingClasses = false;
  bool _isLoadingRegions = false;
  bool _isLoadingSubregions = false;
  bool _isLoadingCategories = false;

  final String _addPersonEndpoint = '${Config.baseUrl}/modules/persons/create';
  final String _updatePersonEndpoint = '${Config.baseUrl}/modules/persons/update';
  final String _fetchTitlesEndpoint = '${Config.sisiUrl}/persons/getTitles.php';
  final String _fetchPositionsEndpoint = '${Config.sisiUrl}/persons/getPositions.php';
  final String _fetchCadresEndpoint = '${Config.sisiUrl}/persons/getCadres.php';
  final String _fetchSpecialitiesEndpoint = '${Config.sisiUrl}/persons/getSpecialitys.php';
  final String _fetchClassesEndpoint = '${Config.sisiUrl}/persons/getClasses.php';
  final String _fetchRegionsEndpoint = '${Config.sisiUrl}/persons/getRegions.php';
  final String _fetchSubregionsEndpoint = '${Config.sisiUrl}/persons/getSubregions.php';
  final String _fetchCategoriesEndpoint = '${Config.sisiUrl}/persons/getCategorys.php';

  @override
  void initState() {
    super.initState();
    _fetchTitles();
    _fetchPositions();
    _fetchCadres();
    _fetchSpecialities();
    _fetchClasses();
    _fetchRegions();
    _fetchSubregions();
    _fetchCategories();
    if (widget.person != null) {
      _isEditing = true;
      _populateFields(widget.person!);
    }
  }

  void _populateFields(Person person) {
    _nameController.text = person.name ?? '';
    _emailController.text = person.email ?? '';
    _telController.text = person.tel ?? '';
    _locationController.text = person.location ?? '';
    _photoUrlController.text = person.photoUrl ?? '';
    _selectedTitleId = person.titleid;
    _selectedPositionId = person.positionid;
    _selectedCadreId = person.cadreid;
    _selectedSpecialityId = person.specialityid;
    _selectedClasseId = person.classeid;
    _selectedRegionId = person.regionid;
    _selectedSubregionId = person.subregionid;
    _selectedCategoryId = person.categoryid;
  }


  Future<void> _fetchTitles() async => _fetchEntityList(
    endpoint: _fetchTitlesEndpoint,
    loadingSetter: (value) => _isLoadingTitles = value,
    listSetter: (list) => _titles = list.cast<Title>(),
    fromJson: Title.fromJson,
  );

  Future<void> _fetchPositions() async => _fetchEntityList(
    endpoint: _fetchPositionsEndpoint,
    loadingSetter: (value) => _isLoadingPositions = value,
    listSetter: (list) => _positions = list.cast<Position>(),
    fromJson: Position.fromJson,
  );

  Future<void> _fetchCadres() async => _fetchEntityList(
    endpoint: _fetchCadresEndpoint,
    loadingSetter: (value) => _isLoadingCadres = value,
    listSetter: (list) => _cadres = list.cast<Cadre>(),
    fromJson: Cadre.fromJson,
  );

  Future<void> _fetchSpecialities() async => _fetchEntityList(
    endpoint: _fetchSpecialitiesEndpoint,
    loadingSetter: (value) => _isLoadingSpecialities = value,
    listSetter: (list) => _specialities = list.cast<Speciality>(),
    fromJson: Speciality.fromJson,
  );

  Future<void> _fetchClasses() async => _fetchEntityList(
    endpoint: _fetchClassesEndpoint,
    loadingSetter: (value) => _isLoadingClasses = value,
    listSetter: (list) => _classes = list.cast<Classe>(),
    fromJson: Classe.fromJson,
  );

  Future<void> _fetchRegions() async => _fetchEntityList(
    endpoint: _fetchRegionsEndpoint,
    loadingSetter: (value) => _isLoadingRegions = value,
    listSetter: (list) => _regions = list.cast<Region>(),
    fromJson: Region.fromJson,
  );

  Future<void> _fetchSubregions() async => _fetchEntityList(
    endpoint: _fetchSubregionsEndpoint,
    loadingSetter: (value) => _isLoadingSubregions = value,
    listSetter: (list) => _subregions = list.cast<Subregion>(),
    fromJson: Subregion.fromJson,
  );

  Future<void> _fetchCategories() async => _fetchEntityList(
    endpoint: _fetchCategoriesEndpoint,
    loadingSetter: (value) => _isLoadingCategories = value,
    listSetter: (list) => _categories = list.cast<Category>(),
    fromJson: Category.fromJson,
  );

  Future<void> _fetchEntityList({
    required String endpoint,
    required void Function(bool) loadingSetter,
    required void Function(List<dynamic>) listSetter,
    required dynamic Function(Map<String, dynamic>) fromJson,
  }) async {
    setState(() {
      loadingSetter(true);
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      print(endpoint+": "+response.statusCode.toString());

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('data') && responseData['data'] is List) {
          final List<dynamic> jsonList = responseData['data'];

          print('jsonList obtained: $jsonList');
          print('Is jsonList empty? ${jsonList.isEmpty}');
          print('Number of items in jsonList: ${jsonList.length}');

          setState(() {
            listSetter(jsonList.map((json) => fromJson(json)).toList());
            loadingSetter(false);
          });
        } else {
          _showSnackBar('Failed to load data: Invalid format');
        }
      } else {
        _showSnackBar('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Error fetching data: $e');
    } finally {
      setState(() {
        loadingSetter(false);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _locationController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedTitleId == null ||
          _selectedPositionId == null ||
          _selectedCadreId == null ||
          _selectedSpecialityId == null ||
          _selectedClasseId == null ||
          _selectedRegionId == null ||
          _selectedSubregionId == null ||
          _selectedCategoryId == null) {
        _showSnackBar('Please select all required fields.');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final Map<String, dynamic> personData = {
          'name': _nameController.text,
          'titleid': _selectedTitleId,
          'positionid': _selectedPositionId,
          'cadreid': _selectedCadreId,
          'specialityid': _selectedSpecialityId,
          'classeid': _selectedClasseId,
          'email': _emailController.text.isEmpty ? null : _emailController.text,
          'tel': _telController.text.isEmpty ? null : _telController.text,
          'regionid': _selectedRegionId,
          'subregionid': _selectedSubregionId,
          'location': _locationController.text.isEmpty ? null : _locationController.text,
          'categoryid': _selectedCategoryId,
          'photo_url': _photoUrlController.text.isEmpty ? null : _photoUrlController.text,
        };

        http.Response response;
        String endpoint;

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (_isEditing) {
          personData['id'] = widget.person!.id;
          endpoint = _updatePersonEndpoint;
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(personData),
          );
        } else {
          endpoint = _addPersonEndpoint;
          response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(personData),
          );
        }

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _showSnackBar(responseData['message'] ?? 'Operation failed!');

        if (response.statusCode == 200 && responseData['success'] == true) {
          if (_isEditing) {
            Navigator.pop(context, true);
          } else {
            _clearForm();
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Network error: $e');
        print('Error submitting person data: $e');
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _telController.clear();
    _locationController.clear();
    _photoUrlController.clear();
    setState(() {
      _selectedTitleId = null;
      _selectedPositionId = null;
      _selectedCadreId = null;
      _selectedSpecialityId = null;
      _selectedClasseId = null;
      _selectedRegionId = null;
      _selectedSubregionId = null;
      _selectedCategoryId = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required int? value,
    required List<T> items,
    required String Function(T) getName,
    required void Function(int?) onChanged,
    required bool isLoading,
  }) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(label.contains('Title')
            ? Icons.title
            : label.contains('Position')
            ? Icons.work
            : label.contains('Cadre')
            ? Icons.group
            : label.contains('Speciality')
            ? Icons.star
            : label.contains('Classe')
            ? Icons.class_
            : label.contains('Region')
            ? Icons.location_on
            : label.contains('Subregion')
            ? Icons.location_city
            : Icons.category),
      ),
      hint: Text('Select $label'),
      items: items.map<DropdownMenuItem<int>>((T item) {
        return DropdownMenuItem<int>(
          value: (item as dynamic).id,
          child: Text(getName(item)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select a $label' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Person: ${widget.person!.name}' : 'Add New Person'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Title Dropdown
              _buildDropdown(
                label: 'Title',
                value: _selectedTitleId,
                items: _titles,
                getName: (title) => title.name,
                onChanged: (value) => setState(() => _selectedTitleId = value),
                isLoading: _isLoadingTitles,
              ),
              const SizedBox(height: 20),

              // Position Dropdown
              _buildDropdown(
                label: 'Position',
                value: _selectedPositionId,
                items: _positions,
                getName: (position) => position.name,
                onChanged: (value) => setState(() => _selectedPositionId = value),
                isLoading: _isLoadingPositions,
              ),
              const SizedBox(height: 20),

              // Cadre Dropdown
              _buildDropdown(
                label: 'Cadre',
                value: _selectedCadreId,
                items: _cadres,
                getName: (cadre) => cadre.name,
                onChanged: (value) => setState(() => _selectedCadreId = value),
                isLoading: _isLoadingCadres,
              ),
              const SizedBox(height: 20),

              // Speciality Dropdown
              _buildDropdown(
                label: 'Speciality',
                value: _selectedSpecialityId,
                items: _specialities,
                getName: (speciality) => speciality.name,
                onChanged: (value) => setState(() => _selectedSpecialityId = value),
                isLoading: _isLoadingSpecialities,
              ),
              const SizedBox(height: 20),

              // Classe Dropdown
              _buildDropdown(
                label: 'Classe',
                value: _selectedClasseId,
                items: _classes,
                getName: (classe) => classe.name,
                onChanged: (value) => setState(() => _selectedClasseId = value),
                isLoading: _isLoadingClasses,
              ),
              const SizedBox(height: 20),

              // Email (Optional)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone (Optional)
              TextFormField(
                controller: _telController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // Region Dropdown
              _buildDropdown(
                label: 'Region',
                value: _selectedRegionId,
                items: _regions,
                getName: (region) => region.name,
                onChanged: (value) => setState(() => _selectedRegionId = value),
                isLoading: _isLoadingRegions,
              ),
              const SizedBox(height: 20),

              // Subregion Dropdown
              _buildDropdown(
                label: 'Subregion',
                value: _selectedSubregionId,
                items: _subregions,
                getName: (subregion) => subregion.name,
                onChanged: (value) => setState(() => _selectedSubregionId = value),
                isLoading: _isLoadingSubregions,
              ),
              const SizedBox(height: 20),

              // Location (Optional)
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
              ),
              const SizedBox(height: 20),

              // Category Dropdown
              _buildDropdown(
                label: 'Category',
                value: _selectedCategoryId,
                items: _categories,
                getName: (category) => category.name,
                onChanged: (value) => setState(() => _selectedCategoryId = value),
                isLoading: _isLoadingCategories,
              ),
              const SizedBox(height: 20),

              // Photo URL (Optional)
              TextFormField(
                controller: _photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 30),

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator(color: Config.themeColor)
                    : ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Save Changes' : 'Add Person'),
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