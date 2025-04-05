import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/components/navbar.dart'; // MainScreen with navbar
import 'package:bookstore/AdminDashboard.dart'; // Redirect to AdminDashboard for admins
import 'package:bookstore/screens/auth/login_screen.dart'; // Redirect to LoginScreen on sign out

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  late Timer _timer;
  bool _isLoading = true;
  bool _isEmailSent = false;
  bool _isSending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
    _sendVerificationEmail();
  }

  Future<bool> _isAdmin(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists && doc.data()?['isAdmin'] == true;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  Future<void> signout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Get.offAll(() => const LoginScreen());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not sign out',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSending || _resendCooldown > 0) return;
    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Get.offAll(() => const LoginScreen());
        return;
      }
      await user.sendEmailVerification();
      setState(() {
        _isEmailSent = true;
        _resendCooldown = 30; // 30-second cooldown
      });
      Get.snackbar(
        'Success',
        'Verification email sent. Please check your inbox (and spam/junk folder).',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Start cooldown timer
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCooldown > 0) {
          setState(() => _resendCooldown--);
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not send verification email: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        timer.cancel();
        Get.offAll(() => const LoginScreen());
        return;
      }

      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser?.emailVerified ?? false) {
        timer.cancel();
        // Check admin status before redirecting
        bool isAdmin = await _isAdmin(updatedUser!.uid);
        if (isAdmin) {
          Get.offAll(() => AdminDashboard());
        } else {
          Get.offAll(() => const MainScreen()); // Navigate to MainScreen
        }
      }
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5F1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: signout,
        ),
        actions: [
          TextButton(
            onPressed: signout,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF7857FC)),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F5F1),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Verify Your Email",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  'Checking verification status...',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ] else ...[
                Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: _isEmailSent ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 20),
                Text(
                  _isEmailSent
                      ? 'Verification email sent. Check your inbox.'
                      : 'Sending verification email...',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Please verify your email to continue.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_isSending || _resendCooldown > 0)
                      ? null
                      : _sendVerificationEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7857FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _resendCooldown > 0
                              ? 'Resend Email ($_resendCooldown s)'
                              : 'Resend Email',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: signout,
        backgroundColor: const Color(0xFF7857FC),
        tooltip: 'Return to Sign In',
        child: const Icon(Icons.logout, color: Colors.white),
      ),
    );
  }
}