import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of user auth changes
  Stream<User?> get user => _auth.authStateChanges();

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // ==================== ERROR HANDLING ====================

  String _handleAuthError(dynamic error) {
    String errorMessage = 'An error occurred. Please try again.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
      // Registration errors
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please login instead.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use at least 6 characters.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled. Please contact support.';
          break;

      // Login errors
        case 'user-not-found':
          errorMessage = 'No account found with this email. Please register first.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;

      // Network errors
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;

        default:
          errorMessage = 'Authentication failed: ${error.message}';
      }
    } else if (error is FirebaseException) {
      errorMessage = 'Firebase error: ${error.message}';
    }

    return errorMessage;
  }

  // ==================== VALIDATION ====================

  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    );
    return emailRegex.hasMatch(email);
  }

  bool isValidPassword(String password) {
    return password.length >= 6;
  }

  bool isValidName(String name) {
    return name.trim().length >= 2 && name.trim().length <= 50;
  }

  // ==================== REGISTRATION ====================

  Future<User?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Validate inputs
      if (!isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }
      if (!isValidPassword(password)) {
        throw Exception('Password must be at least 6 characters long');
      }
      if (!isValidName(name)) {
        throw Exception('Name must be between 2 and 50 characters');
      }

      // Check if email exists in Firestore
      final emailExists = await _checkEmailExists(email);
      if (emailExists) {
        throw Exception('Email already exists');
      }

      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Registration failed');

      // Update profile with display name
      await user.updateDisplayName(name.trim());
      await user.reload();

      // Create user document in Firestore
      await _createUserDocument(user, name, email);

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      // If Firestore check fails, try Firebase Auth methods
      try {
        await _auth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(),
          password: 'dummyPassword',
        );
        return true; // Email exists in Auth
      } catch (e) {
        return false;
      }
    }
  }

  Future<void> _createUserDocument(User user, String name, String email) async {
    final userData = {
      'uid': user.uid,
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'displayName': name.trim(),
      'photoURL': user.photoURL ?? '',
      'phoneNumber': user.phoneNumber ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'isActive': true,
      'bio': '',
      'status': 'Hey there! I am using ChatApp',
    };

    await _firestore.collection('users').doc(user.uid).set(userData);

    // Create initial user settings
    await _firestore.collection('users').doc(user.uid).collection('settings').doc('preferences').set({
      'notifications': true,
      'soundEnabled': true,
      'vibrationEnabled': true,
      'darkMode': false,
      'language': 'en',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== LOGIN ====================

  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      // Validate inputs
      if (!isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }
      if (password.isEmpty) {
        throw Exception('Please enter your password');
      }

      // Sign in with email and password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Login failed');

      // Update user status and last login
      await _updateUserAfterLogin(user.uid);

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } on FirebaseException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Login failed. Please try again.');
    }
  }

  Future<void> _updateUserAfterLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log error but don't throw - non-critical operation
      debugPrint('Error updating user after login: $e');
    }
  }

  // ==================== LOGOUT ====================

  Future<void> logout() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Update online status before logging out
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeenAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Logout failed. Please try again.');
    }
  }

  // ==================== PROFILE MANAGEMENT ====================

  Future<void> updateProfile({
    required String name,
    String? photoURL,
    String? bio,
    String? phoneNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Validate name
      if (!isValidName(name)) {
        throw Exception('Name must be between 2 and 50 characters');
      }

      // Update Firebase Auth profile
      await user.updateDisplayName(name.trim());
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();

      // Update Firestore document
      final updateData = <String, dynamic>{
        'name': name.trim(),
        'displayName': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (photoURL != null) updateData['photoURL'] = photoURL;
      if (bio != null) updateData['bio'] = bio;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;

      await _firestore.collection('users').doc(user.uid).update(updateData);
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  // ==================== PASSWORD MANAGEMENT ====================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      if (!isValidPassword(newPassword)) {
        throw Exception('New password must be at least 6 characters');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      }
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Password change failed: ${e.toString()}');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      if (!isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // ==================== USER DATA ====================

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user subcollections
      final batch = _firestore.batch();

      // Delete settings
      final settings = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .get();

      for (var doc in settings.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Delete user from Firebase Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please login again to delete your account');
      }
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception('Account deletion failed: ${e.toString()}');
    }
  }

  // ==================== SOCIAL AUTH (Optional) ====================

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled by user');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        // Check if user already exists in Firestore
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Create new user document
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'Google User',
            'photoURL': user.photoURL,
            'phoneNumber': '',
            'bio': '',
            'createdAt': Timestamp.now(),
            'isOnline': true,
            'lastSeenAt': Timestamp.now(),
          });
        } else {
          // Update online status for existing user
          await _firestore.collection('users').doc(user.uid).update({
            'isOnline': true,
            'lastSeenAt': Timestamp.now(),
          });
        }
      }
      
      return user;
    } catch (e) {
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // ==================== UTILITY METHODS ====================

  Future<void> verifyEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.sendEmailVerification();
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    return user.emailVerified;
  }
}