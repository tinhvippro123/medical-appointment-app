class Department {
  const Department({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });
  final int id;
  final String name;
  final String? description, imageUrl;
  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );
}
