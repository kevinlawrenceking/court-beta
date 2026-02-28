/// Represents a docket entry / court event.
class EventModel {
  final int id;
  final int caseId;
  final DateTime? eventDate;
  final String eventDescription;
  final String? eventUrl;
  final bool isDoc;
  final bool acknowledged;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final bool processing;
  final bool storyworthy;
  final DateTime createdAt;

  // Joined data
  final String? caseName;
  final String? caseNumber;
  final String? summaryHtml;

  const EventModel({
    required this.id,
    required this.caseId,
    this.eventDate,
    required this.eventDescription,
    this.eventUrl,
    this.isDoc = false,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.processing = false,
    this.storyworthy = false,
    required this.createdAt,
    this.caseName,
    this.caseNumber,
    this.summaryHtml,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final caseData = json['case'] as Map<String, dynamic>?;
    final docData = json['document'] as Map<String, dynamic>?;
    return EventModel(
      id: json['id'] as int,
      caseId: json['case_id'] as int,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      eventDescription: json['event_description'] as String? ?? '',
      eventUrl: json['event_url'] as String?,
      isDoc: json['is_doc'] as bool? ?? false,
      acknowledged: json['acknowledged'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      acknowledgedBy: json['acknowledged_by'] as String?,
      processing: json['processing'] as bool? ?? false,
      storyworthy: json['storyworthy'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      caseName: caseData?['case_name'] as String?,
      caseNumber: caseData?['case_number'] as String?,
      summaryHtml: docData?['summary_ai_html'] as String?,
    );
  }
}
