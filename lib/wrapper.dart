import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/controllers/user_controller.dart';
import 'package:bookstore/components/navbar.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  Future<bool> _isAdmin(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists && (doc.data()?['isAdmin'] ?? false);
  }

  @override
  Widget build(BuildContext context) {
    // Access the already-initialized UserController
    final UserController userController = Get.find<UserController>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          userController.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed('/login');
          });
          return const SizedBox();
        }

        // Load user data into UserController
        userController.loadUserData();

        return FutureBuilder<bool>(
          future: _isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (adminSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${adminSnapshot.error}')),
              );
            }
            if (adminSnapshot.data == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Get.offAllNamed('/admin');
              });
              return const SizedBox();
            }

            // Navigate to MainScreen regardless of email verification status
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Get.offAllNamed('/main');
            });
            return const SizedBox();
          },
        );
      },
    );
  }
}
