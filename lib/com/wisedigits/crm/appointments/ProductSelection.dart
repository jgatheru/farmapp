import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import '../models/appointments.dart';
import 'addAppointment.dart';

class ProductSelectionPage extends StatefulWidget {
  final Appointment appointment;

  const ProductSelectionPage({super.key, required this.appointment});

  @override
  State<ProductSelectionPage> createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Product> _selectedProductIds = []; // Changed from List<int> to List<Product>
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(_debouncedFilterProducts);
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${Config.sisiUrl}/products/getProducts.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${sessionProvider.currentUser?.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _products = (responseData['data'] as List<dynamic>)
                .map((json) => Product.fromJson(json as Map<String, dynamic>))
                .toList();
            _filteredProducts = _products;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load products';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching products: $e';
      });
    }
  }

  void _debouncedFilterProducts() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _filterProducts);
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredProducts = _products;
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_debouncedFilterProducts);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search products...',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.white70),
              onPressed: () {
                _searchController.clear();
                _filterProducts();
              },
            )
                : null,
          ),
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
        )
            : const Text('Select Products'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Cancel' : 'Search',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                return CheckboxListTile(
                  title: Text(product.name),
                  value: _selectedProductIds.contains(product),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedProductIds.add(product); // Store Product object
                      } else {
                        _selectedProductIds.remove(product);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdateAppointmentPage(
                      appointment: widget.appointment,
                      selectedProductIds: _selectedProductIds, // Pass List<Product>
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Config.themeColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Proceed to Update'),
            ),
          ),
        ],
      ),
    );
  }
}