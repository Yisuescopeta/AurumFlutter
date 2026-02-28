import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/cart_item.dart';

const _cartStorageKey = 'aurum_cart_v1';

class CartState {
  CartState({
    required this.items,
    this.couponCode,
    this.discountCents = 0,
    this.isLoading = false,
  });

  final List<CartItem> items;
  final String? couponCode;
  final int discountCents;
  final bool isLoading;

  int get subtotalCents =>
      items.fold<int>(0, (sum, item) => sum + (item.unitPriceCents * item.quantity));

  int get totalCents {
    final value = subtotalCents - discountCents;
    return value < 0 ? 0 : value;
  }

  int get count => items.fold<int>(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    String? couponCode,
    int? discountCents,
    bool? isLoading,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      discountCents: clearCoupon ? 0 : (discountCents ?? this.discountCents),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(CartState(items: [])) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .whereType<Map>()
          .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(items: items);
    } catch (_) {}
  }

  Future<void> _persist(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cartStorageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<bool> addItem(CartItem item, {int? maxStock}) async {
    if (maxStock != null && maxStock <= 0) {
      return false;
    }

    final index = state.items.indexWhere((x) => x.id == item.id);
    final updated = [...state.items];

    if (index >= 0) {
      final existing = updated[index];
      var nextQuantity = existing.quantity + item.quantity;
      if (maxStock != null && nextQuantity > maxStock) {
        if (existing.quantity >= maxStock) return false;
        nextQuantity = maxStock;
      }
      updated[index] = existing.copyWith(quantity: nextQuantity);
    } else {
      var nextQuantity = item.quantity;
      if (maxStock != null && nextQuantity > maxStock) {
        nextQuantity = maxStock;
      }
      updated.add(item.copyWith(quantity: nextQuantity));
    }

    state = state.copyWith(items: updated, clearCoupon: true);
    await _persist(updated);
    return true;
  }

  Future<void> removeItem(String itemId) async {
    final updated = state.items.where((e) => e.id != itemId).toList();
    state = state.copyWith(items: updated, clearCoupon: true);
    await _persist(updated);
  }

  Future<bool> setQuantity(String itemId, int quantity, {int? maxStock}) async {
    if (quantity < 1) {
      await removeItem(itemId);
      return true;
    }

    if (maxStock != null) {
      if (maxStock <= 0) {
        await removeItem(itemId);
        return true;
      }
      if (quantity > maxStock) {
        quantity = maxStock;
      }
    }

    var changed = false;
    final updated = state.items.map((e) {
      if (e.id != itemId) return e;
      changed = changed || e.quantity != quantity;
      return e.copyWith(quantity: quantity);
    }).toList();

    if (!changed) return false;

    state = state.copyWith(items: updated, clearCoupon: true);
    await _persist(updated);
    return true;
  }

  Future<void> clear() async {
    state = CartState(items: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartStorageKey);
  }

  void applyCoupon({required String code, required int discountCents}) {
    state = state.copyWith(couponCode: code, discountCents: discountCents);
  }

  void clearCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
      return CartController();
    });
