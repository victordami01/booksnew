import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/controllers/user_controller.dart';
import 'package:bookstore/screens/auth/login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Updated to 3 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      Get.find<UserController>().clear();
      await FirebaseAuth.instance.signOut();
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not sign out: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5F1),
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF7857FC)),
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Books'),
            Tab(text: 'Orders'), // New Orders tab
          ],
          labelColor: const Color(0xFF7857FC),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFF7857FC),
        ),
      ),
      backgroundColor: const Color(0xFFF9F5F1),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UserManagementTab(),
          BookManagementTab(),
          OrderManagementTab(), // New Orders tab content
        ],
      ),
    );
  }
}

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      if (!mounted) return;
      setState(() {
        _users = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load users: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmDelete = await _showConfirmationDialog(
      'Delete User',
      'Are you sure you want to delete this user? This action cannot be undone.',
    );

    if (!confirmDelete) return;

    try {
      setState(() => _isLoading = true);

      // Delete user from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete user from Firebase Authentication (requires re-authentication or admin SDK)
      // Since we're in a client app, we'll notify the admin to delete the user from Firebase Console
      Get.snackbar(
        'Info',
        'User deleted from Firestore. To fully delete the user, remove them from Firebase Authentication via the Firebase Console.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );

      await _loadUsers();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error deleting user: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAdminStatus(String userId, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isAdmin': !isAdmin,
      });
      await _loadUsers();
      Get.snackbar(
        'Success',
        'Admin status updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error updating admin status: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _editUsername(String userId, String currentUsername) async {
    final newUsernameController = TextEditingController(text: currentUsername);

    final confirmEdit = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Username'),
            content: TextField(
              controller: newUsernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter new username',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmEdit != true) return;

    try {
      setState(() => _isLoading = true);

      await _firestore.collection('users').doc(userId).update({
        'username': newUsernameController.text.trim(),
      });
      await _loadUsers();
      Get.snackbar(
        'Success',
        'Username updated',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error updating username: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF7857FC)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final usernameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter email',
                  ),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter password',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter username',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final userCredential = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                    await _firestore
                        .collection('users')
                        .doc(userCredential.user!.uid)
                        .set({
                          'email': emailController.text.trim(),
                          'username': usernameController.text.trim(),
                          'isAdmin': false,
                          'emailVerified': false,
                        });

                    await _loadUsers();
                    Get.snackbar(
                      'Success',
                      'User added successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                    Navigator.of(context).pop();
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Error adding user: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add User',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7857FC),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isAdmin = user['isAdmin'] ?? false;
        final username = user['username'] ?? 'No username set';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              user['email'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Username: $username',
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  isAdmin ? 'Admin' : 'Regular User',
                  style: TextStyle(
                    color: isAdmin ? Colors.green : Colors.black54,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF7857FC)),
                  onPressed: () => _editUsername(user.id, username),
                ),
                IconButton(
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color: isAdmin ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => _toggleAdminStatus(user.id, isAdmin),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookManagementTab extends StatefulWidget {
  const BookManagementTab({super.key});

  @override
  _BookManagementTabState createState() => _BookManagementTabState();
}

class _BookManagementTabState extends State<BookManagementTab> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  List<QueryDocumentSnapshot> _books = [];
  bool _isLoadingBooks = true;
  String? _errorMessage;

  final List<String> categories = [
    "Best Selling Books",
    "Trending Books",
    "New Arrivals",
    "Editor's Picks",
    "Horror",
    "Comics",
    "History",
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('books').get();
      if (!mounted) return;
      setState(() {
        _books = snapshot.docs;
        _isLoadingBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load books: ${e.toString()}';
        _isLoadingBooks = false;
      });
    }
  }

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://openlibrary.org/search.json?q=${Uri.encodeQueryComponent(query)}&fields=key,title,author_name,cover_i,first_publish_year&limit=20',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['docs'] ?? [];
        });
      } else {
        Get.snackbar(
          'Error',
          'Failed to search books',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error searching books: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _deleteBook(String bookId) async {
    // Sanitize the bookId if it contains slashes
    String sanitizedBookId = bookId.split('/').last;

    final confirmDelete = await _showConfirmationDialog(
      'Delete Book',
      'Are you sure you want to delete this book? This action cannot be undone.',
    );

    if (!confirmDelete) return;

    try {
      setState(() => _isLoadingBooks = true);
      await FirebaseFirestore.instance
          .collection('books')
          .doc(sanitizedBookId)
          .delete();
      await _loadBooks();
      Get.snackbar(
        'Success',
        'Book deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error deleting book: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingBooks = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF7857FC)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showAddBookDialog(Map<String, dynamic> book) {
    final TextEditingController priceController = TextEditingController();
    bool availability = true;
    String? selectedCategory;

    // Sanitize the document ID by taking the last segment of the key
    String bookId = book['key'].toString().split('/').last; // e.g., "OL82563W"

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Book: ${book['title']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'e.g., 19.99',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Available'),
                    value: availability,
                    onChanged: (value) {
                      setState(() {
                        availability = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final price = double.tryParse(priceController.text);
                  if (price == null || price <= 0) {
                    Get.snackbar(
                      'Error',
                      'Please enter a valid price',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  if (selectedCategory == null) {
                    Get.snackbar(
                      'Error',
                      'Please select a category',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('books')
                        .doc(bookId)
                        .set({
                          'id': bookId, // Store the sanitized ID
                          'title': book['title'],
                          'author':
                              book['author_name']?.isNotEmpty == true
                                  ? book['author_name'][0]
                                  : 'Unknown Author',
                          'price': price,
                          'availability': availability,
                          'cover_id': book['cover_i']?.toString(),
                          'category': selectedCategory,
                          'first_publish_year': book['first_publish_year'] ?? 0,
                          'mockPopularity':
                              (book.hashCode %
                                  1000), // Mock popularity for sorting
                        });
                    Navigator.pop(context);
                    await _loadBooks();
                    Get.snackbar(
                      'Success',
                      'Book added successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Error adding book: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showEditBookDialog(QueryDocumentSnapshot bookDoc) {
    final book = bookDoc.data() as Map<String, dynamic>;
    final TextEditingController priceController = TextEditingController(
      text: book['price'].toString(),
    );
    bool availability = book['availability'] ?? true;
    String? selectedCategory = book['category'];

    // Sanitize the bookId if it contains slashes
    String bookId = book['id'].toString().split('/').last;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Book: ${book['title']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      hintText: 'e.g., 19.99',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Available'),
                    value: availability,
                    onChanged: (value) {
                      setState(() {
                        availability = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final price = double.tryParse(priceController.text);
                  if (price == null || price <= 0) {
                    Get.snackbar(
                      'Error',
                      'Please enter a valid price',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  if (selectedCategory == null) {
                    Get.snackbar(
                      'Error',
                      'Please select a category',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('books')
                        .doc(bookId)
                        .update({
                          'price': price,
                          'availability': availability,
                          'category': selectedCategory,
                        });
                    Navigator.pop(context);
                    await _loadBooks();
                    Get.snackbar(
                      'Success',
                      'Book updated successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Error updating book: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Books Section
          const Text(
            'Add New Book',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search for a book',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon:
                    _isSearching
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.search, color: Color(0xFF7857FC)),
                onPressed: () => _searchBooks(_searchController.text),
              ),
            ),
            onSubmitted: _searchBooks,
          ),
          const SizedBox(height: 16),
          if (_searchResults.isNotEmpty) ...[
            const Text(
              'Search Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final book = _searchResults[index];
                final bookTitle = book['title'] ?? 'Unknown Title';
                final author =
                    book['author_name']?.isNotEmpty == true
                        ? book['author_name'][0]
                        : 'Unknown Author';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(bookTitle),
                    subtitle: Text(author),
                    trailing: ElevatedButton(
                      onPressed: () => _showAddBookDialog(book),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          // Current Books Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Books',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF7857FC)),
                onPressed: _loadBooks,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingBooks
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadBooks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
              : _books.isEmpty
              ? const Center(
                child: Text(
                  'No books found.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  final bookDoc = _books[index];
                  final book = bookDoc.data() as Map<String, dynamic>;
                  final bookTitle = book['title'] ?? 'Unknown Title';
                  final author = book['author'] ?? 'Unknown Author';
                  final price = book['price']?.toString() ?? 'N/A';
                  final category = book['category'] ?? 'No category';
                  final isAvailable = book['availability'] ?? true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        bookTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Author: $author'),
                          Text('Price: \$${price}'),
                          Text('Category: $category'),
                          Text(
                            isAvailable ? 'Available' : 'Not Available',
                            style: TextStyle(
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Color(0xFF7857FC),
                            ),
                            onPressed: () => _showEditBookDialog(bookDoc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBook(book['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class OrderManagementTab extends StatefulWidget {
  const OrderManagementTab({super.key});

  @override
  _OrderManagementTabState createState() => _OrderManagementTabState();
}

class _OrderManagementTabState extends State<OrderManagementTab> {
  List<QueryDocumentSnapshot> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> orderStatuses = [
    'Pending',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .get();
      if (!mounted) return;
      setState(() {
        _orders = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load orders: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmDelete = await _showConfirmationDialog(
      'Delete Order',
      'Are you sure you want to delete this order? This action cannot be undone.',
    );

    if (!confirmDelete) return;

    try {
      setState(() => _isLoading = true);
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .delete();
      await _loadOrders();
      Get.snackbar(
        'Success',
        'Order deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error deleting order: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF7857FC)),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showOrderDetailsDialog(QueryDocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final books = List<Map<String, dynamic>>.from(order['books'] ?? []);
    final totalAmount = order['totalAmount']?.toString() ?? 'N/A';
    final userEmail = order['userEmail'] ?? 'Unknown';
    final createdAt =
        (order['createdAt'] as Timestamp?)?.toDate().toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Order Details: ${orderDoc.id}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('User Email: $userEmail'),
                  Text('Order Date: $createdAt'),
                  Text('Total Amount: \$${totalAmount}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Books:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...books.map((book) {
                    final title = book['title'] ?? 'Unknown Title';
                    final price = book['price']?.toString() ?? 'N/A';
                    final quantity = book['quantity']?.toString() ?? '1';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('$title - \$${price} x $quantity'),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
            ],
          ),
    );
  }

  void _showUpdateStatusDialog(QueryDocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    String? selectedStatus = order['status'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Update Order Status: ${orderDoc.id}'),
            content: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items:
                  orderStatuses.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedStatus = newValue;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7857FC)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedStatus == null) {
                    Get.snackbar(
                      'Error',
                      'Please select a status',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderDoc.id)
                        .update({'status': selectedStatus});
                    Navigator.pop(context);
                    await _loadOrders();
                    Get.snackbar(
                      'Success',
                      'Order status updated successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Error updating order status: ${e.toString()}',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7857FC),
                ),
                child: const Text(
                  'Update',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF7857FC)),
                onPressed: _loadOrders,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadOrders,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
              : _orders.isEmpty
              ? const Center(
                child: Text(
                  'No orders found.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final orderDoc = _orders[index];
                  final order = orderDoc.data() as Map<String, dynamic>;
                  final userEmail = order['userEmail'] ?? 'Unknown';
                  final totalAmount = order['totalAmount']?.toString() ?? 'N/A';
                  final status = order['status'] ?? 'Pending';
                  final createdAt =
                      (order['createdAt'] as Timestamp?)?.toDate().toString() ??
                      'Unknown';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        'Order ID: ${orderDoc.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('User: $userEmail'),
                          Text('Total: \$${totalAmount}'),
                          Text('Status: $status'),
                          Text('Date: $createdAt'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.info,
                              color: Color(0xFF7857FC),
                            ),
                            onPressed: () => _showOrderDetailsDialog(orderDoc),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Color(0xFF7857FC),
                            ),
                            onPressed: () => _showUpdateStatusDialog(orderDoc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteOrder(orderDoc.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
