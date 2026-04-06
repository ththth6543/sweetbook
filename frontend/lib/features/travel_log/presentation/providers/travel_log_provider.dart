import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/travel_log/domain/models/travel_log.dart';
import 'package:frontend/core/network/api_service.dart';

final travelLogListProvider = AsyncNotifierProvider<TravelLogListNotifier, List<TravelLog>>(() {
  return TravelLogListNotifier();
});

class TravelLogListNotifier extends AsyncNotifier<List<TravelLog>> {
  @override
  FutureOr<List<TravelLog>> build() async {
    return await apiService.getLogs();
  }

  Future<void> addLog(TravelLog log) async {
    state = const AsyncValue.loading();
    try {
      await apiService.createLog(log);
      ref.invalidateSelf();
      await future;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> removeLog(int id) async {
    state = const AsyncValue.loading();
    try {
      await apiService.deleteLog(id);
      ref.invalidateSelf();
      await future;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
