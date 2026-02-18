import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../model/user_model.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Sign in with email and password
  Future<String> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Update last seen
      await updateLastSeen();

      _isLoading = false;
      notifyListeners();
      return 'success';

    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _handleAuthError(e);
      notifyListeners();
      return _errorMessage ?? 'Login failed';

    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An error occurred. Please try again.';
      notifyListeners();
      return _errorMessage!;
    }
  }

  // Register new user
  Future<String> register(String email, String password, String displayName) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Create user document in Firestore
      final newUser = AppUser(
        uid: userCredential.user!.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        photoURL: null,
        fcmToken: null,
        lastSeen: DateTime.now(),
        isOnline: true,
        status: 'Hey there! I am using Chat App',
      );

      await _firestore
          .collection('users')
          .doc(newUser.uid)
          .set(newUser.toMap());

      _isLoading = false;
      notifyListeners();
      return 'success';

    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _handleAuthError(e);
      notifyListeners();
      return _errorMessage ?? 'Registration failed';

    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An error occurred. Please try again.';
      notifyListeners();
      return _errorMessage!;
    }
  }

  // Get current user data from Firestore
  Future<AppUser?> getCurrentUserData() async {
    if (_auth.currentUser == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();

      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  // Update user profile
  Future<String> updateProfile({
    required String displayName,
    String? photoURL,
    String? status,
  }) async {
    try {
      if (_auth.currentUser == null) return 'No user logged in';

      Map<String, dynamic> updates = {
        'displayName': displayName.trim(),
        if (photoURL != null) 'photoURL': photoURL,
        if (status != null) 'status': status,
      };

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update(updates);

      return 'success';

    } catch (e) {
      return 'Failed to update profile: $e';
    }
  }

  // Update last seen
  Future<void> updateLastSeen() async {
    if (_auth.currentUser != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'lastSeen': DateTime.now().toIso8601String(),
          'isOnline': true,
        });
      } catch (e) {
        print('Error updating last seen: $e');
      }
    }
  }

  // Update FCM token
  Future<void> updateFCMToken(String token) async {
    if (_auth.currentUser != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'fcmToken': token,
        });
      } catch (e) {
        print('Error updating FCM token: $e');
      }
    }
  }

  // Set user offline
  Future<void> setUserOffline() async {
    if (_auth.currentUser != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'isOnline': false,
          'lastSeen': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error setting user offline: $e');
      }
    }
  }

  // Sign out
  Future<void> logout() async {
    try {
      await setUserOffline();
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Send password reset email
  Future<String> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'success';
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return _errorMessage ?? 'Failed to send reset email';
    }
  }

  // Handle Firebase Auth errors
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No user found with this email.';
        break;
      case 'wrong-password':
        _errorMessage = 'Incorrect password.';
        break;
      case 'invalid-credential':
        _errorMessage = 'Invalid email or password.';
        break;
      case 'user-disabled':
        _errorMessage = 'This account has been disabled.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Email already registered. Please login instead.';
        break;
      case 'invalid-email':
        _errorMessage = 'Invalid email address.';
        break;
      case 'weak-password':
        _errorMessage = 'Password is too weak.';
        break;
      case 'operation-not-allowed':
        _errorMessage = 'Email/password accounts are not enabled.';
        break;
      default:
        _errorMessage = e.message ?? 'An error occurred';
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}