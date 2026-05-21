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

  const ListPageParams({
    required this.page,
    required this.limit,
    this.category,
    this.search,
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
        other.search == search &&
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
        search,
        zoneId,
        stateId,
        regionId,
        districtId,
        pincodeId,
      );
}
