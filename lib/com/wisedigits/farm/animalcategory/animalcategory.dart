import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addAnimalcategory.dart';

class AnimalCategory {
  final int id;
  final String name;
  final String? remarks;
  final int? createdBy;
  final DateTime? createdAt;
  final int? updatedBy;
  final DateTime? updatedAt;
  final String? ipAddress;

  AnimalCategory({
    required this.id,
    required this.name,
    this.remarks,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.ipAddress,
  });

  factory AnimalCategory.fromJson(Map<String, dynamic> json) {
    return AnimalCategory(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
      remarks: json['remarks'] as String?,
      createdBy: (json['created_by'] is num) ? (json['created_by'] as num).toInt() : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedBy: (json['updated_by'] is num) ? (json['updated_by'] as num).toInt() : null,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      ipAddress: json['ipaddress'] as String?,
    );
  }
}

class AnimalCategoriesListPage extends StatefulWidget {
  const AnimalCategoriesListPage({super.key});

  @override
  State<AnimalCategoriesListPage> createState() => _AnimalCategoriesListPageState();
}

class _AnimalCategoriesListPageState extends State<AnimalCategoriesListPage> {
  List<AnimalCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  final String _fetchEndpoint = '${Config.baseUrl}/modules/farm/animal-categories/';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

        print(_fetchEndpoint);
      final response = await http.get(
        Uri.parse(_fetchEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print('DEBUG: Animal categories response: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> categoriesData = responseData['data'];
        _categories = categoriesData.map((json) => AnimalCategory.fromJson(json)).toList();
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
      print('Error fetching animal categories: $e');
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
        title: const Text('Animal Categories'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchCategories,
            tooltip: 'Refresh Animal Categories',
          ),
        ],
      ),
      body: _isLoading
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
                onPressed: _fetchCategories,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _categories.isEmpty
          ? const Center(
        child: Text(
          'No animal categories found. Add one!',
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
            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Created By', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _categories.asMap().entries.map((entry) {
            int index = entry.key;
            AnimalCategory category = entry.value;
            return DataRow(
              cells: <DataCell>[
                DataCell(Text((index + 1).toString())),
                DataCell(
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimalCategoryFormPage(category: category),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchCategories();
                        }
                      });
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.2),
                      child: Text(
                        category.name,
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
                          builder: (context) => AnimalCategoryFormPage(category: category),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchCategories();
                        }
                      });
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.25),
                      child: Text(
                        category.remarks ?? 'N/A',
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
                          builder: (context) => AnimalCategoryFormPage(category: category),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchCategories();
                        }
                      });
                    },
                    child: Text(category.createdAt != null ? DateFormat('yyyy-MM-dd').format(category.createdAt!) : 'N/A'),
                  ),
                ),
                DataCell(
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimalCategoryFormPage(category: category),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchCategories();
                        }
                      });
                    },
                    child: Text(category.createdBy?.toString() ?? 'N/A'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnimalCategoryFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchCategories();
            }
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add New Animal Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}