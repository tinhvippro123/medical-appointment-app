/// Model phân trang dùng chung cho mọi danh sách từ backend
class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  const PagedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  /// Factory builder generic từ Map JSON
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic itemJson) fromJsonT,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? <dynamic>[];
    final items = rawItems.map(fromJsonT).toList();
    final totalCount = (json['totalCount'] as num?)?.toInt() ?? items.length;
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final pageSize = (json['pageSize'] as num?)?.toInt() ?? (items.isNotEmpty ? items.length : 10);
    final calculatedTotalPages = pageSize > 0 ? (totalCount / pageSize).ceil() : 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ?? calculatedTotalPages;
    final hasPreviousPage = json['hasPreviousPage'] as bool? ?? (page > 1);
    final hasNextPage = json['hasNextPage'] as bool? ?? (page < totalPages);

    return PagedResult<T>(
      items: items,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      totalPages: totalPages,
      hasPreviousPage: hasPreviousPage,
      hasNextPage: hasNextPage,
    );
  }

  /// Khởi tạo đối tượng phân trang rỗng
  factory PagedResult.empty({int page = 1, int pageSize = 10}) => PagedResult<T>(
    items: const [],
    totalCount: 0,
    page: page,
    pageSize: pageSize,
    totalPages: 0,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}
