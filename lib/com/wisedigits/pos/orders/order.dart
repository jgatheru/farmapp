class Order {
  final int id;
  final Customer customer;
  final String date;
  final double total;

  Order({
    required this.id,
    required this.customer,
    required this.date,
    required this.total,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing Order JSON: $json');
      return Order(
        id: _parseInt(json['id'], 'order id'),
        customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
        date: json['date'] as String? ?? '',
        total: _parseDouble(json['total'], 'order total'),
      );
    } catch (e) {
      print('Error parsing Order JSON: $json, Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer': customer.toJson(),
    'date': date,
    'total': total,
  };
}

/// Represents a customer associated with an order.
class Customer {
  final int id;
  final String name;

  Customer({required this.id, required this.name});

  factory Customer.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing Customer JSON: $json');
      return Customer(
        id: _parseInt(json['id'], 'customer id'),
        name: json['name'] as String? ?? '',
      );
    } catch (e) {
      print('Error parsing Customer JSON: $json, Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Represents a product that can be added to an order.
class Product {
  final int id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing Product JSON: $json');
      return Product(
        id: _parseInt(json['id'], 'product id'),
        name: json['name'] as String? ?? '',
        price: _parseDouble(json['price'], 'product price'),
      );
    } catch (e) {
      print('Error parsing Product JSON: $json, Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

/// Represents an item in an order or cart.
class OrderItem {
  final Product product;
  final int quantity;
  final double price;

  OrderItem({required this.product, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing OrderItem JSON: $json');
      return OrderItem(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: _parseInt(json['quantity'], 'order item quantity'),
        price: _parseDouble(json['price'], 'order item price'),
      );
    } catch (e) {
      print('Error parsing OrderItem JSON: $json, Error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'price': price,
  };
}

/// Helper to safely parse integers with error reporting.
int _parseInt(dynamic value, String field) {
  if (value == null) {
    print('Parsing error: $field is null');
    throw FormatException('Missing $field');
  }
  if (value is int) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      print('Parsing error: Invalid $field: $value');
      throw FormatException('Invalid $field: $value');
    }
    return parsed;
  }
  print('Parsing error: Invalid $field type: ${value.runtimeType}, value: $value');
  throw FormatException('Invalid $field type: ${value.runtimeType}');
}

/// Helper to safely parse doubles with error reporting.
double _parseDouble(dynamic value, String field) {
  if (value == null) {
    print('Parsing error: $field is null');
    throw FormatException('Missing $field');
  }
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      print('Parsing error: Invalid $field: $value');
      throw FormatException('Invalid $field: $value');
    }
    return parsed;
  }
  print('Parsing error: Invalid $field type: ${value.runtimeType}, value: $value');
  throw FormatException('Invalid $field type: ${value.runtimeType}');
}