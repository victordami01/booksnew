import 'package:bookstore/controllers/user_controller.dart';
import 'package:bookstore/screens/auth/login_screen.dart';
import 'package:bookstore/screens/profile/order_history_screen.dart';
import 'package:bookstore/screens/profile/wishlist_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bookstore/services/google_sign_in_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  late UserController userController;
  bool _isEmailVerified = false;
  bool _isLoadingVerify = false;
  List<Map<String, dynamic>> shippingAddresses = [];
  List<Map<String, dynamic>> paymentMethods = [];

  @override
  void initState() {
    super.initState();
    userController = Get.find<UserController>();
    _checkEmailVerificationStatus();
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
          });
          // Update UserController with username, email, and photoUrl from Firestore
          userController.setUserData(
            data?['username'] ?? 'User',
            data?['email'] ?? user.email ?? '',
            newPhotoUrl: data?['photoUrl'],
          );
        } else {
          // If the document doesn't exist, set default values
          userController.setUserData('User', user.email ?? '');
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to load user data. Please check your connection and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _checkEmailVerificationStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        setState(() {
          _isEmailVerified = user.emailVerified;
        });
        if (_isEmailVerified) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'emailVerified': true});
        }
      }
    } catch (e) {
      debugPrint('Error checking email verification status: $e');
    }
  }

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isLoadingVerify = true;
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        Get.snackbar(
          'Offline',
          'You are offline. Please connect to the internet to send a verification email.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        Get.snackbar(
          'Success',
          'Verification email sent. Please check your inbox.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send verification email: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoadingVerify = false;
      });
    }
  }

  Future<void> _verifyEmail() async {
    setState(() {
      _isLoadingVerify = true;
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        Get.snackbar(
          'Offline',
          'You are offline. Please connect to the internet to verify your email.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          setState(() {
            _isEmailVerified = true;
          });
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'emailVerified': true});
          Get.snackbar(
            'Success',
            'Email verified successfully!',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          Get.snackbar(
            'Not Verified',
            'Your email is not yet verified. Please check your inbox and click the verification link.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to verify email: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoadingVerify = false;
      });
    }
  }

  Future<void> _updateUserData({
    required String newEmail,
    required String newUsername,
    required Map<String, dynamic>? newShippingAddress,
    required Map<String, dynamic>? newPaymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        if (newEmail != user.email) {
          await user.updateEmail(newEmail);
          await user.sendEmailVerification();
          setState(() {
            _isEmailVerified = false;
          });
        }

        Map<String, dynamic> updatedData = {
          'username': newUsername,
          'email': newEmail,
          'emailVerified': newEmail == user.email ? user.emailVerified : false,
        };

        if (newShippingAddress != null) {
          shippingAddresses.add(newShippingAddress);
          updatedData['shippingAddresses'] = shippingAddresses;
        }

        if (newPaymentMethod != null) {
          paymentMethods.add(newPaymentMethod);
          updatedData['paymentMethods'] = paymentMethods;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updatedData);

        // Update the UserController
        userController.setUserData(newUsername, newEmail);

        setState(() {
          if (newShippingAddress != null) {
            shippingAddresses = List.from(shippingAddresses);
          }
          if (newPaymentMethod != null) {
            paymentMethods = List.from(paymentMethods);
          }
        });

        Get.snackbar(
          'Success',
          newEmail != user.email
              ? 'Profile updated. Please verify your new email.'
              : 'Profile updated successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to update profile: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      // Sign out from Google using the shared instance
      await GoogleSignInService.instance.signOut();
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      // Clear user data in UserController
      Get.find<UserController>().clear();
      // Navigate to the login screen
      Get.offAllNamed('/login');
      Get.snackbar(
        'Success',
        'Signed out successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showEditProfileDialog() {
    final emailController = TextEditingController(
      text: userController.email.value,
    );
    final usernameController = TextEditingController(
      text: userController.username.value,
    );
    // Shipping Address Fields
    final addressLine1Controller = TextEditingController();
    final addressLine2Controller = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final postalCodeController = TextEditingController();
    String? selectedCountry;
    // Payment Method Fields
    final cardNumberController = TextEditingController();
    final nameOnCardController = TextEditingController();
    final expiryDateController = TextEditingController();
    final cvvController = TextEditingController();

    // List of countries for dropdown
    final List<String> countries = [
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'Germany',
      'France',
      'India',
      'China',
      'Japan',
      'Brazil',
      // Add more countries as needed
    ];

    // Validate expiry date (MM/YY format, not in the past)
    bool _validateExpiryDate(String value) {
      if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) {
        return false;
      }
      final parts = value.split('/');
      final month = int.parse(parts[0]);
      final year = int.parse('20${parts[1]}');
      final now = DateTime.now();
      final expiry = DateTime(year, month);
      return expiry.isAfter(now);
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9, // Wider dialog
              constraints: const BoxConstraints(
                maxWidth: 500,
              ), // Max width for larger screens
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Shipping Address Section
                    const Text(
                      'Add Shipping Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressLine1Controller,
                      decoration: InputDecoration(
                        labelText: 'Address Line 1',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressLine2Controller,
                      decoration: InputDecoration(
                        labelText: 'Address Line 2 (Optional)',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityController,
                            decoration: InputDecoration(
                              labelText: 'City',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: stateController,
                            decoration: InputDecoration(
                              labelText: 'State',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: postalCodeController,
                            decoration: InputDecoration(
                              labelText: 'Postal Code',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCountry,
                            decoration: InputDecoration(
                              labelText: 'Country',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            items:
                                countries.map((String country) {
                                  return DropdownMenuItem<String>(
                                    value: country,
                                    child: Text(country),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              selectedCountry = newValue;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Payment Method Section
                    const Text(
                      'Add Payment Method',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameOnCardController,
                      decoration: InputDecoration(
                        labelText: 'Name on Card',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expiryDateController,
                            decoration: InputDecoration(
                              labelText: 'Expiration Date',
                              hintText: 'MM/YY',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _ExpiryDateInputFormatter(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: cvvController,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                onPressed: () {
                  // Validate payment method
                  Map<String, dynamic>? newPaymentMethod;
                  if (cardNumberController.text.isNotEmpty &&
                      nameOnCardController.text.isNotEmpty &&
                      expiryDateController.text.isNotEmpty &&
                      cvvController.text.isNotEmpty) {
                    // Validate card number (16 digits)
                    final cardNumber = cardNumberController.text.replaceAll(
                      ' ',
                      '',
                    );
                    if (cardNumber.length != 16) {
                      Get.snackbar(
                        'Error',
                        'Card number must be 16 digits.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                      return;
                    }

                    // Validate expiry date
                    if (!_validateExpiryDate(expiryDateController.text)) {
                      Get.snackbar(
                        'Error',
                        'Invalid or expired date. Use MM/YY format and ensure it\'s in the future.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                      return;
                    }

                    // Validate CVV (3 digits)
                    if (cvvController.text.length != 3) {
                      Get.snackbar(
                        'Error',
                        'CVV must be 3 digits.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                      return;
                    }

                    newPaymentMethod = {
                      'type': 'Credit Card',
                      'cardNumber': cardNumber.substring(cardNumber.length - 4),
                      'nameOnCard': nameOnCardController.text.trim(),
                      'expiryDate': expiryDateController.text,
                      'cvv':
                          cvvController.text
                              .trim(), // Note: In production, don't store CVV
                    };
                  }

                  // Prepare new shipping address
                  Map<String, dynamic>? newShippingAddress;
                  if (addressLine1Controller.text.isNotEmpty &&
                      cityController.text.isNotEmpty &&
                      stateController.text.isNotEmpty &&
                      postalCodeController.text.isNotEmpty &&
                      selectedCountry != null) {
                    newShippingAddress = {
                      'addressLine1': addressLine1Controller.text.trim(),
                      'addressLine2': addressLine2Controller.text.trim(),
                      'city': cityController.text.trim(),
                      'state': stateController.text.trim(),
                      'postalCode': postalCodeController.text.trim(),
                      'country': selectedCountry,
                    };
                  }

                  _updateUserData(
                    newEmail: emailController.text.trim(),
                    newUsername: usernameController.text.trim(),
                    newShippingAddress: newShippingAddress,
                    newPaymentMethod: newPaymentMethod,
                  );
                  Navigator.pop(context);
                },
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5F1),
        title: const Text('Profile'),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9F5F1),
      body: Obx(
        () =>
            userController.username.value.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7857FC), Color(0xFF5A3FDB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Obx(
                                  () =>
                                      userController.photoUrl.value.isNotEmpty
                                          ? CircleAvatar(
                                            radius: 40,
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                  userController.photoUrl.value,
                                                ),
                                          )
                                          : CircleAvatar(
                                            radius: 40,
                                            backgroundColor: Colors.white,
                                            child: Text(
                                              userController
                                                      .username
                                                      .value
                                                      .isNotEmpty
                                                  ? userController
                                                      .username
                                                      .value[0]
                                                      .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                fontSize: 30,
                                                color: Color(0xFF7857FC),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userController.username.value.isNotEmpty
                                            ? userController.username.value
                                            : 'User',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        userController.email.value.isNotEmpty
                                            ? userController.email.value
                                            : 'No email set',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showEditProfileDialog,
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Color(0xFF7857FC),
                              ),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF7857FC),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF7857FC),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email Verification Section
                      if (!_isEmailVerified) ...[
                        Text(
                          'Email Verification',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verify your email to secure your account.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _isLoadingVerify
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _sendVerificationEmail,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF7857FC,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Send Verification Email',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _verifyEmail,
                                        child: const Text(
                                          'I’ve Verified',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF7857FC),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Shipping Addresses Section
                      Text(
                        'Shipping Addresses',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            shippingAddresses.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No shipping addresses added yet.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: shippingAddresses.length,
                                  itemBuilder: (context, index) {
                                    final address = shippingAddresses[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          address['addressLine1'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          [
                                                if (address['addressLine2'] !=
                                                        null &&
                                                    address['addressLine2']
                                                        .isNotEmpty)
                                                  address['addressLine2'],
                                                '${address['city']}, ${address['state']} ${address['postalCode']}',
                                                address['country'],
                                              ]
                                              .where((line) => line.isNotEmpty)
                                              .join('\n'),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            try {
                                              setState(() {
                                                shippingAddresses.removeAt(
                                                  index,
                                                );
                                              });
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser!
                                                        .uid,
                                                  )
                                                  .update({
                                                    'shippingAddresses':
                                                        shippingAddresses,
                                                  });
                                              Get.snackbar(
                                                'Success',
                                                'Shipping address removed.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor: Colors.green,
                                                colorText: Colors.white,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                'Failed to remove address: $e',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                              await _loadUserData();
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Payment Methods Section
                      Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            paymentMethods.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No payment methods added yet.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: paymentMethods.length,
                                  itemBuilder: (context, index) {
                                    final payment = paymentMethods[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                          'Card ending in ${payment['cardNumber']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Expires: ${payment['expiryDate']}\nCardholder: ${payment['nameOnCard']}',
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            try {
                                              setState(() {
                                                paymentMethods.removeAt(index);
                                              });
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(
                                                    FirebaseAuth
                                                        .instance
                                                        .currentUser!
                                                        .uid,
                                                  )
                                                  .update({
                                                    'paymentMethods':
                                                        paymentMethods,
                                                  });
                                              Get.snackbar(
                                                'Success',
                                                'Payment method removed.',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor: Colors.green,
                                                colorText: Colors.white,
                                              );
                                            } catch (e) {
                                              Get.snackbar(
                                                'Error',
                                                'Failed to remove payment method: $e',
                                                snackPosition:
                                                    SnackPosition.BOTTOM,
                                                backgroundColor: Colors.red,
                                                colorText: Colors.white,
                                              );
                                              await _loadUserData();
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Wishlist Button
                      Text(
                        'Wishlist',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Get.to(() => const WishlistScreen());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7857FC),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Wishlist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Order History Button
                      ElevatedButton(
                        onPressed: () {
                          Get.to(() => const OrderHistoryScreen());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7857FC),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Order History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Settings Section
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Dark Mode'),
                              value: _isDarkMode,
                              onChanged: (value) {
                                setState(() {
                                  _isDarkMode = value;
                                });
                              },
                              activeColor: const Color(0xFF7857FC),
                            ),
                            SwitchListTile(
                              title: const Text('Notifications'),
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                              },
                              activeColor: const Color(0xFF7857FC),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout Button
                      ElevatedButton(
                        onPressed: _signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

// Formatter for card number (adds spaces every 4 digits)
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(' ', '');
    StringBuffer newText = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        newText.write(' ');
      }
      newText.write(text[i]);
    }
    return TextEditingValue(
      text: newText.toString(),
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// Formatter for expiry date (adds / after MM)
class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      text = text.substring(0, 4);
    }
    StringBuffer newText = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        newText.write('/');
      }
      newText.write(text[i]);
    }
    return TextEditingValue(
      text: newText.toString(),
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
