class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.relationship,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    relationship: json['relationship'] as String,
  );

  final int id;
  final String fullName;
  final String relationship;

  String get label => '$fullName — $relationship';
}
