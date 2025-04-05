import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:bookstore/services/cart_manager.dart';
import 'package:bookstore/services/wishlist_manager.dart';
import 'package:bookstore/screens/shop/shopping_cart_screen.dart';
import 'package:bookstore/services/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class BookDetailScreen extends StatefulWidget {
  final dynamic book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _showFullDescription = false;
  double _userRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  String? _userId;
  String? _username;

  @override
  void initState() {
    super.initState();
    // Assign mock price if not already set
    if (widget.book['price'] == null) {
      widget.book['price'] = generateMockPrice();
    }
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();

    // Get current user info
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _fetchUsername(user.uid);
    }
  }

  Future<void> _fetchUsername(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      setState(() {
        _username = userDoc.data()?['username'] ?? 'Anonymous';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _addToCart(dynamic book) {
    CartManager.addToCart(book);
    setState(() {}); // Update badge
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${book["title"]} added to cart!')));
  }

  Future<void> _submitReview(String bookId) async {
    if (_userId == null || _username == null) {
      Get.snackbar(
        'Error',
        'You must be logged in to submit a review.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_userRating == 0.0) {
      Get.snackbar(
        'Error',
        'Please provide a rating.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // Add review to Firestore
      final reviewRef =
          FirebaseFirestore.instance
              .collection('books')
              .doc(bookId)
              .collection('reviews')
              .doc();
      await reviewRef.set({
        'userId': _userId,
        'username': _username,
        'rating': _userRating,
        'reviewText': _reviewController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update book's average rating and rating count
      final bookRef = FirebaseFirestore.instance
          .collection('books')
          .doc(bookId);
      final reviewsSnapshot = await bookRef.collection('reviews').get();
      final totalRatings = reviewsSnapshot.docs.length;
      final totalRatingSum = reviewsSnapshot.docs.fold<double>(
        0.0,
        (sum, doc) => sum + (doc['rating'] as num).toDouble(),
      );
      final averageRating = totalRatingSum / totalRatings;

      await bookRef.update({
        'averageRating': averageRating,
        'ratingCount': totalRatings,
      });

      // Clear the form
      setState(() {
        _userRating = 0.0;
        _reviewController.clear();
      });

      Get.snackbar(
        'Success',
        'Review submitted successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error submitting review: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _toggleLike(
    String bookId,
    String reviewId,
    List<dynamic> currentLikes,
  ) async {
    if (_userId == null) {
      Get.snackbar(
        'Error',
        'You must be logged in to like a review.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final reviewRef = FirebaseFirestore.instance
        .collection('books')
        .doc(bookId)
        .collection('reviews')
        .doc(reviewId);

    try {
      if (currentLikes.contains(_userId)) {
        // Unlike the review
        await reviewRef.update({
          'likes': FieldValue.arrayRemove([_userId]),
        });
      } else {
        // Like the review
        await reviewRef.update({
          'likes': FieldValue.arrayUnion([_userId]),
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error liking review: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.book["title"] ?? "Unknown Title";
    final String author =
        (widget.book["author_name"] != null &&
                widget.book["author_name"].isNotEmpty)
            ? widget.book["author_name"][0]
            : widget.book["author"] ?? "Unknown Author";
    final String coverId =
        widget.book["cover_i"]?.toString() ??
        widget.book["cover_id"]?.toString() ??
        "";
    final String imageUrl =
        coverId.isNotEmpty
            ? "https://covers.openlibrary.org/b/id/$coverId-L.jpg"
            : "https://via.placeholder.com/300x400";
    final String key = widget.book["key"] ?? widget.book["id"] ?? "";
    final String bookId = key.split('/').last; // Sanitize the book ID
    final bool isFavorited = WishlistManager.isInWishlist(widget.book);
    final double price = widget.book['price'] as double;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 450.0,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            leading: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    Share.share(
                      'Check out "$title" by $author on Open Library: https://openlibrary.org$key',
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'book-cover-$key',
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 120),
                        );
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'by $author',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.grey[800],
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<DocumentSnapshot>(
                                    stream:
                                        FirebaseFirestore.instance
                                            .collection('books')
                                            .doc(bookId)
                                            .snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Row(
                                          children: [
                                            Row(
                                              children: List.generate(5, (
                                                index,
                                              ) {
                                                return Icon(
                                                  Icons.star_border,
                                                  color: Colors.amber.shade700,
                                                  size: 22,
                                                );
                                              }),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '0.0 (0)',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      final data =
                                          snapshot.data!.data()
                                              as Map<String, dynamic>?;
                                      final averageRating =
                                          data?['averageRating']?.toDouble() ??
                                          0.0;
                                      final ratingCount =
                                          data?['ratingCount'] ?? 0;
                                      return Row(
                                        children: [
                                          Row(
                                            children: List.generate(5, (index) {
                                              return Icon(
                                                index < averageRating.floor()
                                                    ? Icons.star
                                                    : (index < averageRating
                                                        ? Icons.star_half
                                                        : Icons.star_border),
                                                color: Colors.amber.shade700,
                                                size: 22,
                                              );
                                            }),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${averageRating.toStringAsFixed(1)} ($ratingCount)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                widget.book['category'] ?? 'Fiction',
                                style: TextStyle(
                                  color: Colors.deepPurple[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        FutureBuilder(
                          future: fetchBookDetails(key),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final pages = snapshot.data?['pages'] ?? 'N/A';
                            final year = snapshot.data?['year'] ?? 'N/A';
                            final language =
                                snapshot.data?['language'] ?? 'N/A';
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem('Pages', pages, Icons.book),
                                _buildStatItem(
                                  'Year',
                                  year,
                                  Icons.calendar_today,
                                ),
                                _buildStatItem(
                                  'Language',
                                  language,
                                  Icons.language,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About this book',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple[900],
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FutureBuilder(
                                future: fetchBookDetails(key),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.deepPurple,
                                            ),
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Text(
                                      'No description available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                        fontSize: 16,
                                      ),
                                    );
                                  }
                                  final description =
                                      snapshot.data?['description'] ??
                                      'No description available';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedCrossFade(
                                        firstChild: SizedBox(
                                          height: 100,
                                          child: Text(
                                            description,
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                              height: 1.7,
                                              fontSize: 16,
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        secondChild: Text(
                                          description,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            height: 1.7,
                                            fontSize: 16,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        crossFadeState:
                                            _showFullDescription
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                      ),
                                      if (description.length > 100)
                                        const SizedBox(height: 12),
                                      if (description.length > 100)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _showFullDescription =
                                                  !_showFullDescription;
                                            });
                                          },
                                          child: Text(
                                            _showFullDescription
                                                ? 'Show Less'
                                                : 'Show More',
                                            style: TextStyle(
                                              color: Colors.deepPurple[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Add Review Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate and Review',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple[900],
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return IconButton(
                                    icon: Icon(
                                      index < _userRating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber.shade700,
                                      size: 30,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _userRating = (index + 1).toDouble();
                                      });
                                    },
                                  );
                                }),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _reviewController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Write your review',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _submitReview(bookId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Submit Review',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Reviews Section
                        Text(
                          'Reviews',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple[900],
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('books')
                                  .doc(bookId)
                                  .collection('reviews')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No reviews yet.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }
                            final reviews = snapshot.data!.docs;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reviews.length,
                              itemBuilder: (context, index) {
                                final review =
                                    reviews[index].data()
                                        as Map<String, dynamic>;
                                final reviewId = reviews[index].id;
                                final rating =
                                    (review['rating'] as num).toDouble();
                                final reviewText = review['reviewText'] ?? '';
                                final username =
                                    review['username'] ?? 'Anonymous';
                                final createdAt =
                                    (review['createdAt'] as Timestamp?)
                                        ?.toDate();
                                final likes = List<String>.from(
                                  review['likes'] ?? [],
                                );
                                final hasLiked = likes.contains(_userId);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Row(
                                              children: List.generate(5, (
                                                starIndex,
                                              ) {
                                                return Icon(
                                                  starIndex < rating
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber.shade700,
                                                  size: 18,
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          reviewText,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              createdAt != null
                                                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                                  : 'Unknown date',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    hasLiked
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color:
                                                        hasLiked
                                                            ? Colors.red
                                                            : Colors.grey,
                                                    size: 20,
                                                  ),
                                                  onPressed:
                                                      () => _toggleLike(
                                                        bookId,
                                                        reviewId,
                                                        likes,
                                                      ),
                                                ),
                                                Text(
                                                  '${likes.length}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (isFavorited) {
                                        WishlistManager.removeFromWishlist(
                                          widget.book,
                                        );
                                      } else {
                                        WishlistManager.addToWishlist(
                                          widget.book,
                                        );
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isFavorited
                                            ? Colors.deepPurple[700]
                                            : Colors.white,
                                    foregroundColor:
                                        isFavorited
                                            ? Colors.white
                                            : Colors.deepPurple,
                                    elevation: 6,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color:
                                            isFavorited
                                                ? Colors.deepPurple[700]!
                                                : Colors.deepPurple.withOpacity(
                                                  0.5,
                                                ),
                                        width: 2,
                                      ),
                                    ),
                                    shadowColor: Colors.deepPurple.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isFavorited
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Wishlist',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isFavorited
                                                  ? Colors.white
                                                  : Colors.deepPurple[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: ElevatedButton(
                                  onPressed: () => _addToCart(widget.book),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple[700],
                                    foregroundColor: Colors.white,
                                    elevation: 6,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 20,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    shadowColor: Colors.deepPurple.withOpacity(
                                      0.4,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.shopping_cart, size: 24),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Add to Cart',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartScreen()),
          );
        },
        backgroundColor: Colors.deepPurple,
        child: Stack(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            if (CartManager.itemCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${CartManager.itemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple.withOpacity(0.1),
          ),
          child: Icon(icon, color: Colors.deepPurple[700], size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> fetchBookDetails(String key) async {
    if (key.isEmpty) return {};
    try {
      final response = await http.get(
        Uri.parse('https://openlibrary.org$key.json'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String? description =
            data['description'] is String
                ? data['description']
                : data['description'] is Map
                ? data['description']['value']
                : 'No description available';
        return {
          'description': description,
          'pages': data['number_of_pages']?.toString() ?? 'N/A',
          'year': data['first_publish_date']?.substring(0, 4) ?? 'N/A',
          'language':
              data['languages']?.isNotEmpty ?? false
                  ? data['languages'][0]['key'].split('/').last
                  : 'N/A',
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
