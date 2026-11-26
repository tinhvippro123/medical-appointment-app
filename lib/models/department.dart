class Department {
  const Department({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.consultationFee,
  });
  final int id;
  final String name;
  final String? description, imageUrl;
  final double? consultationFee;
  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '').toString(),
    description: json['description']?.toString(),
    imageUrl: json['imageUrl']?.toString(),
    consultationFee: (json['consultationFee'] as num?)?.toDouble(),
  );
}
