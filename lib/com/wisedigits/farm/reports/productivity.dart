class FarmReport {
  final int id;
  final String animal;
  final double production;
  final double consumption;
  final double profit;
  final String position;
  final DateTime date;
  final DateTime? createdAt;

  FarmReport({
    required this.id,
    required this.animal,
    required this.production,
    required this.consumption,
    required this.profit,
    required this.position,
    required this.date,
    this.createdAt,
  });

  factory FarmReport.fromJson(Map<String, dynamic> json) {
    return FarmReport(
      id: (json['id'] is num) ? json['id'].toInt() : 0,
      animal: json['farm_animal_name'] as String? ?? 'Unknown',
      production: json['production'] != null
          ? (json['production'] is num
          ? (json['production'] as num).toDouble()
          : double.tryParse(json['production'].toString()) ?? 0.0)
          : 0.0,
      consumption: (json['consumption'] is num) ? json['consumption'].toDouble() : 0.0,
      profit: (json['productivity_ratio'] is num) ? json['productivity_ratio'].toDouble() : 0.0,
      position: json['position'] as String? ?? 'N/A',
      date: DateTime.parse(json['date'] as String? ?? '1970-01-01'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}