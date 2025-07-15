import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../animalcategory/animalcategory.dart';
import '../feeding/feeding.dart';
import 'addFeedingPlans.dart';
import 'feedingplans.dart';

class FeedingPlansListPage extends StatefulWidget {
  const FeedingPlansListPage({super.key});

  @override
  State<FeedingPlansListPage> createState() => _FeedingPlansListPageState();
}

class _FeedingPlansListPageState extends State<FeedingPlansListPage> {
  List<FeedingPlan> _feedingPlans = [];
  List<AnimalCategory> _animalCategories = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  AnimalCategory? _selectedCategory;

  final String _endpoint = '${Config.baseUrl}/modules/farm/feeding-plans/';
  final String _categoriesEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/';

  @override
  void initState() {
    super.initState();
    _fetchFeedingPlans();
    _fetchAnimalCategories();
  }

  Future<void> _fetchFeedingPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please log in to continue';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_endpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final List<dynamic> feedingPlansData = jsonDecode(response.body)['data'] ?? [];
        setState(() {
          _feedingPlans = feedingPlansData.map((json) => FeedingPlan.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load feeding plans (Status: ${response.statusCode})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching feeding plans: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  Future<void> _fetchAnimalCategories() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication required';
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

      if (response.statusCode == 200) {
        final List<dynamic> categoriesData = jsonDecode(response.body)['data'] ?? [];
        setState(() {
          _animalCategories = categoriesData.map((json) => AnimalCategory.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load animal categories (Status: ${response.statusCode})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching animal categories: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        AnimalCategory? tempSelectedCategory = _selectedCategory;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Feeding Plans'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<AnimalCategory>(
                    isExpanded: true,
                    hint: const Text('Select Animal Category'),
                    value: tempSelectedCategory,
                    items: _animalCategories.map((category) {
                      return DropdownMenuItem<AnimalCategory>(
                        value: category,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (AnimalCategory? newValue) {
                      setState(() {
                        tempSelectedCategory = newValue;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = tempSelectedCategory;
                    });
                    Navigator.of(context).pop();
                    _fetchFeedingPlans();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlans = _feedingPlans.where((plan) {
      final matchesSearch = plan.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (plan.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _selectedCategory == null || plan.animalCategoryId == _selectedCategory?.id;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding Plans'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedingPlanFormPage()),
              ).then((result) {
                if (result == true) {
                  _fetchFeedingPlans();
                }
              });
            },
            tooltip: 'Add Feeding Plan',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FeedingPlanFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchFeedingPlans();
            }
          });
        },
        label: const Text('Add'),
        icon: const Icon(Icons.add),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add Feeding Plan',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : filteredPlans.isEmpty
                ? const Center(child: Text('No feeding plans found'))
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Created At')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filteredPlans.map((plan) {
                  final categoryName = _animalCategories
                      .firstWhere(
                        (category) => category.id == plan.animalCategoryId,
                    orElse: () => AnimalCategory(id: 0, name: 'Unknown'),
                  )
                      .name;
                  return DataRow(cells: [
                    DataCell(Text(plan.name)),
                    DataCell(Text(categoryName)),
                    DataCell(Text(plan.description ?? '')),
                    DataCell(Text(
                        plan.createdAt != null ? DateFormat('yyyy-MM-dd').format(plan.createdAt!) : '')),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedingPlanFormPage(feedingPlan: plan),
                            ),
                          ).then((result) {
                            if (result == true) {
                              _fetchFeedingPlans();
                            }
                          });
                        },
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}