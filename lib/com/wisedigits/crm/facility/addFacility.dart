import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/facilitytypes.dart';
import '../models/regions.dart';
import '../models/subregions.dart';
import 'facility.dart';

class Employee {
  final int id;
  final String name;

  Employee({required this.id, required this.name});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: int.parse(json['id'].toString()), // Handle string or int
      name: json['name']?.toString() ?? '', // Handle null
    );
  }
}

class Customer {
  final int id;
  final String name;

  Customer({required this.id, required this.name});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: int.parse(json['id'].toString()), // Handle string or int
      name: json['name']?.toString() ?? '', // Handle null
    );
  }
}

class AddFacilityPage extends StatefulWidget {
  final Facility? facility;

  const AddFacilityPage({super.key, this.facility});

  @override
  State<AddFacilityPage> createState() => _AddFacilityPageState();
}

class _AddFacilityPageState extends State<AddFacilityPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  final _categoryController = TextEditingController(); // Added for category text input
  int? _regionId;
  int? _subregionId;
  int? _facilityTypeId;
  int? _employeeId;
  int? _customerId;
  String? _keyaccounts = 'no';
  int? _status = 0;
  List<Region> _regions = [];
  List<Subregion> _subregions = [];
  List<FacilityType> _facilityTypes = [];
  List<Employee> _employees = [];
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.facility != null) {
      _nameController.text = widget.facility!.name ?? '';
      _emailController.text = widget.facility!.email ?? '';
      _telController.text = widget.facility!.tel ?? '';
      _regionId = widget.facility!.regionid;
      _subregionId = widget.facility!.subregionid;
      _facilityTypeId = widget.facility!.facilitytypeid;
      _employeeId = widget.facility!.employeeid;
      _customerId = widget.facility!.customerid;
      _categoryController.text = widget.facility!.category ?? ''; // Populate category
      _keyaccounts = widget.facility!.keyaccounts;
      _status = widget.facility!.status;
    }
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    await Future.wait([
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/persons/getRegions.php',
        listSetter: (list) => _regions = list.cast<Region>(),
        fromJson: Region.fromJson,
      ),
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/persons/getSubregions.php',
        listSetter: (list) => _subregions = list.cast<Subregion>(),
        fromJson: Subregion.fromJson,
      ),
      _fetchEntityList(
        endpoint: '${Config.sisiUrl}/facilitys/getFacilitytypes.php',
        listSetter: (list) => _facilityTypes = list.cast<FacilityType>(),
        fromJson: FacilityType.fromJson,
      ),
      // _fetchEntityList(
      //   endpoint: '${Config.baseUrl}/modules/employees/',
      //   listSetter: (list) => _employees = list.cast<Employee>(),
      //   fromJson: Employee.fromJson,
      // ),
      // _fetchEntityList(
      //   endpoint: '${Config.baseUrl}/modules/customers/',
      //   listSetter: (list) => _customers = list.cast<Customer>(),
      //   fromJson: Customer.fromJson,
      // ),
    ]);
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

      print('$endpoint: ${response.statusCode}');
      print('Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> jsonList = responseData['data'];
          print('jsonList obtained: $jsonList');
          print('Is jsonList empty? ${jsonList.isEmpty}');
          print('Number of items in jsonList: ${jsonList.length}');
          setState(() {
            listSetter(jsonList.map((json) => fromJson(json as Map<String, dynamic>)).toList());
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load data: Invalid format for $endpoint';
          });
          print('Invalid format: $responseData');
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load data: ${response.statusCode}';
        });
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error fetching dropdown data: $e';
      });
      print('Error fetching data from $endpoint: $e');
    }
  }

  Future<void> _fetchSubregions(int? regionId) async {
    if (regionId == null) {
      setState(() {
        _subregions = [];
        _subregionId = null;
      });
      return;
    }
    await _fetchEntityList(
      endpoint: '${Config.baseUrl}/modules/sys/subregions/?regionid=$regionId',
      listSetter: (list) => _subregions = list.cast<Subregion>(),
      fromJson: Subregion.fromJson,
    );
  }

  Future<void> _saveFacility() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      final body = {
        'name': _nameController.text,
        'regionid': _regionId?.toString(),
        'subregionid': _subregionId?.toString(),
        'email': _emailController.text,
        'tel': _telController.text,
        'facilitytypeid': _facilityTypeId?.toString() ?? '2',
        'keyaccounts': _keyaccounts,
        'employeeid': _employeeId?.toString(),
        'customerid': _customerId?.toString(),
        'status': _status.toString(),
        'category': _categoryController.text.isEmpty ? null : _categoryController.text, // Updated to use text field
      };

      final isEdit = widget.facility != null;
      final response = await http.post(
        Uri.parse(isEdit ? '${Config.baseUrl}/modules/facilities/${widget.facility!.id}' : '${Config.baseUrl}/modules/facilities/'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to ${isEdit ? 'update' : 'add'} facility: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error ${widget.facility != null ? 'updating' : 'adding'} facility: $e';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _categoryController.dispose(); // Dispose category controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.facility != null ? 'Edit Facility' : 'Add Facility'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business, color: Config.themeColor ?? Colors.blueGrey),
                ),
                validator: (value) => value!.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _regionId,
                decoration: InputDecoration(
                  labelText: 'Region',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on, color: Config.themeColor ?? Colors.blueGrey),
                ),
                items: _regions
                    .map((region) => DropdownMenuItem(
                  value: region.id,
                  child: Text(region.name),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _regionId = value;
                    _subregionId = null;
                  });
                  _fetchSubregions(value);
                },
                validator: (value) => value == null ? 'Region is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _subregionId,
                decoration: InputDecoration(
                  labelText: 'Subregion',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city, color: Config.themeColor ?? Colors.blueGrey),
                ),
                items: _subregions
                    .map((subregion) => DropdownMenuItem(
                  value: subregion.id,
                  child: Text(subregion.name),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _subregionId = value),
                validator: (value) => value == null ? 'Subregion is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email, color: Config.themeColor ?? Colors.blueGrey),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Config.themeColor ?? Colors.blueGrey),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _facilityTypeId,
                decoration: InputDecoration(
                  labelText: 'Facility Type',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital, color: Config.themeColor ?? Colors.blueGrey),
                ),
                items: _facilityTypes
                    .map((facilityType) => DropdownMenuItem(
                  value: facilityType.id,
                  child: Text(facilityType.name),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _facilityTypeId = value),
                validator: (value) => value == null ? 'Facility Type is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category, color: Config.themeColor ?? Colors.blueGrey),
                ),
                validator: (value) => value!.isEmpty ? 'Category is required' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveFacility,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(widget.facility != null ? 'Update Facility' : 'Add Facility'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}