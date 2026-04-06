import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:frontend/features/book/domain/models/book.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/payment/presentation/providers/cart_provider.dart';
import 'package:frontend/features/payment/presentation/providers/credit_provider.dart';

class PublishPage extends ConsumerStatefulWidget {
  final List<TravelBook> books;
  final Map<int, int> quantities;

  const PublishPage({super.key, required this.books, required this.quantities});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  int _currentStep = 0;
  bool _isLoading = false;
  Map<String, dynamic>? _estimate;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();

  final _formatter = NumberFormat('#,###');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _postalController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    return widget.books
        .map((b) => {'book_id': b.id, 'quantity': widget.quantities[b.id] ?? 1})
        .toList();
  }

  Future<void> _fetchEstimate() async {
    setState(() => _isLoading = true);
    try {
      final items = _buildItemsPayload();
      final res = await apiService.getBulkEstimate(items);
      setState(() {
        _estimate = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorDialog('견적 조회 실패', e);
      }
    }
  }

  Future<void> _placeOrder() async {
    final creditState = ref.read(creditProvider);
    final currentBalance = creditState.value ?? 0;
    final totalPrice = _estimate?['data']?['totalPrice'] ?? 0;

    if (currentBalance < totalPrice) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('잔액 부족'),
          content: Text(
            '보유하신 크레딧이 부족합니다.\n\n현재 잔액: ${_formatter.format(currentBalance)}원\n결제 금액: ${_formatter.format(totalPrice)}원',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    if (_nameController.text.isEmpty || _address1Controller.text.isEmpty) {
      _showSimpleDialog('정보 미입력', '배송 정보를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final shipping = {
        'recipientName': _nameController.text,
        'recipientPhone': _phoneController.text,
        'postalCode': _postalController.text,
        'address1': _address1Controller.text,
        'address2': _address2Controller.text,
      };

      final items = _buildItemsPayload();
      final res = await apiService.createBulkOrder(items, shipping);

      if (mounted) {
        setState(() => _isLoading = false);
        // 주문 성공 시 장바구니 비우기 및 크레딧 갱신
        ref.read(cartProvider.notifier).clear();
        ref.read(creditProvider.notifier).refreshBalance();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('주문 완료'),
            content: Text(
              '주문이 성공적으로 접수되었습니다.\n주문번호: ${res['data']['orderUid']}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog
                  Navigator.pop(context); // PublishPage
                },
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorDialog('주문 생성 실패', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('도서 주문하기')),
        body: const Center(child: Text('주문할 도서가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('도서 주문하기')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            _fetchEstimate();
            setState(() => _currentStep++);
          } else if (_currentStep == 1) {
            setState(() => _currentStep++);
          } else {
            _placeOrder();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 2 ? '최종 주문하기' : '다음 단계'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('이전'),
                    ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('도서 정보 확인'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '주문 목록',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: widget.books.map((book) {
                      final qty = widget.quantities[book.id] ?? 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.book,
                              size: 20,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (book.description != null &&
                                      book.description!.isNotEmpty)
                                    Text(
                                      book.description!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '$qty권',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '총 ${widget.books.length}종 / ${widget.quantities.values.fold(0, (int sum, val) => sum + val)}권 주문',
                ),
                const SizedBox(height: 16),
                const AlertInfo(text: '결제 전 제작 견적 조회를 위해 다음 버튼을 눌러주세요.'),
              ],
            ),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('견적 및 비용 확인'),
            content: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_estimate != null) ...[
                        const Text(
                          '제작 견적 내역',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              ...widget.books.map((book) {
                                final qty = widget.quantities[book.id] ?? 1;
                                // 스윗북 API에서 개별 항목 가격이 제공되지 않을 것에 대비해 로컬 book.price 활용
                                final itemTotal = book.price * qty;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _buildPriceRow(
                                    '- ${book.title} ($qty권)',
                                    itemTotal,
                                    isSubItem: true,
                                  ),
                                );
                              }).toList(),
                              const Divider(height: 16),
                              _buildPriceRow(
                                '도서 제작비 합계',
                                (_estimate!['data']['totalPrice'] ?? 0) -
                                    (_estimate!['data']['shippingFee'] ?? 3000),
                              ),
                              const SizedBox(height: 8),
                              _buildPriceRow(
                                '부가세 (10%)',
                                (((_estimate!['data']['totalPrice'] ?? 0) -
                                        (_estimate!['data']['shippingFee'] ?? 3000)) *
                                        0.1)
                                    .round(),
                                isAdd: true,
                                isVat: true,
                              ),
                              const SizedBox(height: 8),
                              _buildPriceRow(
                                '배송비',
                                _estimate!['data']['shippingFee'] ?? 3000,
                                isAdd: true,
                              ),
                              const Divider(height: 24),
                              _buildPriceRow(
                                '총 결제 금액',
                                _estimate!['data']['totalPrice'] ?? 3000,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, child) {
                            final creditVal =
                                ref.watch(creditProvider).value ?? 0;
                            final total =
                                _estimate?['data']?['totalPrice'] ?? 0;
                            final isShort = creditVal < total;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isShort
                                    ? Colors.red[50]
                                    : Colors.indigo[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isShort
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline,
                                    color: isShort ? Colors.red : Colors.indigo,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isShort
                                          ? '잔액이 ${_formatter.format(total - creditVal)}원 부족합니다.'
                                          : '결제 후 잔액: ${_formatter.format(creditVal - total)}원',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isShort
                                            ? Colors.red
                                            : Colors.indigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const AlertInfo(
                          text:
                              '최종 결제 금액을 확인하신 후, 배송 정보를 입력하기 위해 다음 버튼을 눌러주세요.',
                        ),
                      ] else
                        const Text('견적 정보를 불러오지 못했습니다.'),
                    ],
                  ),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('배송 정보 입력'),
            content: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '수령인 이름'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: '연락처'),
                ),
                TextField(
                  controller: _postalController,
                  decoration: const InputDecoration(labelText: '우편번호'),
                ),
                TextField(
                  controller: _address1Controller,
                  decoration: const InputDecoration(labelText: '주소'),
                ),
                TextField(
                  controller: _address2Controller,
                  decoration: const InputDecoration(labelText: '상세주소'),
                ),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    dynamic price, {
    bool isAdd = false,
    bool isTotal = false,
    bool isSubItem = false,
    bool isVat = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : (isSubItem ? 13 : 14),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isSubItem ? Colors.grey[700] : Colors.black,
          ),
        ),
        Text(
          '${isAdd && !isVat ? "+" : ""}${_formatter.format(price)}원',
          style: TextStyle(
            fontSize: isTotal ? 18 : (isSubItem ? 13 : 14),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal 
                ? Colors.blue 
                : (isAdd && !isVat ? Colors.red : (isSubItem ? Colors.grey[700] : Colors.black)),
          ),
        ),
      ],
    );
  }

  void _showSimpleDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showErrorDialog(String title, dynamic e) {
    String errorMsg = '$e';
    if (e is DioException && e.response != null && e.response!.data != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        errorMsg = '${data['detail']}';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(errorMsg),
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

class AlertInfo extends StatelessWidget {
  final String text;
  const AlertInfo({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
