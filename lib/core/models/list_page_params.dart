class ListPageParams {
  final int page;
  final int limit;

  const ListPageParams({
    required this.page,
    required this.limit,
  });

  @override
  bool operator ==(Object other) {
    return other is ListPageParams &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(page, limit);
}
