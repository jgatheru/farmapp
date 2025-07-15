class FacilityType {
  final int id;
  final String name;

  FacilityType({required this.id, required this.name});

  factory FacilityType.fromJson(Map<String, dynamic> json) {
    return FacilityType(
      id: int.parse(json['id'].toString()), // Handle string or int
      name: json['name']?.toString() ?? '', // Handle null
    );
  }

  @override
  String toString() => 'FacilityType(id: $id, name: $name)';
}