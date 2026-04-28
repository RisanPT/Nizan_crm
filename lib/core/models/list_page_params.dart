class ListPageParams {
  final int page;
  final int limit;
  final String? category;

  const ListPageParams({
    required this.page,
    required this.limit,
    this.category,
  });

  @override
  bool operator ==(Object other) {
    return other is ListPageParams &&
        other.page == page &&
        other.limit == limit &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(page, limit, category);
}
