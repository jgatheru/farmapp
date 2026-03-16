import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'addFeeding.dart';

class Feeding {
  final int id;
  final int? farmAnimalId;
  final int? shadeId;
  final int invItemId;
  final DateTime feedingDate;
  final double quantity;
  final double? cost;
  final String? notes;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;
  final Map<String, dynamic>? animal;
  final Map<String, dynamic>? shade;
  final Map<String, dynamic>? item;

  Feeding({
    required this.id,
    this.farmAnimalId,
    this.shadeId,
    required this.invItemId,
    required this.feedingDate,
    required this.quantity,
    this.cost,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
    this.animal,
    this.shade,
    this.item,
  });

  factory Feeding.fromJson(Map<String, dynamic> json) {
    return Feeding(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      farmAnimalId: (json['farm_animal_id'] is num) ? (json['farm_animal_id'] as num).toInt() : null,
      shadeId: (json['farm_shade_id'] is num) ? (json['farm_shade_id'] as num).toInt() : null,
      invItemId: (json['inv_item_id'] is num) ? (json['inv_item_id'] as num).toInt() : 0,
      feedingDate: DateTime.tryParse(json['feeding_date'] as String? ?? '') ?? DateTime(2000),
      quantity: json['quantity'] != null
          ? (json['quantity'] is num
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity'].toString()) ?? 0.0)
          : 0.0,
      cost: json['cost'] != null
          ? (json['cost'] is num
          ? (json['cost'] as num).toDouble()
          : double.tryParse(json['cost'].toString()) ?? 0.0)
          : 0.0,
      notes: json['notes'] as String?,
      ipAddress: json['ipaddress'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: (json['updated_by'] is num) ? (json['updated_by'] as num).toInt() : null,
      createdBy: (json['created_by'] is num) ? (json['created_by'] as num).toInt() : null,
      animal: json['animal'] is Map<String, dynamic> ? json['animal'] as Map<String, dynamic> : null,
      // FIX: Handle boolean shade values by converting to null
      shade: json['shade'] is Map<String, dynamic> ? json['shade'] as Map<String, dynamic> : null,
      item: json['item'] is Map<String, dynamic> ? json['item'] as Map<String, dynamic> : null,
    );
  }
}

class AnimalForFilter {
  final int id;
  final String tagNumber;

  AnimalForFilter({required this.id, required this.tagNumber});

  factory AnimalForFilter.fromJson(Map<String, dynamic> json) {
    return AnimalForFilter(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      tagNumber: json['tag_number'] as String? ?? 'Unknown',
    );
  }
}

class InventoryItem {
  final int id;
  final String name;

  InventoryItem({required this.id, required this.name});

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class ShadeForFilter {
  final int id;
  final String name;

  ShadeForFilter({required this.id, required this.name});

  factory ShadeForFilter.fromJson(Map<String, dynamic> json) {
    return ShadeForFilter(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}

class FeedingsListPage extends StatefulWidget {
  const FeedingsListPage({super.key});

  @override
  State<FeedingsListPage> createState() => _FeedingsListPageState();
}

class _FeedingsListPageState extends State<FeedingsListPage> {
  List<Feeding> _records = [];
  List<AnimalForFilter> _allAnimals = [];
  List<InventoryItem> _allInventoryItems = [];
  List<ShadeForFilter> _allShades = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int? _selectedAnimalId;
  int? _selectedShadeId;

  // final String _fetchEndpoint = '${Config.baseUrl}/modules/farm/feedings/';
  final String _fetchEndpoint = 'http://213.136.81.123/farm/feedings/getFeedings.php';
  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchItemsEndpoint = '${Config.baseUrl}/modules/inv/items/';
  final String _fetchShadesEndpoint = '${Config.baseUrl}/modules/farm/shades/';

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _fetchRecords();
    _fetchAnimals();
    _fetchInventoryItems();
    _fetchShades();
  }

  Future<void> _fetchAnimals() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
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

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allAnimals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allAnimals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _errorMessage = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect to fetch animals: $e';
      });
    }
  }

