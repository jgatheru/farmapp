// shades_list_page.dart

import 'package:farmapp/com/wisedigits/farm/shades/shadeAnimals.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';


// Model class for a single Shade
class Shade {
  final int id;
  final String name;
  final String location;
  final int capacity;
  final String? description; // Make nullable as it can be empty string or null
  final String? ipaddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  Shade({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    this.description,
    this.ipaddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  factory Shade.fromJson(Map<String, dynamic> json) {
    return Shade(
      id: json['id'] as int,
      name: json['name'] as String,
      location: json['location'] as String,
      capacity: json['capacity'] as int? ?? 0,
      description: json['description'] as String?, // Can be null or empty string
      ipaddress: json['ipaddress'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      updatedBy: json['updated_by'] as int?,
      createdBy: json['created_by'] as int?,
    );
  }
}

class ShadesListPage extends StatefulWidget {
  const ShadesListPage({super.key});

  @override
  State<ShadesListPage> createState() => ShadesList();
}

class ShadesList extends State<ShadesListPage> {
  List<Shade> _shades = []; // List to hold fetched shades
  bool _isLoading = false; // To show loading indicator
  String? _errorMessage; // To store and display error messages

  // Replace with your actual PHP endpoint URL for fetching shades
  final String _phpEndpoint = '${Config.baseUrl}/modules/farm/shades/';

  @override
  void initState() {
    super.initState();
    _fetchShades(); // Fetch shades when the page initializes
  }

  Future<void> _fetchShades() async {
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

      final response = await http.get(
          Uri.parse(_phpEndpoint),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },

      );

      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);

          print(responseData);

          if (responseData.containsKey('data') && responseData['data'] is List) {
            final List<dynamic> shadesJsonList = responseData['data'];

            setState(() {
              _shades = shadesJsonList.map((json) => Shade.fromJson(json)).toList();
            });
          }  else {
            _errorMessage = responseData['message'] ?? 'Failed to load shades: Invalid data format.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorMessage!)),
            );
            print('DEBUG: API response for shades was not successful or data format incorrect: $responseData');
          }
        } else {
          _errorMessage = 'Failed to load shades: Server returned status ${response.statusCode}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
          print('DEBUG: Failed to load shades. Status Code: ${response.statusCode}, Body: ${response.body}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not connect: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
      print('DEBUG: Error fetching shades: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // The back arrow icon
          onPressed: () {
            // This pops the current route off the navigation stack
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Shades List'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchShades, // Disable refresh when loading
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Config.themeColor)) // Show loading indicator
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
                onPressed: _fetchShades,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _shades.isEmpty
          ? const Center(
        child: Text('No shades found. Add some!',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _shades.length,
        itemBuilder: (context, index) {
          final shade = _shades[index];
          return Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            // --- Wrap the Card content with InkWell to make it tappable ---
            child: InkWell(
              onTap: () {
                // Navigate to the AnimalsByShadePage, passing shadeId and shadeName
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimalsByShadePage(
                      shadeId: shade.id,
                      shadeName: shade.name,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shade.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Config.themeColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Location: ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          shade.location,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Capacity: ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          shade.capacity.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text(
                          'Description: ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Flexible(
                          child: Text(
                            shade.description ?? 'N/A', // Handle null description gracefully
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Added on: ${shade.createdAt?.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the form to add a new shade
          Navigator.pushNamed(context, '/addShade').then((_) {
            // Refresh the list when returning from the add shade page
            _fetchShades();
          });
        },
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}