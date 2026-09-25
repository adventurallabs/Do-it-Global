class School {
  final String id;
  final String name;
  final String logoUrl;
  final String primaryColorHex;
  final List<String> enabledFeatures;
  final int attendanceWarningThreshold;

  School({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.primaryColorHex,
    required this.enabledFeatures,
    this.attendanceWarningThreshold = 85,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'] ?? '',
      primaryColorHex: json['primary_color_hex'],
      enabledFeatures: List<String>.from(json['enabled_features'] ?? []),
      attendanceWarningThreshold: json['attendance_warning_threshold'] ?? 85,
    );
  }
}
