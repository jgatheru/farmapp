// shades_form.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart'; // For jsonEncode

class ShadesFormPage extends StatefulWidget {
  const ShadesFormPage({super.key});

  @override
  State<ShadesFormPage> createState() => _ShadesFormPageState();
}

class _ShadesFormPageState extends State<ShadesFormPage> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation
  final TextEditingController _shadeNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false; // To show loading indicator during submission

  // Replace with your actual PHP endpoint URL for shades
  final String _phpEndpoint = '${Config.baseUrl}/modules/farm/shades/create/';

  @override
  void dispose() {
    _shadeNameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        final response = await http.post(
          Uri.parse(_phpEndpoint),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(<String, dynamic>{
            'shade_name': _shadeNameController.text,
            'location': _locationController.text,
            'capacity': int.parse(_capacityController.text), // Parse to int
            'description': _descriptionController.text,
          }),
        );

        if (context.mounted) { // Check if widget is still mounted before showing SnackBar
          setState(() {
            _isLoading = false;
          });

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(responseData['message'] ?? 'Shade added successfully!')),
              );
              // Clear the form fields after successful submission
              _shadeNameController.clear();
              _locationController.clear();
              _capacityController.clear();
              _descriptionController.clear();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(responseData['message'] ?? 'Failed to add shade.')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Server error: ${response.statusCode}')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Network error: $e')),
          );
        }
        print('Error submitting shade data: $e'); // For debugging
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Shade'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView( // Use SingleChildScrollView to prevent overflow on keyboard
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Shade Name Field
              TextFormField(
                controller: _shadeNameController,
                decoration: const InputDecoration(
                  labelText: 'Shade Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shelves), // Using a shelf icon for shades
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a shade name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Capacity Field
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number, // Ensure numeric keyboard
                decoration: const InputDecoration(
                  labelText: 'Capacity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people), // Icon for capacity
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter capacity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3, // Allows for multi-line input
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  alignLabelWithHint: true, // Align label to the top for multiline
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              Center(
                child: _isLoading
                    ? CircularProgressIndicator(color: Config.themeColor)
                    : ElevatedButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save),
                  label: const Text('Add Shade'),
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
