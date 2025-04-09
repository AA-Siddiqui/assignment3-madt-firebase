import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart' as app_user;

class AuthService with ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  app_user.User? _currentUser;

  app_user.User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  Future<bool> register(String email, String address, String password) async {
    // try {
    // Create user with email and password (using name as email for simplicity)
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email, // Using name as email for demo purposes
      password: password,
    );

    // Create user profile in Firestore
    final userId = userCredential.user!.uid;
    await _firestore.collection('users').doc(userId).set({
      'name': email,
      'address': address,
      'email': email,
    });

    // Set current user
    _currentUser = app_user.User(
      id: int.tryParse(userId.substring(0, 8), radix: 16) ??
          0, // Convert part of UID to int for backward compatibility
      email: email,
      address: address,
      password: password, // Consider not storing this in memory in real apps
    );

    await _saveUserSession(userId);
    notifyListeners();
    return true;
    // } catch (e) {
    //   print('Registration error: $e');
    //   return false;
    // }
  }

  Future<bool> login(String email, String password) async {
    try {
      // Login with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, // Using name as email for demo
        password: password,
      );

      // Get user profile from Firestore
      final userId = userCredential.user!.uid;
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        _currentUser = app_user.User(
          id: int.tryParse(userId.substring(0, 8), radix: 16) ?? 0,
          email: userData['name'],
          address: userData['address'],
          password:
              password, // Not stored in Firestore but kept for model compatibility
        );

        await _saveUserSession(userId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    notifyListeners();
  }

  Future<void> _saveUserSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
  }

  Future<void> checkUserSession() async {
    // First check if Firebase has a current user
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      // Get user data from Firestore
      final docSnapshot =
          await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        _currentUser = app_user.User(
          id: int.tryParse(firebaseUser.uid.substring(0, 8), radix: 16) ?? 0,
          email: userData['name'],
          address: userData['address'],
          password: '', // Password is not stored in Firestore
        );
        notifyListeners();
        return;
      }
    }

    // Fallback to shared preferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null && firebaseUser == null) {
      // Try to get user from Firestore using stored ID
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data()!;
        _currentUser = app_user.User(
          id: int.tryParse(userId.substring(0, 8), radix: 16) ?? 0,
          email: userData['name'],
          address: userData['address'],
          password: '', // Password is not stored
        );
        notifyListeners();
      }
    }
  }
}
