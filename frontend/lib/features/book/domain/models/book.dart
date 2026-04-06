import 'package:frontend/features/travel_log/domain/models/travel_log.dart';

class TravelBook {
  final int id;
  final String title;
  final String? description;
  final String? sweetbookUid;
  final String status;
  final String? bookSpecUid;
  final String? pdfUrl;
  final DateTime createdAt;
  final String? coverTemplateId;
  final String? coverParameters;
  final String? coverTemplateName;
  final String? coverThumbnail;
  final int price;
  final List<TravelLog> logs;
  final List<BookPage> pages;
  final int totalPages;
  final int minPages;
  final int maxPages;
  final int pageIncrement;

  TravelBook({
    required this.id,
    required this.title,
    this.description,
    this.sweetbookUid,
    required this.status,
    this.bookSpecUid,
    this.pdfUrl,
    required this.createdAt,
    this.coverTemplateId,
    this.coverParameters,
    this.coverTemplateName,
    this.coverThumbnail,
    this.price = 0,
    this.logs = const [],
    this.pages = const [],
    this.totalPages = 0,
    this.minPages = 24,
    this.maxPages = 130,
    this.pageIncrement = 2,
  });

  factory TravelBook.fromJson(Map<String, dynamic> json) {
    return TravelBook(
      id: json['id'] ?? 0,
      title: json['title'],
      description: json['description'],
      sweetbookUid: json['sweetbook_uid'],
      status: json['status'],
      bookSpecUid: json['book_spec_uid'],
      pdfUrl: json['pdf_url'],
      coverTemplateId: json['cover_template_id'],
      coverParameters: json['cover_parameters'],
      coverTemplateName: json['cover_template_name'],
      coverThumbnail: json['cover_thumbnail'],
      price: json['price'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      logs: json['logs'] != null
          ? (json['logs'] as List).map((i) => TravelLog.fromJson(i)).toList()
          : [],
      pages: json['pages'] != null
          ? (json['pages'] as List).map((i) => BookPage.fromJson(i)).toList()
          : [],
      totalPages: json['total_pages'] ?? 0,
      minPages: json['min_pages'] ?? 24,
      maxPages: json['max_pages'] ?? 130,
      pageIncrement: json['page_increment'] ?? 2,
    );
  }
}

class BookPage {
  final int id;
  final String templateUid;
  final String parameters;
  final int order;
  final int price;
  final String? templateName;
  final String? thumbnail;

  BookPage({
    required this.id,
    required this.templateUid,
    required this.parameters,
    required this.order,
    this.price = 100,
    this.templateName,
    this.thumbnail,
  });

  factory BookPage.fromJson(Map<String, dynamic> json) {
    return BookPage(
      id: json['id'] ?? 0,
      templateUid: json['template_uid'] ?? '',
      parameters: json['parameters'] ?? '',
      order: json['order'] ?? 0,
      price: json['price'] ?? 100,
      templateName: json['template_name'],
      thumbnail: json['template_thumbnail'],
    );
  }
}
