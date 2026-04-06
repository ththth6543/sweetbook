import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/features/travel_log/domain/models/travel_log.dart';
import 'package:frontend/features/book/domain/models/book.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: dotenv.get('API_BASE_URL', fallback: 'http://127.0.0.1:8000/api/v1'),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<List<TravelLog>> getLogs() async {
    try {
      final response = await _dio.get('/logs/');
      return (response.data as List).map((e) => TravelLog.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching logs: $e');
      rethrow;
    }
  }

  Future<TravelLog> createLog(TravelLog log) async {
    try {
      final response = await _dio.post('/logs/', data: log.toJson());
      return TravelLog.fromJson(response.data);
    } catch (e) {
      print('Error creating log: $e');
      rethrow;
    }
  }

  Future<void> deleteLog(int id) async {
    try {
      await _dio.delete('/logs/$id');
    } catch (e) {
      print('Error deleting log: $id, $e');
      rethrow;
    }
  }

  // Book & Step-by-Step APIs
  Future<List<TravelBook>> getBooks() async {
    try {
      final response = await _dio.get('/books/');
      return (response.data as List)
          .map((e) => TravelBook.fromJson(e))
          .toList();
    } catch (e) {
      print('Error fetching books: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getSpecs() async {
    try {
      final response = await _dio.get('/books/specs');
      final data = response.data['data'];
      if (data is List) return data;
      if (data is Map && data['items'] is List) return data['items'];
      return [];
    } catch (e) {
      print('Error fetching specs: $e');
      return [];
    }
  }

  Future<List<dynamic>> getTemplates(
    String? specUid, {
    String? kind,
    String scope = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      print(
        'Fetching templates for Spec: $specUid, Kind: $kind, Scope: $scope',
      );
      final response = await _dio.get(
        '/books/templates',
        queryParameters: {
          'book_spec_uid': specUid,
          'template_kind': kind,
          'scope': scope,
          'limit': limit,
          'offset': offset,
        },
      );

      final dynamic rawData = response.data['data'];
      print('Raw Template Response Type: ${rawData.runtimeType}');

      if (rawData == null) {
        print('Warning: Template data is null from server');
        return [];
      }

      print(
        'Raw Template Response Count: ${rawData is List ? rawData.length : (rawData is Map ? (rawData['items']?.length ?? "0 (items null)") : "Unknown")}',
      );

      if (rawData is List) return rawData;
      if (rawData is Map && rawData['items'] is List) return rawData['items'];

      return [];
    } catch (e) {
      print('Error fetching templates: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getTemplateDetails(String templateUid) async {
    try {
      final response = await _dio.get('/books/templates/$templateUid');
      return response.data;
    } catch (e) {
      print('Error fetching template details: $e');
      rethrow;
    }
  }

  Future<TravelBook> createBook({
    required String title,
    String? description,
    List<int> logIds = const [],
    String? bookSpecUid,
    String? coverTemplateId,
    bool manualEdit = false,
  }) async {
    try {
      final response = await _dio.post(
        '/books/',
        data: {
          'title': title,
          'description': description,
          'log_ids': logIds,
          'book_spec_uid': bookSpecUid,
          'cover_template_id': coverTemplateId,
          'manual_edit': manualEdit,
        },
      );
      return TravelBook.fromJson(response.data);
    } catch (e) {
      print('Error creating book: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCover(
    int bookId,
    String templateUid,
    String parameters,
  ) async {
    try {
      final response = await _dio.post(
        '/books/$bookId/cover',
        queryParameters: {
          'template_uid': templateUid,
          'parameters': parameters,
        },
      );
      return response.data;
    } catch (e) {
      print('Error updating cover: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadPhoto(
    int bookId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post('/books/$bookId/photos', data: formData);
      return response.data;
    } catch (e) {
      print('Error uploading photo: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addPage(
    int bookId,
    String templateUid,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final response = await _dio.post(
        '/books/$bookId/pages',
        data: {
          'template_uid': templateUid,
          'parameters': jsonEncode(parameters),
          'order': 0,
          'price': 100,
        },
      );
      return response.data;
    } catch (e) {
      print('Error adding page: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePage(
    int bookId,
    int pageId,
    String? templateUid,
    Map<String, dynamic>? parameters,
  ) async {
    try {
      final Map<String, dynamic> data = {};
      if (templateUid != null) data['template_uid'] = templateUid;
      if (parameters != null) data['parameters'] = jsonEncode(parameters);

      final response = await _dio.put(
        '/books/$bookId/pages/$pageId',
        data: data,
      );
      return response.data;
    } catch (e) {
      print('Error updating page: $e');
      rethrow;
    }
  }

  Future<void> deletePage(int bookId, int pageId) async {
    try {
      await _dio.delete('/books/$bookId/pages/$pageId');
    } catch (e) {
      print('Error deleting page: $e');
      rethrow;
    }
  }

  Future<void> reorderPages(int bookId, List<int> pageIds) async {
    try {
      await _dio.put('/books/$bookId/pages/reorder', data: pageIds);
    } catch (e) {
      print('Error reordering pages: $e');
      rethrow;
    }
  }

  Future<void> finalizeBook(int bookId) async {
    try {
      await _dio.post('/books/$bookId/finalization');
    } catch (e) {
      print('Error finalizing book: $e');
      rethrow;
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      await _dio.delete('/books/$id');
    } catch (e) {
      print('Error deleting book: $id, $e');
      rethrow;
    }
  }

  // Order APIs
  Future<Map<String, dynamic>> getBulkEstimate(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await _dio.post(
        '/orders/bulk-estimate',
        data: {'items': items},
      );
      return response.data;
    } catch (e) {
      print('Error getting bulk estimate: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createBulkOrder(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> shipping,
  ) async {
    try {
      final response = await _dio.post(
        '/orders/bulk',
        data: {'items': items, 'shipping': shipping},
      );
      return response.data;
    } catch (e) {
      print('Error creating bulk order: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getEstimate(
    int bookId, {
    int quantity = 1,
  }) async {
    try {
      final response = await _dio.post(
        '/orders/estimate',
        queryParameters: {'book_id': bookId, 'quantity': quantity},
      );
      return response.data;
    } catch (e) {
      print('Error getting estimate: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createOrder(
    int bookId,
    int quantity,
    Map<String, dynamic> shipping,
  ) async {
    try {
      final response = await _dio.post(
        '/orders/',
        data: {'book_id': bookId, 'quantity': quantity, 'shipping': shipping},
      );
      return response.data;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCreditBalance() async {
    final response = await _dio.get('/orders/credits');
    return response.data;
  }

  Future<Map<String, dynamic>> getCreditTransactions({int limit = 20, int offset = 0}) async {
    final response = await _dio.get(
      '/orders/credits/transactions',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> sandboxCharge(int amount, String memo) async {
    final response = await _dio.post(
      '/orders/credits/sandbox/charge',
      data: {'amount': amount, 'memo': memo},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> sandboxDeduct(int amount, String memo) async {
    final response = await _dio.post(
      '/orders/credits/sandbox/deduct',
      data: {'amount': amount, 'memo': memo},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getCredits() async {
    try {
      final response = await _dio.get('/orders/credits');
      return response.data;
    } catch (e) {
      print('Error fetching credits: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrders({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/orders/',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return response.data;
    } catch (e) {
      print('Error fetching orders: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrderDetails(String orderUid) async {
    try {
      final response = await _dio.get('/orders/$orderUid');
      return response.data;
    } catch (e) {
      print('Error fetching order details: $e');
      rethrow;
    }
  }
}

final apiService = ApiService();
