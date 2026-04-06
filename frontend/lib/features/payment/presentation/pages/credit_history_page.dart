import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/features/payment/presentation/providers/credit_provider.dart';

class CreditHistoryPage extends ConsumerWidget {
  const CreditHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsState = ref.watch(creditTransactionsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '크레딧 이용내역',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(creditTransactionsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: transactionsState.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '이용 내역이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final rawDirection =
                  tx['direction']?.toString().toLowerCase().trim() ?? '';
              final reasonCode = int.tryParse(
                tx['reasonCode']?.toString() ?? '',
              );

              // 충전(Credit) 판단 로직 - direction이 'credit'이거나
              // 충전에 해당하는 reasonCode(1, 2, 4, 7, 9) 중 하나라도 만족하면 충전으로 간주
              final isCredit =
                  rawDirection == 'credit' ||
                  (reasonCode != null && [1, 2, 4, 7, 9].contains(reasonCode));

              // 금액 데이터에서 혹시 모를 마이너스 기호를 완전히 제거 (절댓값 강제)
              final rawAmount =
                  double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
              final amount = rawAmount.abs();

              final balanceAfter = tx['balanceAfter'] ?? 0;
              final createdAt = DateTime.parse(
                tx['createdAt'] ?? DateTime.now().toIso8601String(),
              );
              final reason = tx['reasonDisplay'] ?? '기타 거래';
              final memo = tx['memo'] ?? '';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCredit ? Colors.blue[50] : Colors.orange[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: isCredit ? Colors.blue : Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reason,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (memo.isNotEmpty)
                            Text(
                              memo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(createdAt),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}${currencyFormat.format(amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCredit ? Colors.blue : Colors.redAccent,
                          ),
                        ),
                        Text(
                          '잔액: ${currencyFormat.format(balanceAfter)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('에러 발생: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(creditTransactionsProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
