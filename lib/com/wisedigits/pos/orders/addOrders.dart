import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'order.dart';

/// Allows creating a new order by selecting a date, customer, and adding products to a cart.
class AddOrderPage extends StatefulWidget {
  const AddOrderPage({super.key});

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _orderDate;
  Customer? _selectedCustomer;
  Product? _selectedProduct;
  final _customerController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Customer> _customers = [];
  List<Product> _products = [];
  List<OrderItem> _cart = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _orderDate = DateTime.now(); // Default to today
    _fetchCustomers();
    _fetchProducts();
  }

  /// Fetches the list of customers from the API.
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final employeeid = sessionProvider.currentUser?.employeeid;
      final token = sessionProvider.currentUser?.token;
      final uri = '${Config.sisiUrl}/customers/getCustomers.php?employeeid=$employeeid';
      print('Fetching customers: $uri');

      final response = await http.get(
        Uri.parse(uri),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _customers = (responseData['data'] as List).map((json) => Customer.fromJson(json)).toList();
          });
        } else {
          setState(() => _errorMessage = 'No customers found');
        }
      } else {
        setState(() => _errorMessage = 'Server error fetching customers: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error fetching customers: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fetches the list of products from the API.
  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final token = sessionProvider.currentUser?.token;
      final uri = '${Config.sisiUrl}/products/getProducts.php';
      print('Fetching products: $uri');

      final response = await http.get(
        Uri.parse(uri),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _products = (responseData['data'] as List).map((json) => Product.fromJson(json)).toList();
          });
        } else {
          setState(() => _errorMessage = 'No products found');
        }
      } else {
        setState(() => _errorMessage = 'Server error fetching products: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error fetching products: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Selects the order date using a date picker.
  Future<void> _selectOrderDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _orderDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _orderDate && mounted) {
      setState(() => _orderDate = picked);
    }
  }

  /// Adds the selected product and quantity to the cart.
  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProduct == null) {
      setState(() => _errorMessage = 'Select a product');
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'Enter a valid quantity');
      return;
    }

    setState(() {
      _cart.add(OrderItem(
        product: _selectedProduct!,
        quantity: quantity,
        price: _selectedProduct!.price,
      ));
      _selectedProduct = null;
      _productController.clear();
      _quantityController.clear();
      _errorMessage = null;
    });
  }

  /// Submits the order to the API.
  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate() || _orderDate == null || _selectedCustomer == null || _cart.isEmpty) {
      setState(() => _errorMessage = 'Complete all fields and add at least one item');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final token = sessionProvider.currentUser?.token;
      final employeeid = sessionProvider.currentUser?.employeeid;
      final userid = sessionProvider.currentUser?.userid;
      final uri = '${Config.sisiUrl}/orders/saveOrder.php';
      print('Creating order: $uri');

      final body = {
        'orderedon': DateFormat('yyyy-MM-dd').format(_orderDate!),
        'customerid': _selectedCustomer!.id.toString(),
        'employeeid': employeeid.toString(),
        'userid': userid.toString(),
        'items': _cart
            .map((item) => {
          'productid': item.product.id.toString(),
          'quantity': item.quantity.toString(),
          'price': item.price.toString(),
        })
            .toList(),
      };

      final response = await http.post(
        Uri.parse(uri),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = 'Failed to create order: ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error creating order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customerController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Order'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              GestureDetector(
                onTap: () => _selectOrderDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Order Date',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                    ),
                    controller: TextEditingController(
                      text: _orderDate != null ? DateFormat('yyyy-MM-dd').format(_orderDate!) : '',
                    ),
                    validator: (value) => _orderDate == null ? 'Order date is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  return _customers
                      .where((customer) => customer.name.toLowerCase().contains(query))
                      .map((customer) => customer.name)
                      .toList();
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedCustomer = _customers.firstWhere((c) => c.name == selection);
                    _customerController.text = selection;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Customer',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person, color: Config.themeColor),
                    ),
                    validator: (value) => value!.isEmpty ? 'Customer is required' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.toLowerCase();
                  return _products
                      .where((product) => product.name.toLowerCase().contains(query))
                      .map((product) => product.name)
                      .toList();
                },
                onSelected: (String selection) {
                  setState(() {
                    _selectedProduct = _products.firstWhere((p) => p.name == selection);
                    _productController.text = selection;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Product',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_cart, color: Config.themeColor),
                    ),
                    validator: (value) => value!.isEmpty && _selectedProduct == null ? 'Product is required' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers, color: Config.themeColor),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Quantity is required';
                  final qty = int.tryParse(value);
                  return qty == null || qty <= 0 ? 'Enter a valid quantity' : null;
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor ?? Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Add to Cart'),
              ),
              const SizedBox(height: 16),
              const Text('Cart Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (_cart.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Cart is empty', style: TextStyle(color: Colors.grey)),
                ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cart.length,
                itemBuilder: (context, index) {
                  final item = _cart[index];
                  return ListTile(
                    title: Text(item.product.name),
                    subtitle: Text(
                      'Qty: ${item.quantity} | Price: ${item.price.toStringAsFixed(2)} | Subtotal: ${ (item.quantity * item.price).toStringAsFixed(2) }',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => setState(() => _cart.removeAt(index)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Config.themeColor ?? Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Create Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}