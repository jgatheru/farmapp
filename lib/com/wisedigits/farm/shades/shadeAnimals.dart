// lib/animals/pages/animals_by_shade_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../animals/animaldetails.dart';
import '../animals/animals.dart'; // Make sure this import path is correct for your Animal model

class AnimalsByShadePage extends StatefulWidget {
  final int shadeId;
  final String shadeName; // To display in the AppBar

  const AnimalsByShadePage({
    super.key,
    required this.shadeId,
    required this.shadeName,
  });

  @override
  State<AnimalsByShadePage> createState() => _AnimalsByShadePageState();
}

class _AnimalsByShadePageState extends State<AnimalsByShadePage> {
  List<Animal> _animals = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Assuming getAnimals.php can take shade_id as a filter,
  // or you might have a dedicated getAnimalsByShade.php
  final String _fetchAnimalsByShadeEndpoint = '${Config.baseUrl}/modules/farm/animals/';

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
  }

  Future<void> _fetchAnimals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error messages
    });

    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final authToken = sessionProvider.currentUser?.token;

    if (authToken == null) {
      throw Exception('User not authenticated');
    }

    try {

      final response = await http.get(
          Uri.parse('$_fetchAnimalsByShadeEndpoint?farm_shade_id=${widget.shadeId}'),
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

          final dynamic decodedResponse = jsonDecode(response.body); // Decode dynamically first

          // Check if the response is a List (direct array of animals)
          if (decodedResponse is List) {
            _animals = decodedResponse.map((json) => Animal.fromJson(json as Map<String, dynamic>)).toList();
            if (_animals.isEmpty) {
              _errorMessage = 'No animals found in this shade.'; // Not an error, but informative
            } else {
              _errorMessage = null; // Clear any previous 'no animals' message if data arrives
            }
          }
          // Check if the response is a Map (an object potentially containing 'success' and 'data')
          else if (decodedResponse is Map<String, dynamic>) {
            if (decodedResponse['data'] is List) {
              final List<dynamic> animalsData = decodedResponse['data'];
              _animals = animalsData.map((json) => Animal.fromJson(json as Map<String, dynamic>)).toList();
              if (_animals.isEmpty) {
                _errorMessage = 'No animals found in this shade.';
              } else {
                _errorMessage = null;
              }
            } else {
              // If 'success' is false or 'data' is not a list
              _errorMessage = decodedResponse['message'] ?? 'Failed to load animals: Invalid API response format.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_errorMessage!)),
              );
              print('DEBUG: API response for animals by shade was not successful or data format incorrect: $decodedResponse');
            }
          } else {
            // Unexpected response type
            _errorMessage = 'Failed to load animals: Unexpected data type from server.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_errorMessage!)),
            );
            print('DEBUG: Unexpected response type: ${response.body}');
          }
        } else {
          // HTTP status code is not 200
          _errorMessage = 'Failed to load animals: Server returned status ${response.statusCode}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
          print('DEBUG: Failed to load animals. Status Code: ${response.statusCode}, Body: ${response.body}');
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
      print('DEBUG: Error fetching animals by shade: $e');
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Animals in ${widget.shadeName}'),
        backgroundColor: Config.backgroundColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAnimals,
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
                onPressed: _fetchAnimals,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _animals.isEmpty
          ? Center(
        child: Text(
          'No animals found in this shade.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _animals.length,
        itemBuilder: (context, index) {
          final animal = _animals[index];
          return Card(
            elevation: 2.0,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              leading: const Icon(Icons.pets), // Example icon
              title: Text(
                animal.tagNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Species: ${animal.species}, Gender: ${animal.gender}\n'
                    'Weight: ${animal.weight} kg',
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Navigate to AnimalDetailsPage, passing the entire animal object
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnimalDetailsPage(animal: animal),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}