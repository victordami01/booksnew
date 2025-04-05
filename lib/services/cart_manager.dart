// cart_manager.dart
class CartManager {
  // Store cart items as a list of maps with book details and quantity
  static final List<Map<String, dynamic>> _cart = [];

  static List<Map<String, dynamic>> get cart => _cart;

  static void addToCart(dynamic book) {
    // Ensure the book has a price
    if (book['price'] == null) {
      book['price'] = (10 + (book.hashCode % 40)).toDouble(); // Mock price if not set
    }

    // Check if the book is already in the cart
    final existingBookIndex = _cart.indexWhere((item) => item['book'] == book);
    if (existingBookIndex != -1) {
      // Book already exists, increment quantity
      _cart[existingBookIndex]['quantity'] += 1;
    } else {
      // Add new book with quantity 1
      _cart.add({
        'book': book,
        'quantity': 1,
      });
    }
  }

  static void incrementQuantity(dynamic book) {
    final existingBookIndex = _cart.indexWhere((item) => item['book'] == book);
    if (existingBookIndex != -1) {
      _cart[existingBookIndex]['quantity'] += 1;
    }
  }

  static void decrementQuantity(dynamic book) {
    final existingBookIndex = _cart.indexWhere((item) => item['book'] == book);
    if (existingBookIndex != -1) {
      if (_cart[existingBookIndex]['quantity'] > 1) {
        _cart[existingBookIndex]['quantity'] -= 1;
      } else {
        // If quantity is 1, remove the book entirely
        _cart.removeAt(existingBookIndex);
      }
    }
  }

  static void removeFromCart(dynamic book) {
    _cart.removeWhere((item) => item['book'] == book);
  }

  static void clearCart() {
    _cart.clear();
  }

  // Total number of items in the cart (sum of quantities)
  static int get itemCount =>
      _cart.fold(0, (sum, item) => sum + (item['quantity'] as int));

  // Convert cart items to a list of maps for Firestore, including quantity and book ID
  static List<Map<String, dynamic>> getCartItemsForOrder() {
    return _cart.map((item) {
      final book = item['book'];
      return {
        'id': book['id'] ?? book['key'], // Include the book ID
        'title': book['title'] ?? 'Unknown Title',
        'author': (book['author_name'] != null && book['author_name'].isNotEmpty)
            ? book['author_name'][0]
            : (book['authors'] != null && book['authors'].isNotEmpty)
                ? book['authors'][0]['name']
                : book['author'] ?? 'Unknown Author',
        'price': book['price'] as double,
        'cover_i': book['cover_i']?.toString() ?? book['cover_id']?.toString(),
        'quantity': item['quantity'] as int,
      };
    }).toList();
  }
}