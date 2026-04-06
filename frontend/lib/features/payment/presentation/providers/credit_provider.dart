import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';

class UserCreditNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() async {
    return await _fetchBalance();
  }

  Future<int> _fetchBalance() async {
    try {
      final res = await apiService.getCredits();
      // Sweetbook API 응답 구조: {"data": {"balance": 10000}}
      if (res['success'] == true && res['data'] != null) {
        return (res['data']['balance'] ?? 0) as int;
      }
      return 0;
    } catch (e) {
      print('Error fetching balance: $e');
      return 0;
    }
  }

  Future<void> refreshBalance() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchBalance());
  }

  Future<Map<String, dynamic>?> chargeSandboxCredits(int amount, String memo, WidgetRef ref) async {
    state = const AsyncLoading();
    final res = await apiService.sandboxCharge(amount, memo);
    await refreshBalance();
    // 거래 내역도 새로고침
    await ref.read(creditTransactionsProvider.notifier).refresh();
    return res['data'];
  }

  Future<Map<String, dynamic>?> deductSandboxCredits(int amount, String memo, WidgetRef ref) async {
    state = const AsyncLoading();
    final res = await apiService.sandboxDeduct(amount, memo);
    await refreshBalance();
    // 거래 내역도 새로고침
    await ref.read(creditTransactionsProvider.notifier).refresh();
    return res['data'];
  }
}

final creditProvider = AsyncNotifierProvider<UserCreditNotifier, int>(() {
  return UserCreditNotifier();
});

class CreditTransactionsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() async {
    return _fetchTransactions();
  }

  Future<List<dynamic>> _fetchTransactions({int limit = 20, int offset = 0}) async {
    try {
      final res = await apiService.getCreditTransactions(limit: limit, offset: offset);
      if (res['success'] == true && res['data'] != null && res['data']['transactions'] != null) {
        return res['data']['transactions'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchTransactions());
  }
}

final creditTransactionsProvider =
    AsyncNotifierProvider<CreditTransactionsNotifier, List<dynamic>>(() {
  return CreditTransactionsNotifier();
});
