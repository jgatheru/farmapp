// model.dart

class MilkProductionRecord {
  final int id;
  final int farmAnimalId;
  final String farmAnimalName; // Assuming you have this for display
  final DateTime productionDate;
  final double quantityLiters; // <<< FOCUS HERE
  final String? qualityGrade;
  final String? notes;
  final int farmSessionId;

  MilkProductionRecord({
    required this.id,
    required this.farmAnimalId,
    required this.farmAnimalName,
    required this.productionDate,
    required this.quantityLiters,
    this.qualityGrade,
    this.notes,
    required this.farmSessionId,
  });

  factory MilkProductionRecord.fromJson(Map<String, dynamic> json) {

    double parsedQuantity;
    final dynamic rawQuantity = json['quantity']; // Get the raw value

    if (rawQuantity is num) {
      parsedQuantity = rawQuantity.toDouble(); // If it's already a number, convert to double
    } else if (rawQuantity is String) {
      parsedQuantity = double.tryParse(rawQuantity) ?? 0.0; // If it's a string, try parsing it to double
    } else {
      parsedQuantity = 0.0; // Fallback for any other unexpected type
    }

    return MilkProductionRecord(
      id: json['id'] as int,
      farmAnimalId: json['farm_animal_id'] as int,
      farmAnimalName: json['animal']['tag_number'] as String, // Ensure this key matches your API
      productionDate: DateTime.parse(json['date'] as String),
      quantityLiters: parsedQuantity,
      qualityGrade: json['quality_grade'] as String?,
      notes: json['notes'] as String?,
      farmSessionId: (json['farm_session_id'] is num) ? (json['farm_session_id'] as num).toInt() : 0,
    );
  }
}

class AnimalForFilter {
  final int id;
  final String tagNumber;

  AnimalForFilter({required this.id, required this.tagNumber});

  factory AnimalForFilter.fromJson(Map<String, dynamic> json) {
    return AnimalForFilter(
      id: json['id'] as int,
      tagNumber: json['tag_number'] as String,
    );
  }
}