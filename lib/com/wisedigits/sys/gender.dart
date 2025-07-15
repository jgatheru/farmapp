// gender.dart

/// Model class for a Gender from the sys_genders table.
///
/// This model represents a record in the `sys_genders` database table,
/// typically containing an ID and a name (e.g., "Male", "Female").
class Gender {
  final int id;
  final String name; // The gender name (e.g., "Male", "Female")
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? updatedBy;
  final int? createdBy;

  Gender({
    required this.id,
    required this.name, // Name is typically required for a gender entry
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.createdBy,
  });

  /// Factory constructor to create a [Gender] instance from a JSON map.
  ///
  /// This is used when parsing data received from an API. It safely handles
  /// potential nulls for optional fields like timestamps and user IDs.
  ///
  /// Example JSON structure for a single gender item:
  /// ```json
  /// {
  ///   "id": 1,
  ///   "name": "Male",
  ///   "created_at": "2024-01-01T10:00:00.000000Z",
  ///   "updated_at": "2024-01-01 10:00:00", // Can be different formats
  ///   "updated_by": null,
  ///   "created_by": 1
  /// }
  /// ```
  factory Gender.fromJson(Map<String, dynamic> json) {
    return Gender(
      id: json['id'] as int,
      // Provide a default 'Unknown' if name is null or missing,
      // as 'name' is often critical for display.
      name: json['name'] as String? ?? 'Unknown',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) // Safely parse string to DateTime
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) // Safely parse string to DateTime
          : null,
      updatedBy: json['updated_by'] as int?,
      createdBy: json['created_by'] as int?,
    );
  }

  /// Converts this [Gender] instance into a JSON map.
  ///
  /// This is useful for sending data back to an API (e.g., for creating or updating).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'created_by': createdBy,
    };
  }

  @override
  String toString() {
    return 'Gender(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, updatedBy: $updatedBy, createdBy: $createdBy)';
  }
}