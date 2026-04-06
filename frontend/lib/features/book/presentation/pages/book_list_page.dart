import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/features/book/presentation/providers/book_provider.dart';
import 'package:frontend/features/book/presentation/pages/publish_page.dart';

class BookListPage extends ConsumerWidget {
  const BookListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookState = ref.watch(bookListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 여행기 목록', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(bookListProvider.notifier).fetchBooks(),
          ),
        ],
      ),
      body: bookState.when(
        data: (books) => books.isEmpty
            ? const Center(child: Text('아직 생성된 여행기가 없습니다.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusChip(book.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '생성일: ${DateFormat('yyyy-MM-dd HH:mm').format(book.createdAt)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          if (book.description != null && book.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                book.description!,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.auto_stories, size: 16, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 4),
                              Text('${book.logs.length}개의 여행 기록 포함'),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: '여행기 삭제',
                                onPressed: () => _confirmDelete(context, ref, book.id, book.title),
                              ),
                              if (book.status == 'finalized')
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PublishPage(
                                          books: [book],
                                          quantities: {book.id: 1},
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.shopping_cart),
                                  label: const Text('출판하기'),
                                )
                              else if (book.pdfUrl != null)
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('미리보기 URL: ${book.pdfUrl}')),
                                    );
                                  },
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('PDF 보기'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류 발생: $err')),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int bookId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행기 삭제'),
        content: Text('"$title" 여행기를 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookListProvider.notifier).deleteBook(bookId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'finalized':
        color = Colors.green;
        text = '제작 완료 (주문 가능)';
        break;
      case 'contents_uploaded':
        color = Colors.blue;
        text = '업로드됨';
        break;
      case 'created':
      case 'manual_editing':
        color = Colors.orange;
        text = '편집 중';
        break;
      default:
        color = status.startsWith('error') ? Colors.red : Colors.grey;
        text = '오류';
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
