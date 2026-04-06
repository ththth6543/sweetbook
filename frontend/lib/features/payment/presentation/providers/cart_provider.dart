import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => {};

  void add(int bookId) {
    if (state.containsKey(bookId)) {
      state = {...state, bookId: state[bookId]! + 1};
    } else {
      state = {...state, bookId: 1};
    }
  }

  void remove(int bookId) {
    final newState = {...state};
    newState.remove(bookId);
    state = newState;
  }

  void updateQuantity(int bookId, int qty) {
    if (qty <= 0) {
      remove(bookId);
    } else {
      state = {...state, bookId: qty};
    }
  }

  void clear() {
    state = {};
  }
}

final cartProvider = NotifierProvider<CartNotifier, Map<int, int>>(() {
  return CartNotifier();
});
