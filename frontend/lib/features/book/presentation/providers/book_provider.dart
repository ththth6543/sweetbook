import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/core/network/api_service.dart';

final bookListProvider = AsyncNotifierProvider<BookListNotifier, List<TravelBook>>(() {
  return BookListNotifier();
});

class BookListNotifier extends AsyncNotifier<List<TravelBook>> {
  @override
  FutureOr<List<TravelBook>> build() async {
    return await apiService.getBooks();
  }

  Future<void> fetchBooks() async {
    state = const AsyncValue.loading();
    try {
      final books = await apiService.getBooks();
      state = AsyncValue.data(books);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<TravelBook?> createBook({
    required String title,
    String? description,
    List<int> logIds = const [],
    String? bookSpecUid,
    String? coverTemplateId,
    bool manualEdit = false,
  }) async {
    try {
      final newBook = await apiService.createBook(
        title: title,
        description: description,
        logIds: logIds,
        bookSpecUid: bookSpecUid,
        coverTemplateId: coverTemplateId,
        manualEdit: manualEdit,
      );
      
      ref.invalidateSelf();
      await future;
      
      return newBook;
    } catch (e) {
      print('Failed to create book: $e');
      return null;
    }
  }

  Future<bool> deleteBook(int id) async {
    try {
      await apiService.deleteBook(id);
      
      ref.invalidateSelf();
      await future;
      
      return true;
    } catch (e) {
      print('Failed to delete book: $e');
      return false;
    }
  }
}
