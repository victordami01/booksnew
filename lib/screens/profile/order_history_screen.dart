import 'package:flutter/material.dart';
import 'package:bookstore/services/order_manager.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      isLoading = true;
    });
    try {
      final fetchedOrders = await OrderManager.getOrders();
      setState(() {
        orders = fetchedOrders;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching orders: $e')));
    }
  }

  // Mock tracking statuses based on order status
  List<Map<String, dynamic>> _getTrackingSteps(String status) {
    final steps = [
      {'status': 'Order Placed', 'completed': true},
      {'status': 'Shipped', 'completed': false},
      {'status': 'Out for Delivery', 'completed': false},
      {'status': 'Delivered', 'completed': false},
    ];

    if (status == 'Pending') {
      steps[0]['completed'] = true;
    } else if (status == 'Shipped') {
      steps[0]['completed'] = true;
      steps[1]['completed'] = true;
    } else if (status == 'Out for Delivery') {
      steps[0]['completed'] = true;
      steps[1]['completed'] = true;
      steps[2]['completed'] = true;
    } else if (status == 'Delivered') {
      steps[0]['completed'] = true;
      steps[1]['completed'] = true;
      steps[2]['completed'] = true;
      steps[3]['completed'] = true;
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
              ? const Center(
                child: Text(
                  'No orders yet.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderId = order['orderId'] as String;
                  final totalPrice = order['totalPrice'] as double;
                  final itemCount = order['itemCount'] as int;
                  final date =
                      order['createdAt'] != null
                          ? (order['createdAt'] as Timestamp).toDate()
                          : DateTime.parse(order['date'] as String);
                  final items = order['items'] as List<dynamic>;
                  final shippingAddress =
                      order['shippingAddress'] as Map<String, dynamic>;
                  final paymentMethod =
                      order['paymentMethod'] as Map<String, dynamic>;
                  final status = order['status'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: const Icon(
                        Icons.receipt,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        'Order #$orderId',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date: ${DateFormat('MMMM d, yyyy').format(date)}',
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Status: $status',
                                style: TextStyle(
                                  color:
                                      status == 'Pending'
                                          ? Colors.orange
                                          : status == 'Shipped'
                                          ? Colors.blue
                                          : status == 'Out for Delivery'
                                          ? Colors.purple
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Items
                              Text(
                                'Items ($itemCount):',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...items.map((book) {
                                final title = book['title'] ?? 'Unknown Title';
                                final author =
                                    book['author'] ?? 'Unknown Author';
                                final price = book['price'] as double;
                                final coverId = book['cover_i']?.toString();
                                final imageUrl =
                                    coverId != null && coverId.isNotEmpty
                                        ? "https://covers.openlibrary.org/b/id/$coverId-M.jpg"
                                        : "https://via.placeholder.com/150";
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Image.network(
                                        imageUrl,
                                        width: 40,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.book,
                                                  size: 40,
                                                ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'by $author',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '\$${price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 16),

                              // Shipping Address
                              Text(
                                'Shipping Address:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                [
                                      shippingAddress['addressLine1'] ?? 'N/A',
                                      if (shippingAddress['addressLine2'] !=
                                              null &&
                                          shippingAddress['addressLine2']
                                              .isNotEmpty)
                                        shippingAddress['addressLine2'],
                                      '${shippingAddress['city'] ?? 'N/A'}, ${shippingAddress['state'] ?? 'N/A'} ${shippingAddress['postalCode'] ?? 'N/A'}',
                                      shippingAddress['country'] ?? 'N/A',
                                    ]
                                    .where(
                                      (line) => line != null && line.isNotEmpty,
                                    )
                                    .join('\n'),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),

                              // Payment Method
                              Text(
                                'Payment Method:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.credit_card,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    paymentMethod['cardNumber'] != null
                                        ? 'Card ending in ${paymentMethod['cardNumber']}'
                                        : 'No payment method available',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Delivery Tracking
                              Text(
                                'Delivery Tracking:',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children:
                                    _getTrackingSteps(
                                      status,
                                    ).asMap().entries.map((entry) {
                                      final stepIndex = entry.key;
                                      final step = entry.value;
                                      final isCompleted =
                                          step['completed'] as bool;
                                      return Row(
                                        children: [
                                          Column(
                                            children: [
                                              Icon(
                                                isCompleted
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color:
                                                    isCompleted
                                                        ? Colors.green
                                                        : Colors.grey,
                                                size: 24,
                                              ),
                                              if (stepIndex <
                                                  _getTrackingSteps(
                                                        status,
                                                      ).length -
                                                      1)
                                                Container(
                                                  height: 30,
                                                  width: 2,
                                                  color:
                                                      isCompleted
                                                          ? Colors.green
                                                          : Colors.grey,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            step['status'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  isCompleted
                                                      ? Colors.black
                                                      : Colors.grey,
                                              fontWeight:
                                                  isCompleted
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
