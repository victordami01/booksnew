import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  _FirebaseTestScreenState createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  bool _isLoadingAuth = false;
  bool _isLoadingWrite = false;
  bool _isLoadingRead = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // Ensure Firestore persistence is enabled
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoadingAuth = true;
      _statusMessage = '';
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        setState(() {
          _statusMessage = 'Device is offline. Authentication may fail.';
        });
        Get.snackbar(
          'Offline',
          'You are offline. Please connect to the internet to authenticate.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _statusMessage = 'Signed in anonymously with UID: ${userCredential.user!.uid}';
      });
      Get.snackbar(
        'Success',
        'Signed in anonymously with UID: ${userCredential.user!.uid}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error signing in: $e';
      });
      Get.snackbar(
        'Error',
        'Failed to sign in: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _writeToFirestore() async {
    setState(() {
      _isLoadingWrite = true;
      _statusMessage = '';
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        setState(() {
          _statusMessage = 'Device is offline. Write operation will be queued.';
        });
        Get.snackbar(
          'Offline',
          'You are offline. The write operation will be queued and synced when you reconnect.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      await FirebaseFirestore.instance.collection('test').doc('test-doc').set({
        'test': 'This is a test',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _statusMessage = 'Successfully wrote test document to Firestore';
      });
      Get.snackbar(
        'Success',
        'Test document written to Firestore',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error writing to Firestore: $e';
      });
      Get.snackbar(
        'Error',
        'Failed to write to Firestore: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoadingWrite = false;
      });
    }
  }

  Future<void> _readFromFirestore() async {
    setState(() {
      _isLoadingRead = true;
      _statusMessage = '';
    });

    try {
      bool isOnline = await _checkConnectivity();
      if (!isOnline) {
        setState(() {
          _statusMessage = 'Device is offline. Attempting to read from cache.';
        });
        Get.snackbar(
          'Offline',
          'You are offline. Attempting to read from cache.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('test').doc('test-doc').get();
      if (doc.exists) {
        setState(() {
          _statusMessage = 'Read from Firestore: ${doc.data()}';
        });
        Get.snackbar(
          'Success',
          'Read test document: ${doc.data()}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        setState(() {
          _statusMessage = 'Test document does not exist';
        });
        Get.snackbar(
          'Error',
          'Test document does not exist',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error reading from Firestore: $e';
      });
      Get.snackbar(
        'Error',
        'Failed to read from Firestore: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() {
        _isLoadingRead = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5F1),
        title: const Text(
          'Firebase Test',
          style: TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF9F5F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Firebase Test Screen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              _isLoadingAuth
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      onPressed: _signInAnonymously,
                      child: const Text(
                        'Sign In Anonymously',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              _isLoadingWrite
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      onPressed: _writeToFirestore,
                      child: const Text(
                        'Write to Firestore',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              _isLoadingRead
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7857FC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      onPressed: _readFromFirestore,
                      child: const Text(
                        'Read from Firestore',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
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