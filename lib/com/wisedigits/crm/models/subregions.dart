

class Subregion {
  final int id;
  final String name;

  Subregion({required this.id, required this.name});

  factory Subregion.fromJson(Map<String, dynamic> json) {
    return Subregion(
      id: int.parse(json['id'].toString()), // Convert string to int
      name: json['name']?.toString() ?? '',
    );
  }
}