import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'deliveries.dart'; // Ensure this file contains the Delivery and CustomerForFilter models

class DeliveryFormPage extends StatefulWidget {
  final Delivery? delivery;

  const DeliveryFormPage({super.key, this.delivery});

  @override
  State<DeliveryFormPage> createState() => _DeliveryFormPageState();
}

class _DeliveryFormPageState extends State<DeliveryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDeliveryDate = DateTime.now();
  int? _selectedCustomerId;
  int? _selectedSessionId;
  List<CustomerForFilter> _allCustomers = [];
  List<FarmSession> _allSessions = [];
  bool _isLoadingCustomers = false;
  bool _isLoadingSessions = false;
  String? _customerFetchError;
  String? _sessionFetchError;
  bool _isSaving = false;

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/milk-deliveries/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/milk-deliveries/';
  final String _fetchCustomersEndpoint = '${Config.baseUrl}/modules/crm/customers/';
  final String _fetchSessionsEndpoint = '${Config.baseUrl}/modules/farm/sessions/';

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _fetchSessions();
    if (widget.delivery != null) {
      // Edit mode: Populate fields with delivery data
      _customerController.text = widget.delivery!.crmCustomerId.toString();
      _sessionController.text = widget.delivery!.farmSessionId.toString();
      _quantityController.text = widget.delivery!.quantity.toStringAsFixed(2);
      _notesController.text = widget.delivery!.notes ?? '';
      _selectedDeliveryDate = widget.delivery!.date;
      _selectedCustomerId = widget.delivery!.crmCustomerId;
      _selectedSessionId = widget.delivery!.farmSessionId;
    } else {
      // Add mode: Initialize with default values
      _selectedDeliveryDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _sessionController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoadingCustomers = true;
      _customerFetchError = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchCustomersEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingCustomers = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allCustomers = decodedResponse.map((json) => CustomerForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allCustomers = (decodedResponse['data'] as List).map((json) => CustomerForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          _customerFetchError = decodedResponse['message'] ?? 'Failed to load customers: Invalid API format.';
          print('DEBUG: Customer API response not valid: $decodedResponse');
        }
      } else {
        _customerFetchError = 'Failed to load customers: Server returned status ${response.statusCode}';
        print('DEBUG: Customer fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCustomers = false;
        _customerFetchError = 'Could not connect to fetch customers: $e';
      });
      print('DEBUG: Error fetching customers: $e');
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryDate,
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
    if (picked != null && picked != _selectedDeliveryDate) {
      setState(() {
        _selectedDeliveryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid customer')),
        );
        return;
      }
      if (_selectedSessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid farm session')),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> deliveryData = {
          'crm_customer_id': _selectedCustomerId,
          'farm_session_id': _selectedSessionId,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate),
          'quantity': double.parse(_quantityController.text),
          'notes': _notesController.text.isEmpty ? null : _notesController.text,
        };

        if (widget.delivery != null) {
          deliveryData['id'] = widget.delivery!.id;
          _updateEndpoint += "${deliveryData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        print(jsonEncode(deliveryData));
        print(_addEndpoint);

        final response = await http.post(
          Uri.parse(widget.delivery == null ? _addEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(deliveryData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        print('Body: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.delivery == null ? 'Delivery added successfully!' : 'Delivery updated successfully!')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Failed to ${widget.delivery == null ? 'add' : 'update'} delivery')),
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
        print('Error ${widget.delivery == null ? 'adding' : 'updating'} delivery: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.delivery == null ? 'Add Delivery Record' : 'Edit Delivery Record'),
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
              if (_isLoadingCustomers)
                const Center(child: CircularProgressIndicator())
              else if (_customerFetchError != null)
                Center(
                  child: Text(
                    _customerFetchError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                TypeAheadField<CustomerForFilter>(
                  controller: _customerController,
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Customer',
                        hintText: 'Start typing customer name...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select or enter a customer';
                        }
                        if (_selectedCustomerId == null || !_allCustomers.any((customer) => customer.id == _selectedCustomerId && customer.name == value)) {
                          return 'Please select a valid customer from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allCustomers.where((customer) => customer.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                  },
                  itemBuilder: (context, CustomerForFilter suggestion) {
                    return ListTile(
                      title: Text(suggestion.name),
                      subtitle: Text('ID: ${suggestion.id}'),
                    );
                  },
                  onSelected: (CustomerForFilter suggestion) {
                    setState(() {
                      _customerController.text = suggestion.name;
                      _selectedCustomerId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Customer: ${suggestion.name}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading customers...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
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
                  builder: (context, controller, focusNode) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Farm Session',
                        hintText: 'Start typing session ID...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.event),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select or enter a farm session';
                        }
                        if (_selectedSessionId == null || !_allSessions.any((session) => session.id == _selectedSessionId && session.id.toString() == value)) {
                          return 'Please select a valid session from the suggestions.';
                        }
                        return null;
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty) {
                      return [];
                    }
                    return _allSessions.where((session) => session.id.toString().contains(pattern)).toList();
                  },
                  itemBuilder: (context, FarmSession suggestion) {
                    return ListTile(
                      title: Text('Session ${suggestion.id}'),
                      subtitle: suggestion.date != null
                          ? Text(DateFormat('yyyy-MM-dd').format(suggestion.date!))
                          : null,
                    );
                  },
                  onSelected: (FarmSession suggestion) {
                    setState(() {
                      _sessionController.text = suggestion.id.toString();
                      _selectedSessionId = suggestion.id;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected Session: ${suggestion.id}')),
                    );
                    _formKey.currentState?.validate();
                  },
                  loadingBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Loading sessions...', style: TextStyle(color: Colors.grey)),
                  ),
                  errorBuilder: (context, error) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Error loading suggestions: $error', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Delivery Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDeliveryDate),
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
                label: Text(_isSaving ? 'Saving...' : widget.delivery == null ? 'Add Delivery' : 'Update Delivery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FarmSession {
  final int id;
  final String name;
  final DateTime? date;

  FarmSession({required this.id, required this.name, this.date});

  factory FarmSession.fromJson(Map<String, dynamic> json) {
    return FarmSession(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name']?.toString() ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? ''),
    );
  }
}