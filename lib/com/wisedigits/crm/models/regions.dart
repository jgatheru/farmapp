class Region {
  final int id;
  final String name;

  Region({required this.id, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: int.parse(json['id'].toString()), // Convert string to int
      name: json['name']?.toString() ?? '',
    );
  }
}