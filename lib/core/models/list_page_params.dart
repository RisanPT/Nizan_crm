class ListPageParams {
  final int page;
  final int limit;
  final String? category;
  final String? search;
  final String? zoneId;
  final String? stateId;
  final String? regionId;
  final String? districtId;
  final String? pincodeId;

  final String? department;
  final String? artistRole;

  /// Customer list: status filter ('Active'/'Inactive'/'Prospect') and sort key
  /// ('newest'/'oldest'/'name_asc'/'name_desc').
  final String? status;
  final String? sort;

  const ListPageParams({
    required this.page,
    required this.limit,
    this.category,
    this.department,
    this.artistRole,
    this.search,
    this.status,
    this.sort,
    this.zoneId,
    this.stateId,
    this.regionId,
    this.districtId,
    this.pincodeId,
  });

  @override
  bool operator ==(Object other) {
    return other is ListPageParams &&
        other.page == page &&
        other.limit == limit &&
        other.category == category &&
        other.department == department &&
        other.artistRole == artistRole &&
        other.search == search &&
        other.status == status &&
        other.sort == sort &&
        other.zoneId == zoneId &&
        other.stateId == stateId &&
        other.regionId == regionId &&
        other.districtId == districtId &&
        other.pincodeId == pincodeId;
  }

  @override
  int get hashCode => Object.hash(
        page,
        limit,
        category,
        department,
        artistRole,
        search,
        status,
        sort,
        zoneId,
        stateId,
        regionId,
        districtId,
        pincodeId,
      );
}
