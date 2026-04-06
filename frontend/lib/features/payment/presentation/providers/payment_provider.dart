import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';

final paymentBalanceProvider = AsyncNotifierProvider<PaymentBalanceNotifier, Map<String, dynamic>>(() {
  return PaymentBalanceNotifier();
});

class PaymentBalanceNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    return _fetchCredits();
  }

  Future<Map<String, dynamic>> _fetchCredits() async {
    final response = await apiService.getCredits();
    // Sweetbook API response structure: { "success": true, "message": "Success", "data": { "balance": ..., "currency": ..., "env": ... } }
    if (response['success'] == true) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception(response['message'] ?? 'Failed to fetch balance');
  }

  Future<void> refreshBalance() async {
    state = const AsyncValue.loading();
    try {
      final data = await _fetchCredits();
      state = AsyncValue.data(data);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
