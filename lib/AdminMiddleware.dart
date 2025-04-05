import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/controllers/user_controller.dart';

class AdminMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('AdminMiddleware: User not authenticated');
      return const RouteSettings(name: '/login');
    }

    final UserController userController = Get.find<UserController>();
    if (!userController.isAdmin.value) {
      debugPrint('AdminMiddleware: Access denied');
      return const RouteSettings(name: '/main');
    }

    return null;
  }
}