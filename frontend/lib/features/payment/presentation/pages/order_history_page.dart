import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/features/payment/presentation/providers/order_provider.dart';
import 'package:frontend/features/payment/presentation/pages/order_details_page.dart';

class OrderHistoryPage extends ConsumerWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderHistoryProvider);
    final dateFormatter = DateFormat('yyyy.MM.dd HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '주문 내역',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(orderHistoryProvider.notifier).refreshOrders(),
          ),
        ],
      ),
      body: orderState.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '주문 내역이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final items = order['items'] as List? ?? [];
              final orderStatus = order['orderStatus']?.toString() ?? 'UNKNOWN';
              final createdAt = order['createdAt'] != null
                  ? DateTime.parse(order['createdAt'])
                  : DateTime.now();

              // 도서명 요약: "A권 외 N권"
              String titleSummary = '도서 주문';
              if (items.isNotEmpty) {
                final firstItem = items[0];
                final firstTitle = firstItem['bookTitle'] ?? '트래블북';
                if (items.length > 1) {
                  titleSummary = '$firstTitle 외 ${items.length - 1}권';
                } else {
                  titleSummary = firstTitle;
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    final orderUid = order['orderUid'];
                    if (orderUid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailsPage(orderUid: orderUid.toString()),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateFormatter.format(createdAt),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            _buildStatusChip(orderStatus),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          titleSummary,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '주문번호: ${order['orderUid']?.toString() ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('에러 발생: $err')),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status.toUpperCase()) {
      case 'ORDERED':
      case '10':
      case '20':
        color = Colors.blue;
        text = '주문 완료';
        break;
      case 'PRODUCTION':
      case '30':
        color = Colors.orange;
        text = '제작 중';
        break;
      case 'SHIPPING':
      case '40':
        color = Colors.green;
        text = '배송 중';
        break;
      case 'COMPLETED':
      case '50':
        color = Colors.grey;
        text = '배송 완료';
        break;
      case 'CANCELLED':
      case '90':
        color = Colors.red;
        text = '주문 취소';
        break;
      default:
        color = Colors.indigo;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
