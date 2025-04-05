import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/controllers/user_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bookstore/services/google_sign_in_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _saveUserData(
    String userId, {
    String? username,
    String? email,
  }) async {
    try {
      debugPrint('Attempting to save user data for UID: $userId');
      final userEmail = email ?? _emailController.text.trim();
      final userUsername = username ?? _usernameController.text.trim();
      if (userUsername.isEmpty || userEmail.isEmpty) {
        throw Exception('Username or email cannot be empty');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
            'username': userUsername,
            'email': userEmail,
            'isAdmin': false,
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': false,
          })
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Firestore write timed out after 10 seconds');
            },
          );
      debugPrint('User data saved successfully for UID: $userId');
    } catch (e) {
      debugPrint('Error saving user data: $e');
      throw Exception('Failed to save user data: $e');
    }
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        debugPrint(
          'Device is offline; Firestore will queue the write operation',
        );
        Get.snackbar(
          'Offline',
          'You are offline. Your data will sync when you reconnect to the internet.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      debugPrint(
        'Attempting to create user with email: ${_emailController.text.trim()}',
      );
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      debugPrint(
        'User created successfully with UID: ${userCredential.user!.uid}',
      );

      await _saveUserData(userCredential.user!.uid);

      final userController = Get.find<UserController>();
      userController.username.value = _usernameController.text.trim();
      userController.email.value = _emailController.text.trim();
      userController.isAdmin.value = false;
      debugPrint('UserController updated with new user data');

      Get.offAllNamed('/main');

      Get.snackbar(
        'Success!',
        'Account created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Signup error: $e');
      Get.snackbar(
        'Error',
        'Failed to sign up: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

Future<void> _signUpWithGoogle() async {
  setState(() {
    _isLoading = true;
  });

  try {
    bool isOnline = await _checkConnectivity();
    if (!isOnline) {
      debugPrint(
        'Device is offline; cannot sign in with Google',
      );
      Get.snackbar(
        'Offline',
        'You are offline. Please connect to the internet to sign up with Google.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Use the shared GoogleSignIn instance
    final GoogleSignInAccount? googleUser = await GoogleSignInService.instance.signIn();
    if (googleUser == null) {
      // User canceled the sign-in
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    // Check if the user already exists in Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    if (!userDoc.exists) {
      // New user, store their data in Firestore
      await _saveUserData(
        userCredential.user!.uid,
        username: userCredential.user!.displayName ?? 'User_${userCredential.user!.uid}',
        email: userCredential.user!.email,
      );

      // Update Firestore with additional Google data (e.g., photoUrl)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
            'photoUrl': userCredential.user!.photoURL,
            'emailVerified': true, // Google accounts are typically verified
          });
    }

    // Update UserController
    final userController = Get.find<UserController>();
    userController.setUserData(
      userCredential.user!.displayName ?? 'User_${userCredential.user!.uid}',
      userCredential.user!.email ?? '',
      newPhotoUrl: userCredential.user!.photoURL ?? '',
    );

    Get.offAllNamed('/main');

    Get.snackbar(
      'Success!',
      'Signed up with Google successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  } catch (e) {
    debugPrint('Google Sign-Up error: $e');
    Get.snackbar(
      'Error',
      'Failed to sign up with Google: $e',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
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
        backgroundColor: const Color(0xFFF9F5F1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: const Text('Sign Up', style: TextStyle(color: Colors.black87)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9F5F1),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const Center(
              child: Text(
                "Join Our Community of\nBook Lovers",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    "Username",
                    _usernameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  _buildTextField(
                    "Email",
                    _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  _buildPasswordField(
                    "Password",
                    _passwordController,
                    _isPasswordVisible,
                    () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  _buildPasswordField(
                    "Confirm Password",
                    _confirmPasswordController,
                    _isConfirmPasswordVisible,
                    () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSignUpButton(),
                  const SizedBox(height: 16),
                  // Add "or Sign up via" divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black26)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "or Sign up via",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black26)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Add Google Sign-In Button
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _signUpWithGoogle,
                      icon: Image.asset('assets/google_logo.png', height: 24),
                      label: const Text(
                        'Sign up with Google',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.black26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Get.offNamed('/login');
                      },
                      child: const Text(
                        "Already have an account? Sign In",
                        style: TextStyle(color: Color(0xFF7857FC)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: "Enter your $label",
            hintStyle: const TextStyle(color: Colors.black45),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Colors.red),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool isVisible,
    VoidCallback toggleVisibility, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          decoration: InputDecoration(
            hintText: "Enter your $label",
            hintStyle: const TextStyle(color: Colors.black45),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.black45,
              ),
              onPressed: toggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Colors.red),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7857FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 52),
        ),
        onPressed: signup,
        child: const Text(
          "Sign Up",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
