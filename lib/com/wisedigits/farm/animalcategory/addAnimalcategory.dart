import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'animalcategory.dart';

class AnimalCategoryFormPage extends StatefulWidget {
  final AnimalCategory? category;

  const AnimalCategoryFormPage({super.key, this.category});

  @override
  State<AnimalCategoryFormPage> createState() => _AnimalCategoryFormPageState();
}

class _AnimalCategoryFormPageState extends State<AnimalCategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _isSaving = false;

  final String _addEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/';

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      // Edit mode: Populate fields with category data
      _nameController.text = widget.category!.name;
      _remarksController.text = widget.category!.remarks ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final Map<String, dynamic> categoryData = {
          'name': _nameController.text,
          'remarks': _remarksController.text.isEmpty ? null : _remarksController.text,
        };

        if (widget.category != null) {
          categoryData['id'] = widget.category!.id;
          _updateEndpoint += "${categoryData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        print('DEBUG: Submitting to ${_updateEndpoint} with data: $categoryData');

        final response = await http.post(
          Uri.parse(widget.category == null ? _addEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(categoryData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        print('DEBUG: Response: ${response.body}');
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.category == null ? 'Animal category added successfully!' : 'Animal category updated successfully!')),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(responseData['message'] ?? 'Failed to ${widget.category == null ? 'add' : 'update'} animal category')),
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
        print('Error ${widget.category == null ? 'adding' : 'updating'} animal category: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add Animal Category' : 'Edit Animal Category'),
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter category name (e.g., Cattle)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                keyboardType: TextInputType.text,
                maxLength: 32,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category name';
                  }
                  if (value.length > 32) {
                    return 'Name cannot exceed 32 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  hintText: 'Enter any additional remarks',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
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
                label: Text(_isSaving ? 'Saving...' : widget.category == null ? 'Add Category' : 'Update Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}