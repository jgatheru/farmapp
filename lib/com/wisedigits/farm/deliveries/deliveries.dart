class Delivery {
  final int id;
  final int crmCustomerId;
  final int farmSessionId;
  final DateTime date;
  final double quantity;
  final double? approvedQuantity;
  final String? notes;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  Delivery({
    required this.id,
    required this.crmCustomerId,
    required this.farmSessionId,
    required this.date,
    required this.quantity,
    this.approvedQuantity,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      crmCustomerId: (json['crm_customer_id'] is num) ? json['crm_customer_id'].toInt() : 0,
      farmSessionId: (json['farm_session_id'] is num) ? json['farm_session_id'].toInt() : 0,
      date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime(2000),
      quantity: json['quantity'] != null
          ? (json['quantity'] is num
          ? (json['quantity'] as num).toDouble()
          : double.tryParse(json['quantity'].toString()) ?? 0.0)
          : 0.0,
      approvedQuantity: (json['approved_quantity'] is num) ? json['approved_quantity'].toDouble() : null,
      notes: json['notes'] as String?,
      ipAddress: json['ipaddress'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: (json['updated_by'] is num) ? json['updated_by'].toInt() : null,
      createdBy: (json['created_by'] is num) ? json['created_by'].toInt() : null,
    );
  }
}

class CustomerForFilter {
  final int id;
  final String name;

  CustomerForFilter({required this.id, required this.name});

  factory CustomerForFilter.fromJson(Map<String, dynamic> json) {
    return CustomerForFilter(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}
class FarmSession {
  final int id;
  final String name;

  FarmSession({required this.id, required this.name});

  factory FarmSession.fromJson(Map<String, dynamic> json) {
    return FarmSession(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      name: json['name'] as String? ?? 'Unknown',
    );
  }
}