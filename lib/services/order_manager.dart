// services/order_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderManager {
  static Future<void> addOrder({
    required String orderId,
    required double totalPrice,
    required int itemCount,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    required Map<String, dynamic> paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .doc(orderId)
        .set({
          'orderId': orderId,
          'totalPrice': totalPrice,
          'itemCount': itemCount,
          'date': date.toIso8601String(),
          'items': items,
          'shippingAddress': shippingAddress,
          'paymentMethod': paymentMethod,
          'status': 'Pending',
          'createdAt': FieldValue.serverTimestamp(), // Add server timestamp
        });
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  static Future<void> clearOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    final snapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
