import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/case_model.dart';
import '../models/event_model.dart';
import '../models/document_model.dart';
import '../models/celebrity_model.dart';
import '../models/reference_models.dart';
import 'auth_service.dart';

/// Callback invoked when a 401 triggers sign-out.
typedef OnUnauthorized = void Function();

/// Central API client using Dio for all backend communication.
class ApiClient {
  late final Dio _dio;
  String? _authToken;
  AuthService? _authService;
  OnUnauthorized? _onUnauthorized;
  bool _isRefreshing = false;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
      receiveTimeout: Duration(seconds: ApiConfig.timeoutSeconds),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            // Retry the original request with the new token.
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $_authToken';
            try {
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            _onUnauthorized?.call();
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// Wire in the auth service for automatic token refresh.
  void setAuthService(AuthService service) => _authService = service;

  /// Set callback for when auth is irrecoverably expired.
  void setOnUnauthorized(OnUnauthorized callback) =>
      _onUnauthorized = callback;

  /// Sets the JWT auth token for subsequent requests.
  void setAuthToken(String token) => _authToken = token;

  /// Clears the auth token (on logout).
  void clearAuthToken() => _authToken = null;

  Future<bool> _tryRefreshToken() async {
    if (_authService == null) return false;
    _isRefreshing = true;
    try {
      final success = await _authService!.refreshSession();
      if (success) {
        _authToken = _authService!.accessToken;
        return true;
      }
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ──────────────────── Cases ────────────────────

  Future<PaginatedResponse<CaseModel>> getCases({
    int page = 1,
    int perPage = ApiConfig.defaultPageSize,
    String? status,
    int? toolId,
    String? stateCode,
    int? countyId,
    String? courtCode,
    int? celebrityId,
    String? owner,
    String? query,
    String sort = 'created_at',
    String order = 'desc',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'sort': sort,
      'order': order,
    };
    if (status != null) params['status'] = status;
    if (toolId != null) params['tool_id'] = toolId;
    if (stateCode != null) params['state_code'] = stateCode;
    if (countyId != null) params['county_id'] = countyId;
    if (courtCode != null) params['court_code'] = courtCode;
    if (celebrityId != null) params['celebrity_id'] = celebrityId;
    if (owner != null) params['owner'] = owner;
    if (query != null && query.isNotEmpty) params['q'] = query;

    final res = await _dio.get('/api/cases', queryParameters: params);
    return _parsePaginated(res.data, CaseModel.fromJson);
  }

  Future<CaseModel> getCase(int id) async {
    final res = await _dio.get('/api/cases/$id');
    return CaseModel.fromJson(res.data['data']);
  }

  Future<CaseModel> createCase(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/cases', data: data);
    return CaseModel.fromJson(res.data['data']);
  }

  Future<CaseModel> updateCase(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/api/cases/$id', data: data);
    return CaseModel.fromJson(res.data['data']);
  }

  Future<void> deleteCase(int id) async {
    await _dio.delete('/api/cases/$id');
  }

  Future<void> updateCaseStatus(int id, String status) async {
    await _dio.patch('/api/cases/$id/status', data: {'status': status});
  }

  Future<void> bulkUpdateCaseStatus(List<int> ids, String status) async {
    await _dio.patch('/api/cases/bulk-status', data: {
      'ids': ids,
      'status': status,
    });
  }

  Future<void> subscribeToCaseAlerts(int caseId) async {
    await _dio.post('/api/cases/$caseId/subscribers');
  }

  Future<void> unsubscribeFromCaseAlerts(int caseId, String username) async {
    await _dio.delete('/api/cases/$caseId/subscribers/$username');
  }

  // ──────────────────── Events ────────────────────

  Future<PaginatedResponse<EventModel>> getEvents({
    int page = 1,
    int perPage = ApiConfig.defaultPageSize,
    int? caseId,
    bool? acknowledged,
    bool? isDoc,
    bool? storyworthy,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (caseId != null) params['case_id'] = caseId;
    if (acknowledged != null) params['acknowledged'] = acknowledged;
    if (isDoc != null) params['is_doc'] = isDoc;
    if (storyworthy != null) params['storyworthy'] = storyworthy;

    final res = await _dio.get('/api/events', queryParameters: params);
    return _parsePaginated(res.data, EventModel.fromJson);
  }

  Future<void> acknowledgeEvent(int id) async {
    await _dio.post('/api/events/$id/acknowledge');
  }

  Future<void> bulkAcknowledgeEvents(List<int> ids) async {
    await _dio.post('/api/events/bulk-acknowledge', data: {'ids': ids});
  }

  // ──────────────────── Documents ────────────────────

  Future<DocumentModel> getDocument(int id) async {
    final res = await _dio.get('/api/documents/$id');
    return DocumentModel.fromJson(res.data['data']);
  }

  Future<DocumentModel> uploadDocument(
    List<int> fileBytes,
    String fileName, {
    int? caseEventId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      if (caseEventId != null) 'case_event_id': caseEventId,
    });

    final res = await _dio.post(
      '/api/documents/upload',
      data: formData,
      options: Options(
        receiveTimeout: Duration(seconds: ApiConfig.uploadTimeoutSeconds),
      ),
    );
    return DocumentModel.fromJson(res.data['data']);
  }

  Future<void> summarizeDocument(int id) async {
    await _dio.post('/api/documents/$id/summarize');
  }

  Future<List<ConversationEntry>> getConversationHistory(int docId) async {
    final res = await _dio.get('/api/documents/$docId/conversations');
    final list = res.data['data'] as List<dynamic>;
    return list
        .map((e) => ConversationEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> askDocumentQuestion(int docId, String question) async {
    await _dio.post('/api/documents/$docId/ask', data: {'question': question});
  }

  Future<void> saveQcFeedback(int docId, {
    required String rating,
    String? notes,
    String? modelName,
  }) async {
    await _dio.post('/api/documents/$docId/qc-feedback', data: {
      'rating': rating,
      if (notes != null) 'notes': notes,
      if (modelName != null) 'model_name': modelName,
    });
  }

  // ──────────────────── Celebrities ────────────────────

  Future<PaginatedResponse<CelebrityModel>> getCelebrities({
    int page = 1,
    int perPage = ApiConfig.defaultPageSize,
    bool? verified,
    String? query,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (verified != null) params['verified'] = verified;
    if (query != null && query.isNotEmpty) params['q'] = query;

    final res = await _dio.get('/api/celebrities', queryParameters: params);
    return _parsePaginated(res.data, CelebrityModel.fromJson);
  }

  Future<CelebrityModel> getCelebrity(int id) async {
    final res = await _dio.get('/api/celebrities/$id');
    return CelebrityModel.fromJson(res.data['data']);
  }

  Future<List<CelebrityModel>> searchCelebrities(String query) async {
    final res = await _dio.get('/api/celebrities/search', queryParameters: {'q': query});
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => CelebrityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CelebrityModel> createCelebrity(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/celebrities', data: data);
    return CelebrityModel.fromJson(res.data['data']);
  }

  // ──────────────────── Matches ────────────────────

  Future<PaginatedResponse<CelebrityMatchModel>> getMatches({
    int page = 1,
    int perPage = ApiConfig.defaultPageSize,
    int? caseId,
    int? celebrityId,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (caseId != null) params['case_id'] = caseId;
    if (celebrityId != null) params['celebrity_id'] = celebrityId;
    if (status != null) params['status'] = status;

    final res = await _dio.get('/api/matches', queryParameters: params);
    return _parsePaginated(res.data, CelebrityMatchModel.fromJson);
  }

  Future<void> createMatch(int caseId, int celebrityId) async {
    await _dio.post('/api/matches', data: {
      'case_id': caseId,
      'celebrity_id': celebrityId,
    });
  }

  Future<void> deleteMatch(int id) async {
    await _dio.delete('/api/matches/$id');
  }

  Future<void> updateMatchStatus(int id, String status) async {
    await _dio.patch('/api/matches/$id/status', data: {'status': status});
  }

  // ──────────────────── Monitor ────────────────────

  Future<List<EventModel>> getMonitorEvents({int limit = 50}) async {
    final res = await _dio.get('/api/monitor/events', queryParameters: {'limit': limit});
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ──────────────────── Reference Data ────────────────────

  Future<List<StateModel>> getStates() async {
    final res = await _dio.get('/api/reference/states');
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => StateModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CountyModel>> getCounties({String? stateCode}) async {
    final params = <String, dynamic>{};
    if (stateCode != null) params['state_code'] = stateCode;
    final res = await _dio.get('/api/reference/counties', queryParameters: params);
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => CountyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CourtModel>> getCourts({int? countyId, String? stateCode}) async {
    final params = <String, dynamic>{};
    if (countyId != null) params['county_id'] = countyId;
    if (stateCode != null) params['state_code'] = stateCode;
    final res = await _dio.get('/api/reference/courts', queryParameters: params);
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => CourtModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ToolModel>> getTools() async {
    final res = await _dio.get('/api/reference/tools');
    final list = res.data['data'] as List<dynamic>;
    return list.map((e) => ToolModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ──────────────────── Admin ────────────────────

  Future<List<Map<String, dynamic>>> getTaskLogs({int limit = 50}) async {
    final res = await _dio.get('/api/admin/tasks', queryParameters: {'limit': limit});
    return (res.data['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getErrorLogs({
    String? severity,
    bool? resolved,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (severity != null) params['severity'] = severity;
    if (resolved != null) params['resolved'] = resolved;
    final res = await _dio.get('/api/admin/errors', queryParameters: params);
    return (res.data['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<int> resolveErrors(List<int> ids) async {
    final res = await _dio.post('/api/admin/errors/resolve', data: {'ids': ids});
    return res.data['resolved'] as int? ?? 0;
  }

  Future<List<Map<String, dynamic>>> getArticles({int limit = 50}) async {
    final res = await _dio.get('/api/admin/articles', queryParameters: {'limit': limit});
    return (res.data['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ──────────────────── Helpers ────────────────────

  PaginatedResponse<T> _parsePaginated<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final meta = json['meta'] as Map<String, dynamic>;
    final dataList = json['data'] as List<dynamic>;
    return PaginatedResponse<T>(
      data: dataList.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      page: meta['page'] as int,
      perPage: meta['per_page'] as int,
      total: meta['total'] as int,
      totalPages: meta['total_pages'] as int,
    );
  }
}
