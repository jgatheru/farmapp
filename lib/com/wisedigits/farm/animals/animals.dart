import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart'; // For shimmer effect

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'animaldetails.dart'; // Import the details page

// Model class for Feeding Record
class FeedingRecord {
  final int id;
  final String feedType;
  final double quantity;
  final DateTime date;

  FeedingRecord({
    required this.id,
    required this.feedType,
    required this.quantity,
    required this.date,
  });

  factory FeedingRecord.fromJson(Map<String, dynamic> json) {
    return FeedingRecord(
      id: json['id'] as int,
      feedType: json['feed_type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}

// Model class for Health Record
class HealthRecord {
  final int id;
  final String condition;
  final String treatment;
  final DateTime date;

  HealthRecord({
    required this.id,
    required this.condition,
    required this.treatment,
    required this.date,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as int,
      condition: json['condition'] as String,
      treatment: json['treatment'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

class ProductionRecord {
  final String productionType; // e.g., 'Milk', 'Eggs', 'Weight Gain'
  final double quantity;       // e.g., Liters of milk, number of eggs, KG gained
  final DateTime date;
  final String? notes; // Optional notes

  ProductionRecord({
    required this.productionType,
    required this.quantity,
    required this.date,
    this.notes,
  });

  factory ProductionRecord.fromJson(Map<String, dynamic> json) {
    return ProductionRecord(
      productionType: json['production_type'],
      quantity: (json['quantity'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }
}

// Model class for a single Animal
class Animal {
  final int animalId;
  final String tagNumber;
  final String species;
  final String? breed;
  final DateTime birthDate;
  final String gender;
  final double weight;
  final double production;
  final int? shadeId; // Nullable
  final int? animalCategoryId;
  final DateTime? acquisitionDate; // Nullable
  final double? acquisitionCost; // Nullable
  final String status;
  final DateTime createdAt;
  final List<String>? displayFields; // Optional field to control display
  final Color? cardColor; // Color for the Card widget
  final List<FeedingRecord> feedingRecords;
  final List<HealthRecord> healthRecords;
  final List<ProductionRecord> productionRecords;
  final String? photoUrl; // Photo URL

  Animal({
    required this.animalId,
    required this.tagNumber,
    required this.species,
    this.breed,
    required this.birthDate,
    required this.gender,
    required this.weight,
    required this.production,
    this.shadeId,
    this.animalCategoryId,
    this.acquisitionDate,
    this.acquisitionCost,
    required this.status,
    required this.createdAt,
    this.displayFields,
    this.cardColor,
    this.feedingRecords = const [],
    this.healthRecords = const [],
    this.productionRecords = const [],
    this.photoUrl,
  });

  // Factory constructor to create an Animal object from a JSON map
  factory Animal.fromJson(Map<String, dynamic> json) {
    print('DEBUG: JSON Data: $json');

    // Parse hex color string to Color object
    Color? parseColor(String? hexColor) {
      if (hexColor == null || hexColor.isEmpty) return null;
      try {
        final hex = hexColor.replaceFirst('#', '');
        final intColor = int.parse(hex, radix: 16);
        return Color(hex.length == 6 ? (0xFF000000 | intColor) : intColor);
      } catch (e) {
        return null; // Invalid color falls back to null
      }
    }

    return Animal(
      animalId: (json['id'] is num) ? (json['id'] as num).toInt() : 0,
      tagNumber: (json['tag_number'] as String?) ?? 'N/A',
      species: (json['species'] as String?) ?? 'N/A',
      breed: json['breed'] as String?,
      birthDate: DateTime.tryParse(json['birth_date'] as String? ?? '') ?? DateTime(2000),
      gender: (json['gender']['name'] as String?) ?? 'Unknown',
      weight: (json['weight'] is num) ? (json['weight'] as num).toDouble() : 0.0,
      production: (json['production'] is num) ? (json['production'] as num).toDouble() : 0.0,
      shadeId: json['shade']['id'] as int?,
      animalCategoryId: json['category']['id'] as int?,
      acquisitionDate: DateTime.tryParse(json['acquisition_date'] as String? ?? ''),
      acquisitionCost: (json['acquisition_cost'] is num) ? (json['acquisition_cost'] as num).toDouble() : 0.0,
      status: (json['status'] as String?) ?? 'Unknown',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      displayFields: json['displayFields'] != null
          ? List<String>.from(json['displayFields'] as List)
          : null,
      cardColor: parseColor(json['cardColor'] as String?),
      feedingRecords: (json['feeding_records'] as List<dynamic>?)
          ?.map((e) => FeedingRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      healthRecords: (json['health_records'] as List<dynamic>?)
          ?.map((e) => HealthRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      productionRecords: (json['production_records'] as List<dynamic>?)
          ?.map((e) => ProductionRecord.fromJson(e))
          .toList() ??
          [],
      photoUrl: json['photo_url'] as String?,
    );
  }

  // Helper method to create consistent detail chips (now part of Animal class)
  Widget _buildDetailChip({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    bool show = true,
  }) {
    if (!show) return const SizedBox.shrink();
    return Chip(
      avatar: Icon(icon, size: 18, color: color ?? Config.themeColor),
      label: Text('$label: $value'),
      backgroundColor: (color ?? Config.themeColor).withOpacity(0.1),
      labelStyle: TextStyle(color: color ?? Colors.black87),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Makes chip smaller
    );
  }

  // REVISED: Helper method to get displayable fields as a list of widgets
  List<Widget> getDisplayWidgets() {
    final List<Widget> widgets = [];

    // Map of all possible fields and their formatted values/widgets
    // Using a map allows dynamic lookup and easy modification
    final Map<String, Widget> allPossibleFieldWidgets = {
      'tag_number': Text(
        tagNumber,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Config.themeColor,
        ),
      ),
      'species': Text(
        '$species ${breed != null ? '(${breed})' : ''}',
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      'category_id': animalCategoryId != null
          ? _buildDetailChip(
        label: 'Category',
        value: animalCategoryId.toString(),
        icon: Icons.category,
      )
          : const SizedBox.shrink(), // Don't show if null
      'gender': _buildDetailChip(
        label: 'Gender',
        value: gender,
        icon: gender == 'Male' ? Icons.male : Icons.female,
      ),
      'weight': _buildDetailChip(
        label: 'Weight',
        value: '${weight} KG',
        icon: Icons.scale,
      ),
      'production': _buildDetailChip(
        label: 'Prod.',
        value: '${production.toStringAsFixed(1)}', // Adjusted to KG based on your production field
        icon: Icons.local_drink,
      ),
      'birth_date': _buildDetailChip(
        label: 'Born',
        value: DateFormat('yyyy-MM-dd').format(birthDate),
        icon: Icons.cake,
      ),
      'acquisition_date': acquisitionDate != null
          ? _buildDetailChip(
        label: 'Acquired',
        value: DateFormat('yyyy-MM-dd').format(acquisitionDate!),
        icon: Icons.calendar_today,
      )
          : const SizedBox.shrink(), // Don't show if null
      'acquisition_cost': acquisitionCost != null
          ? _buildDetailChip(
        label: 'Cost',
        value: '\$${acquisitionCost!.toStringAsFixed(2)}',
        icon: Icons.attach_money,
      )
          : const SizedBox.shrink(), // Don't show if null
      'status': _buildDetailChip(
        label: 'Status',
        value: status,
        icon: Icons.info_outline,
        color: status == 'active' ? Colors.green[700] : Colors.red[700],
      ),
      'shade_id': shadeId != null
          ? _buildDetailChip(
        label: 'Shade ID',
        value: shadeId.toString(),
        icon: Icons.home,
      )
          : const SizedBox.shrink(), // Don't show if null
      'created_at': Text(
        'Added: ${createdAt.toLocal().toString().split(' ')[0]}',
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    };

    // Determine which fields to render. Use displayFields if provided, otherwise a default set.
    final fieldsToRender = displayFields ?? [
      'tag_number', 'species', 'gender', 'weight', 'production', 'birth_date', 'status', 'created_at'
    ];

    // Always add tag_number and species first for primary identification
    if (fieldsToRender.contains('tag_number') && allPossibleFieldWidgets.containsKey('tag_number')) {
      widgets.add(allPossibleFieldWidgets['tag_number']!);
      widgets.add(const SizedBox(height: 4));
    }
    if (fieldsToRender.contains('species') && allPossibleFieldWidgets.containsKey('species')) {
      widgets.add(allPossibleFieldWidgets['species']!);
      widgets.add(const SizedBox(height: 8)); // Add more space after primary info
    }


    // Collect chips for flexible display using Wrap
    final List<Widget> chips = [];
    for (final field in fieldsToRender) {
      // Skip tag_number and species as they are already handled
      if (field != 'tag_number' && field != 'species' && allPossibleFieldWidgets.containsKey(field)) {
        final Widget fieldWidget = allPossibleFieldWidgets[field]!;
        // Check if the widget is a Chip (or SizedBox.shrink from _buildDetailChip)
        // If it's a Chip, add it to the chips list. Otherwise, add directly.
        if (fieldWidget is Chip || fieldWidget is SizedBox) { // SizedBox.shrink is used for null values
          chips.add(fieldWidget);
        } else {
          // For other non-chip widgets like 'created_at' (if displayFields contains it)
          widgets.add(fieldWidget);
          widgets.add(const SizedBox(height: 4));
        }
      }
    }

    // Add collected chips in a Wrap widget for flowing layout
    if (chips.isNotEmpty) {
      widgets.add(Wrap(
        spacing: 12.0, // Horizontal space between chips
        runSpacing: 6.0, // Vertical space between lines of chips
        children: chips,
      ));
    }

    // Ensure there's a small space at the end if the last item wasn't a chip/text
    if (widgets.isNotEmpty && widgets.last is! SizedBox) {
      widgets.add(const SizedBox(height: 4));
    }

    return widgets;
  }
}

class AnimalsListPage extends StatefulWidget {
  const AnimalsListPage({super.key});

  @override
  State<AnimalsListPage> createState() => _AnimalListState();
}

class _AnimalListState extends State<AnimalsListPage> {
  List<Animal> _animals = []; // List to hold fetched animals
  bool _isLoading = false; // To show loading indicator
  String? _errorMessage; // To store and display error messages
  String _searchQuery = ''; // For search functionality
  int _page = 1; // For pagination
  bool _hasMore = true; // To check if more data is available
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController(); // For persistent search text

  // PHP endpoint for fetching animals
  final String _phpEndpoint = '${Config.baseUrl}/modules/farm/animals/';

  @override
  void initState() {
    super.initState();
    _fetchAnimals(page: 1); // Fetch first page on init
    // Add listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent &&
          !_isLoading &&
          _hasMore) {
        _fetchAnimals(page: _page + 1);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose(); // Dispose search controller
    super.dispose();
  }

  Future<void> _fetchAnimals({int page = 1}) async {
    // Only set loading for first page or if not already loading.
    // This prevents showing shimmer/loader when just adding to existing list.
    if (page == 1 || !_isLoading) { // Added condition
      setState(() {
        _isLoading = true;
        if (page == 1) _errorMessage = null; // Clear errors only on refresh
      });
    }


    try {

      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final authToken = sessionProvider.currentUser?.token;

      if (authToken == null) {
        throw Exception('User not authenticated');
      }

      // Ensure the page parameter is correctly appended to the URL
      final response = await http
          .get(Uri.parse('$_phpEndpoint?page=$page'),
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $authToken',
                },
              )
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return; // Always check mounted after async calls

      // We set isLoading to false *after* the response, regardless of success/fail
      setState(() {
        _isLoading = false;
      });

      // print(response.body);
      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);

        List<dynamic>? rawData;
        if (decodedResponse is List) {
          rawData = decodedResponse;
        } else if (decodedResponse is Map<String, dynamic> &&
            decodedResponse['data'] is List) {
          rawData = decodedResponse['data'] as List;
        } else {
          // Handle unexpected API response format
          _errorMessage = decodedResponse['message'] ?? 'Invalid API response format.';
          //print('DEBUG: Animal API response not valid: $decodedResponse');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorMessage!)),
            );
          }
          return; // Exit if format is invalid
        }

        if (rawData != null) {

          final newAnimals = rawData.map((json) => Animal.fromJson(json as Map<String, dynamic>)).toList();

          setState(() {
            if (page == 1) {
              _animals = newAnimals; // Replace for first page/refresh
            } else {
              _animals.addAll(newAnimals); // Append for subsequent pages
            }
            _page = page; // Update current page number
            _hasMore = newAnimals.isNotEmpty; // If newAnimals is empty, no more data
          });
        }
      } else {
        setState(() {
          _errorMessage =
          'Failed to load animals: Server returned status ${response.statusCode}';
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching animals: $e';
        print('$e');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
      print('DEBUG: Error fetching animals: $e');
    }
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _sortByBirthDate() {
    setState(() {
      _animals.sort((a, b) => a.birthDate.compareTo(b.birthDate));
    });
  }

  List<Animal> get _filteredAnimals => _animals.where((animal) =>
  animal.tagNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      animal.species.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (animal.breed?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
  ).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // The back arrow icon
          onPressed: () {
            // This pops the current route off the navigation stack
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: TextField(
          controller: _searchController, // Use controller for more control
          onChanged: _updateSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search animals...',
            hintStyle: const TextStyle(color: Colors.white70),
            fillColor: Colors.white.withOpacity(0.2), // Slightly darker background
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 0),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
                _updateSearchQuery('');
                FocusScope.of(context).unfocus(); // Dismiss keyboard
              },
            )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              if (value == 'birth_date') {
                _sortByBirthDate();
              }
              // Add more sorting options here if needed (e.g., by weight, production)
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'birth_date',
                child: Text('Sort by Birth Date'),
              ),
              // Add more menu items for other sorting options
            ],
            tooltip: 'Sort Options',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _fetchAnimals(page: 1),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _animals.isEmpty // Only show shimmer if loading AND no data yet
          ? ListView.builder(
        itemCount: 5, // Show 5 shimmer placeholders
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(
                vertical: 8.0, horizontal: 16.0),
            child: Container(
              height: 180, // Increased height for shimmer to match new card size
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
      )
          : _errorMessage != null && _animals.isEmpty // Show error if no animals and error exists
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _fetchAnimals(page: 1),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _filteredAnimals.isEmpty // Show 'No animals found' if filter yields no results
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No animals found matching your search.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _updateSearchQuery('');
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _filteredAnimals.length + (_isLoading && _hasMore ? 1 : 0), // Add loader only if more data
        itemBuilder: (context, index) {
          if (index == _filteredAnimals.length) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Config.themeColor),
                ));
          }
          final animal = _filteredAnimals[index];
          return GestureDetector( // Use GestureDetector for more flexible tap
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnimalDetailsPage(animal: animal),
                ),
              );
            },
            child: Card(
              elevation: 5.0, // Increased elevation for more pop
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // Added horizontal margin
              color: animal.cardColor ?? Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0), // More rounded corners
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row( // Use a Row for image and details
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animal Photo (Placeholder)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200], // Placeholder color
                        image: animal.photoUrl != null && animal.photoUrl!.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(animal.photoUrl!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: animal.photoUrl == null || animal.photoUrl!.isEmpty
                          ? Icon(Icons.pets, size: 40, color: Colors.grey[600])
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: animal.getDisplayWidgets(), // Call the method here
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20), // Arrow indicator
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/addAnimal').then((_) {
            _fetchAnimals(page: 1); // Refresh list on return
          });
        },
        backgroundColor: Config.themeColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}