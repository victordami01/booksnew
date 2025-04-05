import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bookstore/controllers/user_controller.dart';
import 'package:bookstore/screens/auth/login_screen.dart';
import 'package:bookstore/screens/auth/signup_screen.dart';
import 'package:bookstore/utils/view.dart'; // OnboardingScreen
import 'package:bookstore/screens/search/search_screen.dart';
import 'package:bookstore/screens/shop/shopping_cart_screen.dart';
import 'package:bookstore/components/navbar.dart'; // MainScreen
import 'package:bookstore/screens/profile/order_history_screen.dart';
import 'package:bookstore/screens/profile/wishlist_screen.dart'; // Add this import
import 'package:bookstore/admindashboard.dart';
import 'package:bookstore/adminmiddleware.dart';
import 'package:bookstore/firebase_options.dart';
import 'package:bookstore/wrapper.dart';
import 'package:bookstore/forgot.dart';
import 'package:bookstore/firebase_test_screen.dart';
import 'package:bookstore/services/wishlist_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    // Initialize the wishlist after Firebase is ready
    await WishlistManager.initWishlist();
  } catch (e) {
    print('Error initializing Firebase: $e');
    runApp(const FirebaseErrorApp());
    return;
  }
  runApp(const MainApp());
}

class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Failed to initialize Firebase',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/signup',
      getPages: [
        GetPage(name: '/', page: () => const Wrapper()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/signup', page: () => const SignupScreen()),
        GetPage(name: '/forgot', page: () => const ForgotPassword()),
        GetPage(name: '/main', page: () => const MainScreen()),
        GetPage(name: '/home', page: () => const MainScreen()), // Updated to MainScreen
        GetPage(name: '/search', page: () => const SearchScreen()),
        GetPage(name: '/cart', page: () => const CartScreen()),
        GetPage(name: '/order_history', page: () => const OrderHistoryScreen()),
        GetPage(name: '/wishlist', page: () => const WishlistScreen()),
        GetPage(
          name: '/admin',
          page: () => const AdminDashboard(),
          middlewares: [AdminMiddleware()],
        ),
        GetPage(name: '/firebase-test', page: () => const FirebaseTestScreen()),
      ],
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => const Scaffold(body: Center(child: Text('Not Found'))),
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(UserController());
      }),
      theme: ThemeData(
        primaryColor: const Color(0xFF7857FC),
        scaffoldBackgroundColor: const Color(0xFFF9F5F1),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7857FC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9F5F1),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
    );
  }
}