import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_service.dart';

class OrderHistoryNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() async {
    return await _fetchOrders();
  }

  Future<List<dynamic>> _fetchOrders() async {
    try {
      final res = await apiService.getOrders();
      // Sweetbook API response structure: {"success": true, "data": {"orders": [...]}}
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (data is Map && data['orders'] is List) {
          return data['orders'];
        } else if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching order history: $e');
      return [];
    }
  }

  Future<void> refreshOrders() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchOrders());
  }
}

final orderHistoryProvider = AsyncNotifierProvider<OrderHistoryNotifier, List<dynamic>>(() {
  return OrderHistoryNotifier();
});
