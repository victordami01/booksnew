// services/wishlist_manager.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistManager {
  static final List<dynamic> _wishlist = [];
  static const String _collectionPath = 'users'; // Store wishlist under the user's document

  // Getter for the wishlist
  static List<dynamic> get wishlist => _wishlist;

  // Initialize the wishlist by fetching from Firestore
  static Future<void> initWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collectionPath)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        _wishlist.clear();
        _wishlist.addAll(List<dynamic>.from(data?['wishlist'] ?? []));
      } else {
        // If the user document doesn't exist, create it with an empty wishlist
        await FirebaseFirestore.instance
            .collection(_collectionPath)
            .doc(user.uid)
            .set({
          'wishlist': [],
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error initializing wishlist: $e');
    }
  }

  // Add a book to the wishlist and sync with Firestore
  static Future<void> addToWishlist(dynamic book) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Check if the book is already in the wishlist using a unique identifier
    final bookKey = book['key']?.toString();
    if (bookKey == null) {
      throw Exception('Book does not have a key');
    }

    if (_wishlist.any((item) => item['key'] == bookKey)) {
      return; // Book already in wishlist, avoid duplicates
    }

    _wishlist.add(book);

    try {
      await FirebaseFirestore.instance
          .collection(_collectionPath)
          .doc(user.uid)
          .update({
        'wishlist': _wishlist,
      });
    } catch (e) {
      print('Error adding to wishlist: $e');
      _wishlist.remove(book);
      rethrow;
    }
  }

  // Remove a book from the wishlist and sync with Firestore
  static Future<void> removeFromWishlist(dynamic book) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final bookKey = book['key']?.toString();
    if (bookKey == null) {
      throw Exception('Book does not have a key');
    }

    _wishlist.removeWhere((item) => item['key'] == bookKey);

    try {
      await FirebaseFirestore.instance
          .collection(_collectionPath)
          .doc(user.uid)
          .update({
        'wishlist': _wishlist,
      });
    } catch (e) {
      print('Error removing from wishlist: $e');
      await initWishlist(); // Revert local changes if Firestore update fails
      rethrow;
    }
  }

  // Check if a book is in the wishlist
  static bool isInWishlist(dynamic book) {
    final bookKey = book['key']?.toString();
    if (bookKey == null) return false;
    return _wishlist.any((item) => item['key'] == bookKey);
  }

  // Clear the wishlist
  static Future<void> clearWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    _wishlist.clear();

    try {
      await FirebaseFirestore.instance
          .collection(_collectionPath)
          .doc(user.uid)
          .update({
        'wishlist': [],
      });
    } catch (e) {
      print('Error clearing wishlist: $e');
      await initWishlist(); // Revert local changes if Firestore update fails
      rethrow;
    }
  }
}