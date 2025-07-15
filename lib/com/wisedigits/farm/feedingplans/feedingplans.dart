import 'package:intl/intl.dart';

// Model for farm_feeding_plans table
class FeedingPlan {
  final int id;
  final String name;
  final String? description;
  final int? animalCategoryId;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  FeedingPlan({
    required this.id,
    required this.name,
    this.description,
    this.animalCategoryId,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  factory FeedingPlan.fromJson(Map<String, dynamic> json) {
    return FeedingPlan(
      id: json['id'] is num ? json['id'].toInt() : 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      animalCategoryId: json['farm_animal_category_id'] is num ? json['farm_animal_category_id'].toInt() : null,
      ipAddress: json['ipaddress']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedBy: json['updated_by'] is num ? json['updated_by'].toInt() : null,
      createdBy: json['created_by'] is num ? json['created_by'].toInt() : null,
    );
  }
}

// Model for farm_feeding_plan_details table
class FeedingPlanDetail {
  final int id;
  final int farmFeedingPlanId;
  final int invItemId;
  final double quantity;
  final String feedingFrequency;
  final String? notes;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  FeedingPlanDetail({
    required this.id,
    required this.farmFeedingPlanId,
    required this.invItemId,
    required this.quantity,
    required this.feedingFrequency,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  // Parse JSON from API response
  factory FeedingPlanDetail.fromJson(Map<String, dynamic> json) {
    return FeedingPlanDetail(
      id: json['id'] is num ? json['id'].toInt() : 0,
      farmFeedingPlanId: json['farm_feeding_plan_id'] is num ? json['farm_feeding_plan_id'].toInt() : 0,
      invItemId: json['inv_item_id'] is num ? json['inv_item_id'].toInt() : 0,
      quantity: json['quantity'] is num ? json['quantity'].toDouble() : 0.0,
      feedingFrequency: json['feeding_frequency']?.toString() ?? 'daily',
      notes: json['notes']?.toString(),
      ipAddress: json['ipaddress']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedBy: json['updated_by'] is num ? json['updated_by'].toInt() : null,
      createdBy: json['created_by'] is num ? json['created_by'].toInt() : null,
    );
  }
}

// Model for filtering by animal (used in FeedingPlanFilterDialog)
class AnimalForFilter {
  final int id;
  final String tagNumber;

  AnimalForFilter({required this.id, required this.tagNumber});

  factory AnimalForFilter.fromJson(Map<String, dynamic> json) {
    return AnimalForFilter(
      id: json['id'] is num ? json['id'].toInt() : 0,
      tagNumber: json['tag_number']?.toString() ?? 'Unknown',
    );
  }
}

// Model for inventory items
class InventoryItem {
  final int id;
  final String name;

  InventoryItem({required this.id, required this.name});

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] is num ? json['id'].toInt() : 0,
      name: json['name']?.toString() ?? 'Unknown',
    );
  }
}