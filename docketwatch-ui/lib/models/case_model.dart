/// Represents a court case in the system.
class CaseModel {
  final int id;
  final String caseNumber;
  final String caseName;
  final String? caseType;
  final String? courtCode;
  final String status;
  final String? owner;
  final int? toolId;
  final DateTime? filingDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int eventCount;
  final int docCount;
  final List<CelebrityMatchModel>? celebrities;

  const CaseModel({
    required this.id,
    required this.caseNumber,
    required this.caseName,
    this.caseType,
    this.courtCode,
    required this.status,
    this.owner,
    this.toolId,
    this.filingDate,
    required this.createdAt,
    required this.updatedAt,
    this.eventCount = 0,
    this.docCount = 0,
    this.celebrities,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      id: json['id'] as int,
      caseNumber: json['case_number'] as String,
      caseName: json['case_name'] as String? ?? '',
      caseType: json['case_type'] as String?,
      courtCode: json['court_code'] as String?,
      status: json['status'] as String? ?? 'Review',
      owner: json['owner'] as String?,
      toolId: json['tool_id'] as int?,
      filingDate: json['filing_date'] != null
          ? DateTime.parse(json['filing_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      eventCount: json['event_count'] as int? ?? 0,
      docCount: json['doc_count'] as int? ?? 0,
      celebrities: (json['celebrities'] as List<dynamic>?)
          ?.map((e) => CelebrityMatchModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'case_number': caseNumber,
        'case_name': caseName,
        'case_type': caseType,
        'court_code': courtCode,
        'status': status,
        'owner': owner,
        'tool_id': toolId,
      };
}

/// Represents a celebrity-case match (lightweight, for embedding).
class CelebrityMatchModel {
  final int id;
  final int caseId;
  final int celebrityId;
  final String matchStatus;
  final double? matchScore;
  final String? matchedBy;
  final String? celebrityName;
  final String? celebrityImageUrl;

  const CelebrityMatchModel({
    required this.id,
    required this.caseId,
    required this.celebrityId,
    required this.matchStatus,
    this.matchScore,
    this.matchedBy,
    this.celebrityName,
    this.celebrityImageUrl,
  });

  factory CelebrityMatchModel.fromJson(Map<String, dynamic> json) {
    final celebrity = json['celebrity'] as Map<String, dynamic>?;
    return CelebrityMatchModel(
      id: json['id'] as int,
      caseId: json['case_id'] as int,
      celebrityId: json['celebrity_id'] as int,
      matchStatus: json['match_status'] as String? ?? 'Pending',
      matchScore: (json['match_score'] as num?)?.toDouble(),
      matchedBy: json['matched_by'] as String?,
      celebrityName: celebrity?['name'] as String?,
      celebrityImageUrl: celebrity?['image_url'] as String?,
    );
  }
}
