import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../animalcategory/animalcategory.dart';
import 'feedingplans.dart';

class FeedingPlanFormPage extends StatefulWidget {
  final FeedingPlan? feedingPlan;

  const FeedingPlanFormPage({super.key, this.feedingPlan});

  @override
  State<FeedingPlanFormPage> createState() => _FeedingPlanFormPageState();
}

class _FeedingPlanFormPageState extends State<FeedingPlanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _feedItems = [];
  final List<TextEditingController> _quantityControllers = [];
  final List<TextEditingController> _notesControllers = [];

  List<InventoryItem> _inventoryItems = [];
  List<AnimalCategory> _animalCategories = [];
  int? _selectedAnimalCategoryId;
  bool _isLoadingItems = false;
  bool _isLoadingCategories = false;
  String? _errorMessage;
  bool _isSaving = false;

  final String _createEndpoint = '${Config.baseUrl}/modules/farm/feeding-plans/create';
  late String _updateEndpoint = '${Config.baseUrl}/modules/farm/feeding-plans/';
  final String _itemsEndpoint = '${Config.baseUrl}/modules/inv/items/';
  final String _detailsEndpoint = '${Config.baseUrl}/modules/farm/feeding-plans/';
  final String _categoriesEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/';

  @override
  void initState() {
    super.initState();
    _fetchInventoryItems();
    _fetchAnimalCategories().then((_) {
      if (widget.feedingPlan != null) {
        _nameController.text = widget.feedingPlan!.name;
        _descriptionController.text = widget.feedingPlan!.description ?? '';
        _selectedAnimalCategoryId = widget.feedingPlan!.animalCategoryId;
        _fetchFeedingPlanDetails();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    for (var controller in _notesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchInventoryItems() async {
    setState(() {
      _isLoadingItems = true;
      _errorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingItems = false;
        _errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_itemsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingItems = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        final List<dynamic> itemsData = decodedResponse is List ? decodedResponse : decodedResponse['data'] ?? [];
        if (itemsData.isEmpty) {
          setState(() {
            _errorMessage = 'No inventory items available';
          });
          return;
        }
        _inventoryItems = itemsData.map((json) => InventoryItem.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        setState(() {
          _errorMessage = 'Failed to load inventory items (Status: ${response.statusCode})';
        });
        print('DEBUG: Inventory fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _errorMessage = 'Error connecting to server: $e';
      });
      print('DEBUG: Error fetching inventory items: $e');
    }
  }

  Future<void> _fetchAnimalCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _errorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_categoriesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingCategories = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        final List<dynamic> categoriesData = decodedResponse is List ? decodedResponse : decodedResponse['data'] ?? [];
        if (categoriesData.isEmpty) {
          setState(() {
            _errorMessage = 'No animal categories available';
          });
          return;
        }
        _animalCategories = categoriesData.map((json) => AnimalCategory.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        setState(() {
          _errorMessage = 'Failed to load animal categories (Status: ${response.statusCode})';
        });
        print('DEBUG: Animal categories fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        _errorMessage = 'Error connecting to server: $e';
      });
      print('DEBUG: Error fetching animal categories: $e');
    }
  }

  Future<void> _fetchFeedingPlanDetails() async {
    if (widget.feedingPlan == null) return;

    setState(() {
      _isLoadingItems = true;
      _errorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingItems = false;
        _errorMessage = 'Authentication required';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_detailsEndpoint${widget.feedingPlan!.id}/details'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingItems = false;
      });

      if (response.statusCode == 200) {
        final List<dynamic> detailsData = jsonDecode(response.body)['data'] ?? [];
        setState(() {
          _feedItems.clear();
          _quantityControllers.clear();
          _notesControllers.clear();
          for (var detail in detailsData) {
            final itemName = _inventoryItems.firstWhere(
                  (item) => item.id == detail['inv_item_id'],
              orElse: () => InventoryItem(id: 0, name: 'Unknown'),
            ).name;
            _feedItems.add({
              'invItemId': detail['inv_item_id'],
              'quantity': detail['quantity'].toString(),
              'feedingFrequency': detail['feeding_frequency'] ?? 'daily',
              'notes': detail['notes'] ?? '',
              'itemName': itemName,
            });
            _quantityControllers.add(TextEditingController(text: detail['quantity'].toString()));
            _notesControllers.add(TextEditingController(text: detail['notes'] ?? ''));
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load plan details (Status: ${response.statusCode})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _errorMessage = 'Error fetching plan details: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  void _addFeedItem() {
    setState(() {
      _feedItems.add({
        'invItemId': null,
        'quantity': '',
        'feedingFrequency': 'daily',
        'notes': '',
        'itemName': '',
      });
      _quantityControllers.add(TextEditingController());
      _notesControllers.add(TextEditingController());
    });
  }

  void _removeFeedItem(int index) {
    setState(() {
      _feedItems.removeAt(index);
      _quantityControllers[index].dispose();
      _quantityControllers.removeAt(index);
      _notesControllers[index].dispose();
      _notesControllers.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_feedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one feed item')),
        );
        return;
      }
      if (_selectedAnimalCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an animal category')),
        );
        return;
      }
      for (var item in _feedItems) {
        if (item['invItemId'] == null || item['itemName'].isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a valid inventory item for all feed items')),
          );
          return;
        }
        if (item['quantity'].isEmpty || double.tryParse(item['quantity']) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid quantity for all feed items')),
          );
          return;
        }
      }

      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final Map<String, dynamic> planData = {
          'name': _nameController.text,
          'description': _descriptionController.text.isEmpty ? null : _descriptionController.text,
          'farm_animal_category_id': _selectedAnimalCategoryId,
          'ipaddress': null,
          'details': _feedItems.map((item) => {
            'inv_item_id': item['invItemId'],
            'quantity': double.parse(item['quantity']),
            'feeding_frequency': item['feedingFrequency'],
            'notes': item['notes'].isEmpty ? null : item['notes'],
          }).toList(),
        };

        if (widget.feedingPlan != null) {
          planData['id'] = widget.feedingPlan!.id;
          _updateEndpoint += "${planData['id']}/edit";
        }

        final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
        final authToken = sessionProvider.currentUser?.token;

        if (authToken == null) {
          throw Exception('User not authenticated');
        }

        final response = await http.post(
          Uri.parse(widget.feedingPlan == null ? _createEndpoint : _updateEndpoint),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode(planData),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        setState(() {
          _isSaving = false;
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.feedingPlan == null ? 'Feeding plan added successfully' : 'Feeding plan updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          } else {
            setState(() {
              _errorMessage = responseData['message'] ?? 'Failed to ${widget.feedingPlan == null ? 'add' : 'update'} feeding plan';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorMessage!)),
            );
          }
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
          _isSaving = false;
          _errorMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
        print('Error ${widget.feedingPlan == null ? 'adding' : 'updating'} feeding plan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feedingPlan == null ? 'Add Feeding Plan' : 'Edit Feeding Plan'),
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
                  labelText: 'Plan Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Plan name is required';
                  }
                  if (value.length > 100) {
                    return 'Name must be 100 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedAnimalCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Animal Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                items: _animalCategories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedAnimalCategoryId = newValue;
                  });
                },
                validator: (value) => value == null ? 'Select an animal category' : null,
                hint: const Text('Select animal category'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 24),
              const Text(
                'Feed Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingItems || _isLoadingCategories)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_inventoryItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No inventory items available',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _feedItems.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              TypeAheadField<InventoryItem>(
                                controller: TextEditingController(text: _feedItems[index]['itemName']),
                                builder: (context, controller, focusNode) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Inventory Item',
                                      hintText: 'Type to search items...',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.inventory),
                                      suffixIcon: controller.text.isNotEmpty
                                          ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          controller.clear();
                                          setState(() {
                                            _feedItems[index]['invItemId'] = null;
                                            _feedItems[index]['itemName'] = '';
                                          });
                                        },
                                      )
                                          : null,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Select an inventory item';
                                      }
                                      if (!_inventoryItems.any((item) => item.name == value)) {
                                        return 'Select a valid item';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                suggestionsCallback: (pattern) async {
                                  if (pattern.isEmpty) return [];
                                  return _inventoryItems.where((item) => item.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                                },
                                itemBuilder: (context, suggestion) {
                                  return ListTile(
                                    title: Text(suggestion.name),
                                    subtitle: Text('ID: ${suggestion.id}'),
                                  );
                                },
                                onSelected: (InventoryItem suggestion) {
                                  setState(() {
                                    _feedItems[index]['invItemId'] = suggestion.id;
                                    _feedItems[index]['itemName'] = suggestion.name;
                                  });
                                },
                                loadingBuilder: (context) => const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Loading items...', style: TextStyle(color: Colors.grey)),
                                ),
                                errorBuilder: (context, error) => Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
                                ),
                                emptyBuilder: (context) => const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('No items found', style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _quantityControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.scale),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantity is required';
                                  }
                                  final parsed = double.tryParse(value);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Enter a valid positive number';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  _feedItems[index]['quantity'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _feedItems[index]['feedingFrequency'],
                                decoration: const InputDecoration(
                                  labelText: 'Feeding Frequency',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.repeat),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                                ],
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _feedItems[index]['feedingFrequency'] = newValue ?? 'daily';
                                  });
                                },
                                validator: (value) => value == null ? 'Select a frequency' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _notesControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Notes (Optional)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.notes),
                                ),
                                maxLines: 2,
                                onChanged: (value) {
                                  _feedItems[index]['notes'] = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _removeFeedItem(index),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('Remove Item', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _inventoryItems.isEmpty || _animalCategories.isEmpty ? null : _addFeedItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Feed Item'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving || _inventoryItems.isEmpty || _animalCategories.isEmpty ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : widget.feedingPlan == null ? 'Add Plan' : 'Update Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}