// animals_list_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode
import 'package:intl/intl.dart';

import '../../../../config.dart'; // For date formatting

// Model class for a single Animal
class Animal {
  final int animalId;
  final String tagNumber;
  final String species;
  final String? breed;
  final DateTime birthDate;
  final String gender;
  final double weight;
  final int? shadeId; // Nullable if not always assigned
  final DateTime? acquisitionDate; // Nullable
  final double? acquisitionCost; // Nullable
  final String status;
  final DateTime createdAt;

  Animal({
    required this.animalId,
    required this.tagNumber,
    required this.species,
    this.breed,
    required this.birthDate,
    required this.gender,
    required this.weight,
    this.shadeId,
    this.acquisitionDate,
    this.acquisitionCost,
    required this.status,
    required this.createdAt,
  });

  // Factory constructor to create an Animal object from a JSON map
  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      animalId: json['animal_id'] as int,
      tagNumber: json['tag_number'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      birthDate: DateTime.parse(json['birth_date'] as String),
      gender: json['gender'] as String,
      weight: (json['weight'] as num).toDouble(), // Handle num to double conversion
      shadeId: json['shade_id'] as int?,
      acquisitionDate: json['acquisition_date'] != null
          ? DateTime.parse(json['acquisition_date'] as String)
          : null,
      acquisitionCost: (json['acquisition_cost'] as num?)?.toDouble(), // Handle nullable num to double
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AnimalsListPage extends StatefulWidget {
  const AnimalsListPage({super.key});

  @override
  State<AnimalsListPage> createState() => AnimalList();
}

class AnimalList extends State<AnimalsListPage> {
  List<Animal> _animals = []; // List to hold fetched animals
  bool _isLoading = false; // To show loading indicator
  String? _errorMessage; // To store and display error messages

  // Replace with your actual PHP endpoint URL for fetching animals
  final String _phpEndpoint = '${Config.baseUrl}/animals/getAnimals.php';

  @override
  void initState() {
    super.initState();
    _fetchAnimals(); // Fetch animals when the page initializes
  }

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      final response = await http.get(Uri.parse(_phpEndpoint));

      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          final List<dynamic> responseData = jsonDecode(response.body);
          _animals = responseData.map((json) => Animal.fromJson(json)).toList();
        } else {
          _errorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error: Could not connect. $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
      print('Error fetching animals: $e'); // For debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals List'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAnimals, // Disable refresh when loading
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
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
                onPressed: _fetchAnimals,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _animals.isEmpty
          ? const Center(
        child: Text('No animals found. Add some!',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _animals.length,
        itemBuilder: (context, index) {
          final animal = _animals[index];
          return Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animal.tagNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Species: ${animal.species} (${animal.breed ?? 'N/A'})',
                      style: const TextStyle(fontSize: 16)),
                  Text('Gender: ${animal.gender}', style: const TextStyle(fontSize: 16)),
                  Text('Weight: ${animal.weight} KG', style: const TextStyle(fontSize: 16)),
                  Text('Born: ${DateFormat('yyyy-MM-dd').format(animal.birthDate)}',
                      style: const TextStyle(fontSize: 16)),
                  if (animal.acquisitionDate != null)
                    Text(
                        'Acquired: ${DateFormat('yyyy-MM-dd').format(animal.acquisitionDate!)}',
                        style: const TextStyle(fontSize: 16)),
                  if (animal.acquisitionCost != null)
                    Text('Cost: \$${animal.acquisitionCost!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16)),
                  Text('Status: ${animal.status}', style: const TextStyle(fontSize: 16)),
                  if (animal.shadeId != null)
                    Text('Shade ID: ${animal.shadeId}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Added: ${animal.createdAt.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the form to add a new animal
          Navigator.pushNamed(context, '/addAnimal').then((_) {
            // Refresh the list when returning from the add animal page
            _fetchAnimals();
          });
        },
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
