/// Represents a celebrity tracked in the system.
class CelebrityModel {
  final int id;
  final String name;
  final int? tmzCelebId;
  final String? imageUrl;
  final bool verified;
  final DateTime createdAt;
  final int caseCount;

  const CelebrityModel({
    required this.id,
    required this.name,
    this.tmzCelebId,
    this.imageUrl,
    this.verified = false,
    required this.createdAt,
    this.caseCount = 0,
  });

  factory CelebrityModel.fromJson(Map<String, dynamic> json) {
    return CelebrityModel(
      id: json['id'] as int,
      name: json['name'] as String,
      tmzCelebId: json['tmz_celeb_id'] as int?,
      imageUrl: json['image_url'] as String?,
      verified: json['verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      caseCount: json['case_count'] as int? ?? 0,
    );
  }
}
