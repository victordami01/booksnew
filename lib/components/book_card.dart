import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/screens/home/book_details_screen.dart'; // Import the detail screen
import 'package:bookstore/services/wishlist_manager.dart'; // Import WishlistManager

class BookCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String author;
  final double price;
  final double rating;
  final dynamic book;
  final VoidCallback? onBuy; // Callback for adding to cart

  const BookCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.author,
    required this.price,
    this.rating = 4.0,
    required this.book,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
        );
      },
      child: Container(
        width: 120, // Fixed width
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stack to overlay the heart icon on the cover image
            Stack(
              children: [
                // Book Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imageUrl,
                    width: 120,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        "assets/images/placeholder.png",
                        width: 120,
                        height: 160,
                      );
                    },
                  ),
                ),
                // Heart Icon for Wishlist
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        if (WishlistManager.isInWishlist(book)) {
                          await WishlistManager.removeFromWishlist(book);
                          Get.snackbar(
                            'Removed',
                            '$title removed from wishlist',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        } else {
                          await WishlistManager.addToWishlist(book);
                          Get.snackbar(
                            'Added',
                            '$title added to wishlist',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        }
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to update wishlist: $e',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    child: Icon(
                      WishlistManager.isInWishlist(book)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Rating Row
            SizedBox(
              height: 14,
              child: Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 12,
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),

            // Book Title
            SizedBox(
              height: 12,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Author Name
            Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),

            // Price and Buy Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "\$${price.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
