import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/local_storage_service.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final LocalStorageService _localStorage;
  static const String _cartKey = 'cart_items';

  CartNotifier(this._localStorage) : super([]) {
    _loadCartFromStorage();
  }

  /// Load cart items from local storage
  Future<void> _loadCartFromStorage() async {
    try {
      final cartData = _localStorage.getString(_cartKey);
      if (cartData != null && cartData.isNotEmpty) {
        final List<dynamic> cartJson = jsonDecode(cartData);
        final cartItems = cartJson
            .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
            .toList();
        state = cartItems;
        debugPrint('[CartNotifier] Loaded ${cartItems.length} items from storage');
      }
    } catch (e) {
      debugPrint('[CartNotifier] Error loading cart from storage: $e');
      state = [];
    }
  }

  /// Save cart items to local storage
  void _saveCartToStorage() {
    try {
      final cartJson = state.map((item) => item.toJson()).toList();
      final cartData = jsonEncode(cartJson);
      _localStorage.saveString(_cartKey, cartData);
      debugPrint('[CartNotifier] Saved ${state.length} items to storage');
    } catch (e) {
      debugPrint('[CartNotifier] Error saving cart to storage: $e');
    }
  }

  /// Add item to cart
  void addItem(MenuItem menuItem) {
    final existingIndex = state.indexWhere(
      (cartItem) => cartItem.menuItem.id == menuItem.id,
    );

    if (existingIndex >= 0) {
      // Item already in cart, increase quantity
      final updatedList = [...state];
      updatedList[existingIndex] = updatedList[existingIndex].copyWith(
        quantity: updatedList[existingIndex].quantity + 1,
      );
      state = updatedList;
    } else {
      // Add new item to cart
      state = [...state, CartItem(menuItem: menuItem, quantity: 1)];
    }

    _saveCartToStorage();
  }

  /// Remove item from cart
  void removeItem(String menuItemId) {
    state = state.where((item) => item.menuItem.id != menuItemId).toList();
    _saveCartToStorage();
  }

  /// Update item quantity
  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
      return;
    }

    final updatedList = state.map((item) {
      if (item.menuItem.id == menuItemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    state = updatedList;
    _saveCartToStorage();
  }

  /// Clear cart
  void clearCart() {
    state = [];
    _saveCartToStorage();
  }

  /// Get total items count
  int get totalItems {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Get total price
  double get totalPrice {
    return state.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Check if item is in cart
  bool isInCart(String menuItemId) {
    return state.any((item) => item.menuItem.id == menuItemId);
  }

  /// Get item quantity
  int getItemQuantity(String menuItemId) {
    final item = state.firstWhere(
      (item) => item.menuItem.id == menuItemId,
      orElse: () => CartItem(
        menuItem: MenuItem(
          id: '',
          name: '',
          imageUrl: '',
          calories: 0,
          price: 0,
          category: '',
          isVeg: true,
        ),
        quantity: 0,
      ),
    );
    return item.quantity;
  }
}

/// Provider for cart management
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  final localStorage = ref.watch(localStorageProvider).value;

  if (localStorage == null) {
    throw Exception('LocalStorage not initialized');
  }

  return CartNotifier(localStorage);
});

/// Provider for total items count
final cartTotalItemsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Provider for total price
final cartTotalPriceProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});
