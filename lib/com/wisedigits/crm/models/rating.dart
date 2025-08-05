class Rating {
  final int id;
  final String name;

  Rating({required this.id, required this.name});

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: int.parse(json['id'].toString()),
      name: json['name'] as String,
    );
  }
}