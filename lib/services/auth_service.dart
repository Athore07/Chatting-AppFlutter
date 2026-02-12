import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future register(String username, String email, String password) async {
    // ensure username is unique
    final existing = await _db.collection('users').where('username', isEqualTo: username).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw Exception('Username already taken');
    }

    var user = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    // set display name on the Firebase user to username
    await user.user!.updateDisplayName(username);

    await _db.collection("users").doc(user.user!.uid).set({
      "email": email,
      "username": username,
      "uid": user.user!.uid,
    });
  }

  Future login(String identifier, String password) async {
    String email = identifier;
    // if identifier is not an email, treat it as username and resolve to email
    if (!identifier.contains('@')) {
      final q = await _db.collection('users').where('username', isEqualTo: identifier).limit(1).get();
      if (q.docs.isEmpty) throw Exception('User not found');
      final data = q.docs.first.data() as Map<String, dynamic>?;
      email = data?['email'] ?? identifier;
    }

    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future resetPassword(String identifier) async {
    String email = identifier;
    if (!identifier.contains('@')) {
      final q = await _db.collection('users').where('username', isEqualTo: identifier).limit(1).get();
      if (q.docs.isEmpty) throw Exception('User not found');
      final data = q.docs.first.data() as Map<String, dynamic>?;
      email = data?['email'] ?? identifier;
    }

    await _auth.sendPasswordResetEmail(email: email);
  }

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
