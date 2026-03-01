/// Represents a PDF document with OCR text and AI summaries.
class DocumentModel {
  final int id;
  final String docUid;
  final int? caseEventId;
  final String? pdfTitle;
  final String? s3Key;
  final int? fileSize;
  final String? sha256Hash;
  final String? ocrText;
  final String? summaryAi;
  final String? summaryAiHtml;
  final Map<String, dynamic>? extractionJson;
  final String? modelName;
  final int? processingMs;
  final int? tokensInput;
  final int? tokensOutput;
  final DateTime createdAt;

  const DocumentModel({
    required this.id,
    required this.docUid,
    this.caseEventId,
    this.pdfTitle,
    this.s3Key,
    this.fileSize,
    this.sha256Hash,
    this.ocrText,
    this.summaryAi,
    this.summaryAiHtml,
    this.extractionJson,
    this.modelName,
    this.processingMs,
    this.tokensInput,
    this.tokensOutput,
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as int,
      docUid: json['doc_uid'] as String,
      caseEventId: json['case_event_id'] as int?,
      pdfTitle: json['pdf_title'] as String?,
      s3Key: json['s3_key'] as String?,
      fileSize: json['file_size'] as int?,
      sha256Hash: json['sha256_hash'] as String?,
      ocrText: json['ocr_text'] as String?,
      summaryAi: json['summary_ai'] as String?,
      summaryAiHtml: json['summary_ai_html'] as String?,
      extractionJson: json['summary_ai_extraction_json'] as Map<String, dynamic>?,
      modelName: json['model_name'] as String?,
      processingMs: json['processing_ms'] as int?,
      tokensInput: json['tokens_input'] as int?,
      tokensOutput: json['tokens_output'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Human-readable file size.
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Represents a single Q&A exchange for a document.
class ConversationEntry {
  final int id;
  final int documentId;
  final String sessionId;
  final String promptText;
  final String responseText;
  final String? modelName;
  final int? tokensInput;
  final int? tokensOutput;
  final int? rating;
  final String? feedback;
  final DateTime createdAt;

  const ConversationEntry({
    required this.id,
    required this.documentId,
    required this.sessionId,
    required this.promptText,
    required this.responseText,
    this.modelName,
    this.tokensInput,
    this.tokensOutput,
    this.rating,
    this.feedback,
    required this.createdAt,
  });

  factory ConversationEntry.fromJson(Map<String, dynamic> json) {
    return ConversationEntry(
      id: json['id'] as int,
      documentId: json['document_id'] as int,
      sessionId: json['session_id'] as String,
      promptText: json['prompt_text'] as String,
      responseText: json['response_text'] as String,
      modelName: json['model_name'] as String?,
      tokensInput: json['tokens_input'] as int?,
      tokensOutput: json['tokens_output'] as int?,
      rating: json['rating'] as int?,
      feedback: json['feedback'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
