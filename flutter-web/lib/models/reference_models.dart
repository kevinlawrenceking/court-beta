/// Reference data models for dropdowns and filters.

class StateModel {
  final String stateCode;
  final String stateName;

  const StateModel({required this.stateCode, required this.stateName});

  factory StateModel.fromJson(Map<String, dynamic> json) => StateModel(
        stateCode: json['state_code'] as String,
        stateName: json['state_name'] as String,
      );
}

class CountyModel {
  final int id;
  final String name;
  final String stateCode;

  const CountyModel({
    required this.id,
    required this.name,
    required this.stateCode,
  });

  factory CountyModel.fromJson(Map<String, dynamic> json) => CountyModel(
        id: json['id'] as int,
        name: json['name'] as String,
        stateCode: json['state_code'] as String,
      );
}

class CourtModel {
  final int id;
  final String courtCode;
  final String courtName;
  final String? address;
  final int? countyId;
  final String? courtType;

  const CourtModel({
    required this.id,
    required this.courtCode,
    required this.courtName,
    this.address,
    this.countyId,
    this.courtType,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) => CourtModel(
        id: json['id'] as int,
        courtCode: json['court_code'] as String,
        courtName: json['court_name'] as String,
        address: json['address'] as String?,
        countyId: json['county_id'] as int?,
        courtType: json['court_type'] as String?,
      );
}

class ToolModel {
  final int id;
  final String name;
  final String? toolType;
  final bool active;

  const ToolModel({
    required this.id,
    required this.name,
    this.toolType,
    this.active = true,
  });

  factory ToolModel.fromJson(Map<String, dynamic> json) => ToolModel(
        id: json['id'] as int,
        name: json['name'] as String,
        toolType: json['tool_type'] as String?,
        active: json['active'] as bool? ?? true,
      );
}

/// Standard paginated API response wrapper.
class PaginatedResponse<T> {
  final List<T> data;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const PaginatedResponse({
    required this.data,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });
}
