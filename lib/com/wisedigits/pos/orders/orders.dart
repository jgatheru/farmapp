import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../config.dart';
import '../../auth/SessionProvider.dart';
import 'order.dart';
import 'addOrders.dart';

/// Displays a list of orders with filtering by date range in a refined table.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _fromDate;
  DateTime? _toDate;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _fetchOrders();
  }

  /// Fetches orders from the API based on the selected date range.
  Future<void> _fetchOrders() async {
    if (_fromDate == null || _toDate == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final employeeid = sessionProvider.currentUser?.employeeid;
      final token = sessionProvider.currentUser?.token;

      if (employeeid == null || token == null) {
        setState(() => _errorMessage = 'Authentication data missing');
        return;
      }

      final since = DateFormat('yyyy-MM-dd').format(_fromDate!);
      final until = DateFormat('yyyy-MM-dd').format(_toDate!);
      final uri = '${Config.sisiUrl}/orders/getOrders.php?employeeid=$employeeid&fromdate=$since&todate=$until';
      print('Fetching orders: $uri');

      final response = await http.get(
        Uri.parse(uri),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      print('Raw response: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Parsed response: $responseData');

        List<dynamic> ordersData;
        if (responseData is List) {
          print('Handling direct array response');
          ordersData = responseData;
        } else if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          print('Handling wrapped response');
          ordersData = responseData['data'] as List;
        } else {
          setState(() => _errorMessage = 'Invalid response format: ${responseData['message'] ?? 'Unknown error'}');
          return;
        }

        setState(() {
          _orders = ordersData.asMap().entries.map((entry) {
            final index = entry.key;
            final json = entry.value as Map<String, dynamic>;
            try {
              return Order.fromJson(json);
            } catch (e) {
              print('Failed to parse order at index $index: $json, Error: $e');
              throw e;
            }
          }).toList();
          _retryCount = 0;
        });
      } else {
        setState(() => _errorMessage = 'Server error: ${response.statusCode}');
        _retryFetchOrders();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error fetching orders: $e');
      _retryFetchOrders();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Retries fetching orders if the previous attempt failed.
  Future<void> _retryFetchOrders() async {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      print('Retrying fetch orders ($_retryCount/$_maxRetries)...');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _fetchOrders();
    } else {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to fetch orders after $_maxRetries attempts');
      }
    }
  }

  /// Fetches and displays the items for a specific order in a dialog.
  Future<void> _showOrderItems(Order order) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<OrderItem> items = [];

    try {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final token = sessionProvider.currentUser?.token;
      if (token == null) {
        setState(() => _errorMessage = 'Authentication token missing');
        return;
      }

      final uri = '${Config.sisiUrl}/orders/getOrderItems.php?orderid=${order.id}';
      print('Fetching order items: $uri');

      final response = await http.get(
        Uri.parse(uri),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      print('Order items response: ${response.body}');
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          items = (responseData['data'] as List).asMap().entries.map((entry) {
            final index = entry.key;
            final json = entry.value;
            try {
              return OrderItem.fromJson(json);
            } catch (e) {
              print('Failed to parse order item at index $index: $json, Error: $e');
              throw e;
            }
          }).toList();
        } else {
          setState(() => _errorMessage = 'No items found for order ${order.id}');
        }
      } else {
        setState(() => _errorMessage = 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Error fetching order items: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (items.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Items for Order #${order.id}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.product.name),
                  subtitle: Text(
                    'Qty: ${item.quantity} | Price: ${item.price.toStringAsFixed(2)} | Subtotal: ${(item.quantity * item.price).toStringAsFixed(2)}',
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      setState(() => _errorMessage = _errorMessage ?? 'No items available for order ${order.id}');
    }
  }

  /// Shows a date picker for selecting the "From" date.
  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _fromDate && mounted) {
      setState(() {
        _fromDate = picked;
        _fetchOrders();
      });
    }
  }

  /// Shows a date picker for selecting the "To" date.
  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _toDate && mounted) {
      setState(() {
        _toDate = picked;
        _fetchOrders();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
          tooltip: 'Back to Home',
        ),
        title: const Text('Orders'),
        backgroundColor: Config.backgroundColor ?? Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectFromDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'From Date',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                        ),
                        controller: TextEditingController(
                          text: _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectToDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'To Date',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, color: Config.themeColor),
                        ),
                        controller: TextEditingController(
                          text: _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : '',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _fetchOrders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Config.themeColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Filter', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                ? const Center(child: Text('No orders found', style: TextStyle(fontSize: 16)))
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  dataRowHeight: 60,
                  headingRowHeight: 56,
                  headingTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Config.themeColor ?? Colors.blue,
                    fontSize: 16,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 14),
                  columns: const [
                    DataColumn(label: Text('Order ID')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Total')),
                  ],
                  rows: _orders.asMap().entries.map((entry) {
                    final index = entry.key;
                    final order = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(Text('#${order.id}')),
                        DataCell(
                          GestureDetector(
                            onTap: () => _showOrderItems(order),
                            child: Text(
                              order.customer.name,
                              style: TextStyle(
                                color: Config.themeColor ?? Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(order.date)),
                        DataCell(Text(order.total.toStringAsFixed(2))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddOrderPage()),
        ).then((value) {
          if (value == true && mounted) _fetchOrders();
        }),
        backgroundColor: Config.themeColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}