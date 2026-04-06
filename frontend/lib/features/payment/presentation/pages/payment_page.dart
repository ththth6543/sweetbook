import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/payment/presentation/providers/payment_provider.dart';
import 'package:frontend/features/payment/presentation/providers/credit_provider.dart';
import 'package:frontend/features/payment/presentation/pages/order_history_page.dart';
import 'package:frontend/features/payment/presentation/pages/credit_history_page.dart';
import 'package:intl/intl.dart';

class PaymentPage extends ConsumerWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceState = ref.watch(paymentBalanceProvider);
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          '결제 및 잔액',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(paymentBalanceProvider.notifier).refreshBalance();
              ref.read(creditProvider.notifier).refreshBalance();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo[900]!,
              Colors.indigo[700]!,
              Colors.grey[50]!,
            ],
            stops: const [0.0, 0.4, 0.4],
          ),
        ),
        child: SafeArea(
          child: balanceState.when(
            data: (data) => _buildContent(context, ref, data, currencyFormat),
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '정보를 불러오지 못했습니다:\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(paymentBalanceProvider.notifier)
                          .refreshBalance();
                      ref.read(creditProvider.notifier).refreshBalance();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
    NumberFormat format,
  ) {
    final balance = data['balance'] ?? 0;
    final currency = data['currency'] ?? 'KRW';
    final env = data['env'] ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildBalanceCard(context, ref, balance, currency, env, format),
          const SizedBox(height: 40),
          const Text(
            '빠른 관리',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildActionGrid(context),
          const SizedBox(height: 32),
          _buildInfoSection(env),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    WidgetRef ref,
    num balance,
    String currency,
    String env,
    NumberFormat format,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '나의 충전금',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: env == 'live'
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  env.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            format.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildBalanceAction(
                  context,
                  ref,
                  icon: Icons.add_circle_outline,
                  label: '충전하기',
                  onTap: () =>
                      _showSandboxCreditDialog(context, ref, isCharge: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBalanceAction(
                  context,
                  ref,
                  icon: Icons.remove_circle_outline,
                  label: '차감 테스트',
                  onTap: () =>
                      _showSandboxCreditDialog(context, ref, isCharge: false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBalanceAction(
                  context,
                  ref,
                  icon: Icons.history,
                  label: '이용내역',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreditHistoryPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceAction(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildActionCard(
          icon: Icons.receipt_long,
          title: '주문 목록',
          color: Colors.blue[100]!,
          iconColor: Colors.blue[700]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
            );
          },
        ),
        _buildActionCard(
          icon: Icons.local_shipping_outlined,
          title: '배송 조회',
          color: Colors.orange[100]!,
          iconColor: Colors.orange[700]!,
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.settings_outlined,
          title: '결제 설정',
          color: Colors.purple[100]!,
          iconColor: Colors.purple[700]!,
          onTap: () {},
        ),
        _buildActionCard(
          icon: Icons.help_outline,
          title: '도움말',
          color: Colors.green[100]!,
          iconColor: Colors.green[700]!,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String env) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.indigo[700]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '알림',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  env == 'live'
                      ? '충전금은 실제 도서 주문 시 사용됩니다.'
                      : '샌드박스 환경에서는 가상의 충전금이 사용됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.indigo[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSandboxCreditDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isCharge,
  }) {
    final amountController = TextEditingController();
    final memoController = TextEditingController(
      text: isCharge ? '테스트 충전' : '테스트 차감',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isCharge ? '샌드박스 크레딧 충전' : '샌드박스 크레딧 차감'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: '금액 (원)',
                hintText: '숫자만 입력',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: memoController,
              decoration: const InputDecoration(labelText: '메모'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('올바른 금액을 입력해주세요.')),
                );
                return;
              }

              // 다이얼로그를 닫을 때는 dialogContext 사용
              Navigator.pop(dialogContext);

              try {
                Map<String, dynamic>? result;
                if (isCharge) {
                  result = await ref
                      .read(creditProvider.notifier)
                      .chargeSandboxCredits(amount, memoController.text, ref);
                } else {
                  result = await ref
                      .read(creditProvider.notifier)
                      .deductSandboxCredits(amount, memoController.text, ref);
                }

                // 성공 다이얼로그와 리프레시는 부모 페이지의 context 사용
                if (context.mounted) {
                  // 전체 잔액 정보(PaymentBalanceNotifier)도 새로고침
                  ref.read(paymentBalanceProvider.notifier).refreshBalance();

                  _showSuccessDialog(
                    context,
                    isCharge: isCharge,
                    amount: result?['amount'] ?? amount,
                    balanceAfter: result?['balanceAfter'] ?? 0,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
                }
              }
            },
            child: Text(isCharge ? '충전하기' : '차감하기'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(
    BuildContext context, {
    required bool isCharge,
    required dynamic amount,
    required dynamic balanceAfter,
  }) {
    final formatter = NumberFormat('#,###');
    final absAmount = amount is num ? amount.abs() : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCharge ? Icons.check_circle : Icons.remove_circle,
              color: isCharge ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(isCharge ? '충전 완료' : '차감 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isCharge ? "충전" : "차감"}된 금액',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              '${isCharge ? "+" : "-"}${formatter.format(absAmount)}원',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isCharge ? Colors.blue : Colors.redAccent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