  Future<void> _fetchInventoryItems() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchItemsEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allInventoryItems = decodedResponse.map((json) => InventoryItem.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allInventoryItems = (decodedResponse['data'] as List).map((json) => InventoryItem.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _errorMessage = decodedResponse['message'] ?? 'Failed to load inventory items: Invalid API format.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load inventory items: Server returned status ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect to fetch inventory items: $e';
      });
    }
  }

  Future<void> _fetchShades() async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchShadesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        if (decodedResponse is List) {
          _allShades = decodedResponse.map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          _allShades = (decodedResponse['data'] as List).map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _errorMessage = decodedResponse['message'] ?? 'Failed to load shades: Invalid API format.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load shades: Server returned status ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not connect to fetch shades: $e';
      });
    }
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String url = _fetchEndpoint;
      url += '?from_date=${DateFormat('yyyy-MM-dd').format(_fromDate)}';
      url += '&to_date=${DateFormat('yyyy-MM-dd').format(_toDate)}';
      if (_selectedAnimalId != null) {
        url += '&farm_animal_id=$_selectedAnimalId';
      }
      if (_selectedShadeId != null) {
        url += '&farm_shade_id=$_selectedShadeId';
      }

      print(url);

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print('DEBUG: Feedings response: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> recordsData = responseData['body'] ?? [];

          // FIX: Remove the problematic filter condition
          _records = recordsData
              .map((json) => Feeding.fromJson(json))
          // Remove this filter as it's incorrectly filtering out valid records
          // .where((record) => (record.farmAnimalId != null) != (record.shadeId != null))
              .toList();

          print('DEBUG: Loaded ${_records.length} records'); // Debug line
        } else {
          _errorMessage = responseData['message'] ?? 'Failed to fetch records';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
        }
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
      print('Error fetching feedings: $e');
    }
  }

  Future<void> _showFilterDialog() async {
    final Map<String, dynamic>? filters = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return FeedingFilterDialog(
          initialFromDate: _fromDate,
          initialToDate: _toDate,
          initialAnimalId: _selectedAnimalId,
          initialShadeId: _selectedShadeId,
        );
      },
    );

    if (filters != null) {
      setState(() {
        _fromDate = filters['fromDate'];
        _toDate = filters['toDate'];
        _selectedAnimalId = filters['animalId'];
        _selectedShadeId = filters['shadeId'];
      });
      _fetchRecords();
    }
  }

  String _getAnimalTagNumber(int? animalId, Map<String, dynamic>? animal) {
    if (animal != null && animal['name'] != null) {
      return animal['name'] as String;
    }
    return _allAnimals.firstWhere(
          (animal) => animal.id == animalId,
      orElse: () => AnimalForFilter(id: 0, tagNumber: ''),
    ).tagNumber;
  }

  String _getItemName(int itemId, Map<String, dynamic>? item) {
    if (item != null && item['name'] != null) {
      return item['name'] as String;
    }
    return _allInventoryItems.firstWhere(
          (item) => item.id == itemId,
      orElse: () => InventoryItem(id: 0, name: ''),
    ).name;
  }

  String _getShadeName(int? shadeId, Map<String, dynamic>? shade) {
    if (shade != null && shade['name'] != null) {
      return shade['name'] as String;
    }
    return _allShades.firstWhere(
          (shade) => shade.id == shadeId,
      orElse: () => ShadeForFilter(id: 0, name: ''),
    ).name;
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
        title: const Text('Feeding Records'),
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Feedings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchRecords,
            tooltip: 'Refresh Feedings',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Showing feedings from ${DateFormat('yyyy-MM-dd').format(_fromDate)} '
                  'to ${DateFormat('yyyy-MM-dd').format(_toDate)}'
                  '${_selectedAnimalId != null ? ' for Animal: ${_getAnimalTagNumber(_selectedAnimalId, null)}' : ''}'
                  '${_selectedShadeId != null ? ' for Shade: ${_getShadeName(_selectedShadeId, null)}' : ''}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: _isLoading
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
                      onPressed: _fetchRecords,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : _records.isEmpty
                ? const Center(
              child: Text(
                'No feeding records found for the selected filters. Add one!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : Scrollbar(
              thumbVisibility: true, // Makes the scrollbar always visible
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical, // Enable vertical scrolling
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // Existing horizontal scrolling
                  child: DataTable(
                    columnSpacing: 16.0,
                    dataRowMinHeight: 38.0,
                    dataRowMaxHeight: 40.0,
                    headingRowColor: WidgetStateProperty.resolveWith(
                            (states) => Config.themeColor.withOpacity(0.1)),
                    columns: const <DataColumn>[
                      DataColumn(
                          label: Text('ID',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Animal',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Shade',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Item',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Date',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Quantity',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Cost',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Notes',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Actions',
                              style:
                              TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _records.map((record) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(record.id.toString()),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(_getAnimalTagNumber(
                                  record.farmAnimalId, record.animal)),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(
                                  _getShadeName(record.shadeId, record.shade)),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(
                                  _getItemName(record.invItemId, record.item)),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(DateFormat('yyyy-MM-dd')
                                  .format(record.feedingDate)),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(record.quantity.toStringAsFixed(2)),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: Text(record.cost != null
                                  ? record.cost!.toStringAsFixed(2)
                                  : ''),
                            ),
                          ),
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth:
                                    MediaQuery.of(context).size.width *
                                        0.25),
                                child: Text(
                                  record.notes ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FeedingFormPage(feeding: record),
                                  ),
                                ).then((result) {
                                  if (result == true) {
                                    _fetchRecords();
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FeedingFormPage()),
          ).then((result) {
            if (result == true) {
              _fetchRecords();
            }
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        tooltip: 'Add New Feeding Record',
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class FeedingFilterDialog extends StatefulWidget {
  final DateTime initialFromDate;
  final DateTime initialToDate;
  final int? initialAnimalId;
  final int? initialShadeId;

  const FeedingFilterDialog({
    super.key,
    required this.initialFromDate,
    required this.initialToDate,
    this.initialAnimalId,
    this.initialShadeId,
  });

  @override
  State<FeedingFilterDialog> createState() => _FeedingFilterDialogState();
}

class _FeedingFilterDialogState extends State<FeedingFilterDialog> {
  late DateTime _selectedFromDate;
  late DateTime _selectedToDate;
  AnimalForFilter? _selectedAnimal;
  ShadeForFilter? _selectedShade;
  List<AnimalForFilter> _animals = [AnimalForFilter(id: 0, tagNumber: 'All Animals')];
  List<ShadeForFilter> _shades = [ShadeForFilter(id: 0, name: 'All Shades')];
  bool _isLoadingAnimals = false;
  bool _isLoadingShades = false;
  String? _animalErrorMessage;
  String? _shadeErrorMessage;

  final TextEditingController _animalSearchController = TextEditingController();
  final TextEditingController _shadeSearchController = TextEditingController();

  final String _fetchAnimalsEndpoint = '${Config.baseUrl}/modules/farm/animals/';
  final String _fetchShadesEndpoint = '${Config.baseUrl}/modules/farm/shades/';

  @override
  void initState() {
    super.initState();
    _selectedFromDate = widget.initialFromDate;
    _selectedToDate = widget.initialToDate;
    _fetchAnimals();
    _fetchShades();
  }

  @override
  void dispose() {
    _animalSearchController.dispose();
    _shadeSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoadingAnimals = true;
      _animalErrorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingAnimals = false;
        _animalErrorMessage = 'User not authenticated';
      });
      return;
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
        List<AnimalForFilter> fetchedAnimals = [];
        if (decodedResponse is List) {
          fetchedAnimals = decodedResponse.map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          fetchedAnimals = (decodedResponse['data'] as List).map((json) => AnimalForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _animalErrorMessage = decodedResponse['message'] ?? 'Failed to load animals: Invalid API format.';
          });
          print('DEBUG: Animal API response not valid: $decodedResponse');
          return;
        }
        setState(() {
          _animals = [AnimalForFilter(id: 0, tagNumber: 'All Animals'), ...fetchedAnimals];
          if (widget.initialAnimalId != null) {
            _selectedAnimal = _animals.firstWhere(
                  (animal) => animal.id == widget.initialAnimalId,
              orElse: () => AnimalForFilter(id: 0, tagNumber: 'All Animals'),
            );
            _animalSearchController.text = _selectedAnimal!.tagNumber;
          }
        });
      } else {
        setState(() {
          _animalErrorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
        });
        print('DEBUG: Animal fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnimals = false;
        _animalErrorMessage = 'Could not connect to fetch animals: $e';
      });
      print('DEBUG: Error fetching animals: $e');
    }
  }

  Future<void> _fetchShades() async {
    setState(() {
      _isLoadingShades = true;
      _shadeErrorMessage = null;
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      setState(() {
        _isLoadingShades = false;
        _shadeErrorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(_fetchShadesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        _isLoadingShades = false;
      });

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);
        List<ShadeForFilter> fetchedShades = [];
        if (decodedResponse is List) {
          fetchedShades = decodedResponse.map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else if (decodedResponse is Map<String, dynamic> && decodedResponse['data'] is List) {
          fetchedShades = (decodedResponse['data'] as List).map((json) => ShadeForFilter.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          setState(() {
            _shadeErrorMessage = decodedResponse['message'] ?? 'Failed to load shades: Invalid API format.';
          });
          print('DEBUG: Shade API response not valid: $decodedResponse');
          return;
        }
        setState(() {
          _shades = [ShadeForFilter(id: 0, name: 'All Shades'), ...fetchedShades];
          if (widget.initialShadeId != null) {
            _selectedShade = _shades.firstWhere(
                  (shade) => shade.id == widget.initialShadeId,
              orElse: () => ShadeForFilter(id: 0, name: 'All Shades'),
            );
            _shadeSearchController.text = _selectedShade!.name;
          }
        });
      } else {
        setState(() {
          _shadeErrorMessage = 'Failed to load shades: Server returned status ${response.statusCode}';
        });
        print('DEBUG: Shade fetch failed. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingShades = false;
        _shadeErrorMessage = 'Could not connect to fetch shades: $e';
      });
      print('DEBUG: Error fetching shades: $e');
    }
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFromDate,
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
    if (picked != null && picked != _selectedFromDate) {
      setState(() {
        _selectedFromDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedToDate,
      firstDate: _selectedFromDate,
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
    if (picked != null && picked != _selectedToDate) {
      setState(() {
        _selectedToDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _applyFilters() {
    if (_selectedAnimal != null && _selectedShade != null && _selectedAnimal!.id != 0 && _selectedShade!.id != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select either an animal or a shade, not both')),
      );
      return;
    }
    Navigator.pop(context, {
      'fromDate': _selectedFromDate,
      'toDate': _selectedToDate,
      'animalId': _selectedAnimal?.id == 0 ? null : _selectedAnimal?.id,
      'shadeId': _selectedShade?.id == 0 ? null : _selectedShade?.id,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFromDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedToDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _selectedAnimal = null;
      _selectedShade = null;
      _animalSearchController.clear();
      _shadeSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Feeding Records'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit dialog height
          maxWidth: MediaQuery.of(context).size.width * 0.8, // Limit dialog width
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'From Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedFromDate),
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectFromDate(context),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'To Date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedToDate),
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectToDate(context),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _isLoadingAnimals
                  ? const CircularProgressIndicator()
                  : _animalErrorMessage != null
                  ? Text(
                'Error loading animals: $_animalErrorMessage',
                style: const TextStyle(color: Colors.red),
              )
                  : Autocomplete<AnimalForFilter>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  return _animals.where((animal) {
                    return animal.tagNumber.toLowerCase().contains(query) || query.isEmpty;
                  });
                },
                displayStringForOption: (AnimalForFilter option) => option.tagNumber,
                fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                  if (_selectedAnimal != null && fieldTextEditingController.text.isEmpty) {
                    fieldTextEditingController.text = _selectedAnimal!.tagNumber;
                  }
                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Filter by Animal Tag Number',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pets),
                      suffixIcon: fieldTextEditingController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          fieldTextEditingController.clear();
                          setState(() {
                            _selectedAnimal = null;
                            _selectedShade = null; // Clear shade when animal is cleared
                            _shadeSearchController.clear();
                          });
                        },
                      )
                          : null,
                    ),
                    onChanged: (text) {
                      if (text.isEmpty) {
                        setState(() {
                          _selectedAnimal = null;
                          _selectedShade = null; // Clear shade when animal is cleared
                          _shadeSearchController.clear();
                        });
                      }
                    },
                  );
                },
                onSelected: (AnimalForFilter selection) {
                  setState(() {
                    _selectedAnimal = selection.id == 0 ? null : selection;
                    if (_selectedAnimal != null) {
                      _selectedShade = null; // Clear shade if animal is selected
                      _shadeSearchController.clear();
                    }
                    _animalSearchController.text = _selectedAnimal?.tagNumber ?? '';
                  });
                  FocusScope.of(context).unfocus();
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<AnimalForFilter> onSelected, Iterable<AnimalForFilter> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final AnimalForFilter option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(option.tagNumber),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _isLoadingShades
                  ? const CircularProgressIndicator()
                  : _shadeErrorMessage != null
                  ? Text(
                'Error loading shades: $_shadeErrorMessage',
                style: const TextStyle(color: Colors.red),
              )
                  : Autocomplete<ShadeForFilter>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  return _shades.where((shade) {
                    return shade.name.toLowerCase().contains(query) || query.isEmpty;
                  });
                },
                displayStringForOption: (ShadeForFilter option) => option.name,
                fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                  if (_selectedShade != null && fieldTextEditingController.text.isEmpty) {
                    fieldTextEditingController.text = _selectedShade!.name;
                  }
                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Filter by Shade Name',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.roofing),
                      suffixIcon: fieldTextEditingController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          fieldTextEditingController.clear();
                          setState(() {
                            _selectedShade = null;
                            _selectedAnimal = null; // Clear animal when shade is cleared
                            _animalSearchController.clear();
                          });
                        },
                      )
                          : null,
                    ),
                    onChanged: (text) {
                      if (text.isEmpty) {
                        setState(() {
                          _selectedShade = null;
                          _selectedAnimal = null; // Clear animal when shade is cleared
                          _animalSearchController.clear();
                        });
                      }
                    },
                  );
                },
                onSelected: (ShadeForFilter selection) {
                  setState(() {
                    _selectedShade = selection.id == 0 ? null : selection;
                    if (_selectedShade != null) {
                      _selectedAnimal = null; // Clear animal if shade is selected
                      _animalSearchController.clear();
                    }
                    _shadeSearchController.text = _selectedShade?.name ?? '';
                  });
                  FocusScope.of(context).unfocus();
                },
                optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<ShadeForFilter> onSelected, Iterable<ShadeForFilter> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ShadeForFilter option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(option.name),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _clearFilters();
            _applyFilters();
          },
          style: TextButton.styleFrom(foregroundColor: Config.themeColor),
          child: const Text('Clear Filters'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: Config.themeColor),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          style: ElevatedButton.styleFrom(
            backgroundColor: Config.themeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply Filters'),
        ),
      ],
    );
  }
}