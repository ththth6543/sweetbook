import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/core/network/api_service.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderUid;

  const OrderDetailsPage({super.key, required this.orderUid});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late Future<Map<String, dynamic>> _detailsFuture;
  final _formatter = NumberFormat('#,###');
  final _dateFormatter = DateFormat('yyyy.MM.dd HH:mm');

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
  }

  Future<Map<String, dynamic>> _fetchDetails() async {
    final res = await apiService.getOrderDetails(widget.orderUid);
    if (res['success'] == true && res['data'] != null) {
      return res['data'];
    }
    throw Exception(res['message'] ?? '주문 상세 정보를 불러오지 못했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('주문 상세', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류 발생: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _detailsFuture = _fetchDetails();
                    }),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final items = data['items'] as List? ?? [];
          final orderedAt = DateTime.parse(data['orderedAt'] ?? data['createdAt'] ?? DateTime.now().toIso8601String());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 주문 요약 정보
                _buildSectionCard(
                  child: Column(
                    children: [
                      _buildInfoRow('주문 번호', data['orderUid'] ?? '-', isBold: true),
                      const Divider(height: 24),
                      _buildInfoRow('주문 일시', _dateFormatter.format(orderedAt)),
                      const SizedBox(height: 12),
                      _buildInfoRow('주문 상태', data['orderStatusDisplay'] ?? '-', 
                        valueColor: Colors.indigo, isValueBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionTitle('주문 도서'),
                // 2. 도서 항목 리스트
                ...items.map((item) => _buildItemCard(item)),

                const SizedBox(height: 20),
                _buildSectionTitle('배송 정보'),
                // 3. 배송지 정보
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('수령인', data['recipientName'] ?? '-'),
                      const SizedBox(height: 12),
                      _buildInfoRow('연락처', data['recipientPhone'] ?? '-'),
                      const SizedBox(height: 12),
                      _buildInfoRow('우편번호', data['postalCode'] ?? '-'),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('주소', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${data['address1'] ?? '-'} ${data['address2'] ?? ''}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionTitle('결제 금액'),
                // 4. 결제 금액 정보
                _buildSectionCard(
                  child: Column(
                    children: [
                      _buildInfoRow('공급가액(책값)', '${_formatter.format(data['subtotal'] ?? 0)}원'),
                      const SizedBox(height: 12),
                      _buildInfoRow('부가세(10%)', '+ ${_formatter.format(data['vat'] ?? 0)}원'),
                      const SizedBox(height: 12),
                      _buildInfoRow('배송비', '+ ${_formatter.format(data['shippingFee'] ?? 3000)}원'),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('최종 결제 금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '${_formatter.format(data['totalAmount'] ?? 0)}원',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                      if (data['paymentMethod'] != null) ...[
                        const SizedBox(height: 16),
                        _buildInfoRow('결제 수단', data['paymentMethod'] == 'CREDIT' ? '충전금(크레딧)' : data['paymentMethod']),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value, {
    bool isBold = false, 
    Color? valueColor, 
    bool isValueBold = false
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: (isBold || isValueBold) ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // 책 썸네일 (모킹)
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.book, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['bookTitle'] ?? '트래블북',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['quantity'] ?? 1}권', style: TextStyle(color: Colors.grey[600])),
                    Text(
                      '${_formatter.format(item['itemAmount'] ?? 0)}원',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
