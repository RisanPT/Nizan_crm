class PaginatedResponse<T> {
  final List<T> items;
  final int totalItems;
  final int totalPages;
  final int page;
  final int limit;
  final Map<String, int>? stats;

  PaginatedResponse({
    required this.items,
    required this.totalItems,
    required this.totalPages,
    required this.page,
    required this.limit,
    this.stats,
  });

  factory PaginatedResponse.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return PaginatedResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => fromJsonT(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      stats: json['stats'] != null ? Map<String, int>.from(json['stats'] as Map) : null,
    );
  }
}
