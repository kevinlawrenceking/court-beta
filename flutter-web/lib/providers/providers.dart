import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../config/routes.dart';
import '../models/case_model.dart';
import '../models/event_model.dart';
import '../models/celebrity_model.dart';
import '../models/reference_models.dart';

// ──────────────────── Service Providers ────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  final auth = ref.watch(authServiceProvider);
  api.setAuthService(auth);

  // On irrecoverable 401, sign out and redirect to login.
  api.setOnUnauthorized(() async {
    await auth.signOut();
    ref.read(isAuthenticatedProvider.notifier).state = false;
  });

  return api;
});

// ──────────────────── Auth State ────────────────────

final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

// ──────────────────── Router ────────────────────

final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));

// ──────────────────── Case Providers ────────────────────

/// Filter state for the cases dashboard.
class CaseFilterState {
  final String? status;
  final int? toolId;
  final String? stateCode;
  final int? countyId;
  final String? courtCode;
  final int? celebrityId;
  final String? owner;
  final String? query;
  final int page;
  final String sort;
  final String order;

  const CaseFilterState({
    this.status,
    this.toolId,
    this.stateCode,
    this.countyId,
    this.courtCode,
    this.celebrityId,
    this.owner,
    this.query,
    this.page = 1,
    this.sort = 'created_at',
    this.order = 'desc',
  });

  CaseFilterState copyWith({
    String? status,
    int? toolId,
    String? stateCode,
    int? countyId,
    String? courtCode,
    int? celebrityId,
    String? owner,
    String? query,
    int? page,
    String? sort,
    String? order,
  }) {
    return CaseFilterState(
      status: status ?? this.status,
      toolId: toolId ?? this.toolId,
      stateCode: stateCode ?? this.stateCode,
      countyId: countyId ?? this.countyId,
      courtCode: courtCode ?? this.courtCode,
      celebrityId: celebrityId ?? this.celebrityId,
      owner: owner ?? this.owner,
      query: query ?? this.query,
      page: page ?? this.page,
      sort: sort ?? this.sort,
      order: order ?? this.order,
    );
  }
}

final caseFilterProvider = StateProvider<CaseFilterState>(
  (ref) => const CaseFilterState(status: 'Tracked'),
);

final casesProvider = FutureProvider.autoDispose<PaginatedResponse<CaseModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(caseFilterProvider);

  return api.getCases(
    page: filter.page,
    status: filter.status,
    toolId: filter.toolId,
    stateCode: filter.stateCode,
    countyId: filter.countyId,
    courtCode: filter.courtCode,
    celebrityId: filter.celebrityId,
    owner: filter.owner,
    query: filter.query,
    sort: filter.sort,
    order: filter.order,
  );
});

final caseDetailProvider = FutureProvider.autoDispose.family<CaseModel, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.getCase(id);
});

// ──────────────────── Event Providers ────────────────────

final unacknowledgedEventsProvider =
    FutureProvider.autoDispose<PaginatedResponse<EventModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getEvents(acknowledged: false, perPage: 50);
});

final caseEventsProvider =
    FutureProvider.autoDispose.family<PaginatedResponse<EventModel>, int>((ref, caseId) async {
  final api = ref.watch(apiClientProvider);
  return api.getEvents(caseId: caseId, perPage: 100);
});

// ──────────────────── Celebrity Providers ────────────────────

final celebritiesProvider =
    FutureProvider.autoDispose<PaginatedResponse<CelebrityModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCelebrities();
});

final celebrityDetailProvider =
    FutureProvider.autoDispose.family<CelebrityModel, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  return api.getCelebrity(id);
});

// ──────────────────── Match Providers ────────────────────

final matchesProvider =
    FutureProvider.autoDispose<PaginatedResponse<CelebrityMatchModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getMatches();
});

// ──────────────────── Monitor Providers ────────────────────

final monitorEventsProvider = FutureProvider.autoDispose<List<EventModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getMonitorEvents();
});

// ──────────────────── Reference Data Providers ────────────────────

final statesProvider = FutureProvider<List<StateModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getStates();
});

final countiesProvider =
    FutureProvider.family<List<CountyModel>, String?>((ref, stateCode) async {
  final api = ref.watch(apiClientProvider);
  return api.getCounties(stateCode: stateCode);
});

final courtsProvider =
    FutureProvider.family<List<CourtModel>, int?>((ref, countyId) async {
  final api = ref.watch(apiClientProvider);
  return api.getCourts(countyId: countyId);
});

final toolsProvider = FutureProvider<List<ToolModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getTools();
});

// ──────────────────── Selected Items ────────────────────

final selectedCaseIdsProvider = StateProvider<Set<int>>((ref) => {});
