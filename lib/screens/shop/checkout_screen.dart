// screens/shop/checkout_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bookstore/services/cart_manager.dart';
import 'package:bookstore/services/order_manager.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalPrice;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutScreen({
    super.key,
    required this.totalPrice,
    required this.cartItems,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> shippingAddresses = [];
  List<Map<String, dynamic>> paymentMethods = [];
  Map<String, dynamic>? selectedShippingAddress;
  Map<String, dynamic>? selectedPaymentMethod;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            shippingAddresses = List<Map<String, dynamic>>.from(
              data?['shippingAddresses'] ?? [],
            );
            paymentMethods = List<Map<String, dynamic>>.from(
              data?['paymentMethods'] ?? [],
            );
            // Pre-select the first shipping address and payment method if available
            if (shippingAddresses.isNotEmpty) {
              selectedShippingAddress = shippingAddresses[0];
            }
            if (paymentMethods.isNotEmpty) {
              selectedPaymentMethod = paymentMethods[0];
            }
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
      }
    }
  }

  void _completePurchase() async {
    if (selectedShippingAddress == null || selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a shipping address and payment method'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      await OrderManager.addOrder(
        orderId: orderId,
        totalPrice: widget.totalPrice,
        itemCount: CartManager.itemCount,
        date: DateTime.now(),
        items: widget.cartItems,
        shippingAddress: selectedShippingAddress!,
        paymentMethod: selectedPaymentMethod!,
      );

      CartManager.clearCart();
      Navigator.popUntil(
        context,
        (route) => route.isFirst,
      ); // Back to MainScreen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase completed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error completing purchase: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[900],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items in Cart:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...widget.cartItems.map((item) {
                    final title = item['title'] ?? 'Unknown Title';
                    final price = item['price'] as double;
                    final quantity = item['quantity'] as int;
                    final subtotal = price * quantity;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$title (x$quantity)',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Items:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${CartManager.itemCount}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${widget.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Shipping Address Selection
            Text(
              'Shipping Address',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[900],
              ),
            ),
            const SizedBox(height: 16),
            shippingAddresses.isEmpty
                ? const Text(
                  'No shipping addresses available. Please add one in your profile.',
                  style: TextStyle(color: Colors.red),
                )
                : DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedShippingAddress,
                  decoration: InputDecoration(
                    labelText: 'Select Shipping Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items:
                      shippingAddresses.map((address) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: address,
                          child: Text(
                            '${address['addressLine1']}, ${address['city']}, ${address['country']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedShippingAddress = value;
                    });
                  },
                ),
            const SizedBox(height: 24),

            // Payment Method Selection
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[900],
              ),
            ),
            const SizedBox(height: 16),
            paymentMethods.isEmpty
                ? const Text(
                  'No payment methods available. Please add one in your profile.',
                  style: TextStyle(color: Colors.red),
                )
                : Column(
                  children:
                      paymentMethods.asMap().entries.map((entry) {
                        final index = entry.key;
                        final payment = entry.value;
                        return ListTile(
                          title: Text(
                            'Card ending in ${payment['cardNumber']}',
                          ),
                          leading: Radio<Map<String, dynamic>>(
                            value: payment,
                            groupValue: selectedPaymentMethod,
                            onChanged: (value) {
                              setState(() {
                                selectedPaymentMethod = value;
                              });
                            },
                          ),
                          trailing: const Icon(
                            Icons.credit_card,
                            color: Colors.grey,
                            size: 20,
                          ),
                        );
                      }).toList(),
                ),
            const SizedBox(height: 24),

            // Confirm Button
            ElevatedButton(
              onPressed: _isLoading ? null : _completePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'Confirm Purchase',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
