import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserController extends GetxController {
  // Reactive variables to store user data
  final RxBool isAdmin = false.obs;
  final RxString username = 'User'.obs;
  final RxString email = ''.obs;
  final RxString photoUrl =
      ''.obs; // Add photoUrl for Google Sign-In profile picture

  @override
  void onInit() {
    super.onInit();
    loadUserData(); // Load user data when the controller is initialized
  }

  // Method to load user data from Firestore
  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          isAdmin.value = userData['isAdmin'] ?? false;
          username.value = userData['username'] ?? 'User';
          email.value = userData['email'] ?? user.email ?? '';
          photoUrl.value =
              userData['photoUrl'] ?? ''; // Load photoUrl from Firestore
        } else {
          isAdmin.value = false;
          username.value = 'User';
          email.value = user.email ?? '';
          photoUrl.value =
              user.photoURL ?? ''; // Fallback to Firebase user photoURL
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to load user data: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        // Fallback values in case of error
        isAdmin.value = false;
        username.value = 'User';
        email.value = user.email ?? '';
        photoUrl.value =
            user.photoURL ?? ''; // Fallback to Firebase user photoURL
      }
    }
  }

  // Method to update user data
  void setUserData(String newUsername, String newEmail, {String? newPhotoUrl}) {
    username.value = newUsername;
    email.value = newEmail;
    if (newPhotoUrl != null) {
      photoUrl.value = newPhotoUrl; // Update photoUrl if provided
    }
  }

  // Method to clear user data on sign-out
  void clear() {
    isAdmin.value = false;
    username.value = 'User';
    email.value = '';
    photoUrl.value = ''; // Clear photoUrl on sign-out
  }
}
