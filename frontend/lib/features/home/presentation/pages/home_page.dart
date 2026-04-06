import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/book/presentation/providers/book_provider.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/features/book/presentation/pages/book_builder_page.dart';
import 'package:frontend/features/payment/presentation/pages/payment_page.dart';
import 'package:frontend/features/book/presentation/widgets/create_book_wizard.dart';
import 'package:frontend/features/book/presentation/pages/publish_page.dart';
import 'package:frontend/features/payment/presentation/providers/cart_provider.dart';
import 'package:frontend/features/payment/presentation/providers/credit_provider.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final bookState = ref.watch(bookListProvider);
    final cart = ref.watch(cartProvider);
    final creditState = ref.watch(creditProvider);
    final formatter = NumberFormat('#,###');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            '나의 트래블북',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: '결제 및 잔액',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentPage()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '디자인 중인 프로젝트'),
              Tab(text: '제작 완료 (주문하기)'),
            ],
            indicatorColor: Colors.indigo,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: bookState.when(
          data: (books) {
            final editingBooks = books
                .where((b) => b.status.toLowerCase() != 'finalized')
                .toList();
            final finalizedBooks = books
                .where((b) => b.status.toLowerCase() == 'finalized')
                .toList();

            return Column(
              children: [
                // 크레딧 정보 배너
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 18,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '현재 가용 크레딧:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      creditState.when(
                        data: (balance) => Text(
                          '${formatter.format(balance)}원',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => const Text(
                          '조회 실패',
                          style: TextStyle(fontSize: 13, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 1. 디자인 중인 프로젝트 탭
                      RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(bookListProvider.notifier)
                              .fetchBooks();
                          await ref
                              .read(creditProvider.notifier)
                              .refreshBalance();
                        },
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: _buildCreateProjectCard(context),
                              ),
                            ),
                            if (editingBooks.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    '아직 제작 중인 책이 없습니다.\n새로운 여행기를 만들어보세요!',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    return _buildBookCard(
                                      context,
                                      editingBooks[index],
                                      isFinalized: false,
                                    );
                                  }, childCount: editingBooks.length),
                                ),
                              ),
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 32),
                            ),
                          ],
                        ),
                      ),

                      // 2. 제작 완료 및 주문하기 탭
                      Stack(
                        children: [
                          RefreshIndicator(
                            onRefresh: () async {
                              await ref
                                  .read(bookListProvider.notifier)
                                  .fetchBooks();
                              await ref
                                  .read(creditProvider.notifier)
                                  .refreshBalance();
                            },
                            child: CustomScrollView(
                              slivers: [
                                const SliverPadding(
                                  padding: EdgeInsets.only(top: 24),
                                ),
                                if (finalizedBooks.isEmpty)
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Text(
                                        '제작이 완료된 책이 없습니다.\n\n프로젝트를 열어 [제작 완료] 버튼을 눌러보세요.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        index,
                                      ) {
                                        return _buildBookCard(
                                          context,
                                          finalizedBooks[index],
                                          isFinalized: true,
                                          cartQty:
                                              cart[finalizedBooks[index].id] ??
                                              0,
                                        );
                                      }, childCount: finalizedBooks.length),
                                    ),
                                  ),
                                const SliverPadding(
                                  padding: EdgeInsets.only(bottom: 100),
                                ),
                              ],
                            ),
                          ),
                          if (cart.isNotEmpty)
                            Positioned(
                              bottom: 24,
                              left: 24,
                              right: 24,
                              child: ElevatedButton(
                                onPressed: () {
                                  final selectedBooks = finalizedBooks
                                      .where((b) => cart.containsKey(b.id))
                                      .toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PublishPage(
                                        books: selectedBooks,
                                        quantities: cart,
                                      ),
                                    ),
                                  ).then(
                                    (_) => ref
                                        .read(bookListProvider.notifier)
                                        .fetchBooks(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 8,
                                ),
                                child: Text(
                                  '선택한 ${cart.values.fold(0, (int sum, val) => sum + val)}권 주문하기',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ), // Stack
                    ], // TabBarView children
                  ), // TabBarView
                ), // Expanded
              ], // Column children
            ); // Column
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('데이터를 불러오지 못했습니다: $err')),
        ),
      ),
    );
  }

  Widget _buildCreateProjectCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCreateBookWizard(context),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo, Colors.indigo.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새 여행 프로젝트 시작',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '나만의 특별한 여행기를 만들어보세요',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    TravelBook book, {
    required bool isFinalized,
    int cartQty = 0,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          if (!isFinalized) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookBuilderPage(book: book),
              ),
            ).then((_) => ref.read(bookListProvider.notifier).fetchBooks());
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: isFinalized ? Colors.green[50] : Colors.indigo[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isFinalized ? Icons.local_shipping_outlined : Icons.book,
                  color: isFinalized ? Colors.green : Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '상태: ${_getStatusText(book.status)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(book.status),
                      ),
                    ),
                  ],
                ),
              ),
              if (isFinalized)
                Row(
                  children: [
                    if (cartQty > 0) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.indigo,
                        ),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(book.id, cartQty - 1),
                      ),
                      InkWell(
                        onTap: () =>
                            _showQuantityDialog(context, ref, book.id, cartQty),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$cartQty',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.indigo,
                        ),
                        onPressed: () {
                          if (cartQty < 100) {
                            ref
                                .read(cartProvider.notifier)
                                .updateQuantity(book.id, cartQty + 1);
                          } else {
                            _showErrorDialog(context, '최대 100권까지 주문 가능합니다.');
                          }
                        },
                      ),
                    ] else
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(cartProvider.notifier).add(book.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('담기'),
                      ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('프로젝트 삭제'),
                        content: Text('"${book.title}" 프로젝트를 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              try {
                                await apiService.deleteBook(book.id);
                                ref
                                    .read(bookListProvider.notifier)
                                    .fetchBooks();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('삭제 실패: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              '삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (!isFinalized)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'manual_editing':
        return '편집 중';
      case 'finalized':
        return '제작 완료';
      case 'ordered':
        return '주문 접수';
      default:
        return '디자인 중';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'manual_editing':
        return Colors.orange;
      case 'finalized':
        return Colors.green;
      case 'ordered':
        return Colors.blue;
      default:
        return Colors.indigo;
    }
  }

  void _showCreateBookWizard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: CreateBookWizard(),
      ),
    );
  }

  void _showQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    int bookId,
    int currentQty,
  ) {
    final controller = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수량 직접 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('주문하실 수량을 입력해주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: '권',
                hintText: '숫자만 입력',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val == null) {
                _showErrorDialog(context, '올바른 숫자를 입력해주세요.');
                return;
              }
              if (val > 100) {
                // 스윗북 API 상한선
                _showErrorDialog(context, '한 번에 최대 100권까지 주문 가능합니다.');
                return;
              }
              ref.read(cartProvider.notifier).updateQuantity(bookId, val);
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
