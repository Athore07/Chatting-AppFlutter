import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? fcmToken;
  final DateTime lastSeen;
  final bool? isOnline;
  final String? status;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.fcmToken,
    required this.lastSeen,
    this.isOnline,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'fcmToken': fcmToken,
      'lastSeen': Timestamp.fromDate(lastSeen), // Store as Timestamp
      'isOnline': isOnline ?? false,
      'status': status ?? 'Hey there! I am using Chat App',
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    // Handle lastSeen - it could be Timestamp or String
    DateTime lastSeenDateTime;

    if (map['lastSeen'] is Timestamp) {
      // If it's a Timestamp object (from Firestore)
      lastSeenDateTime = (map['lastSeen'] as Timestamp).toDate();
    } else if (map['lastSeen'] is String) {
      // If it's a string (fallback)
      try {
        lastSeenDateTime = DateTime.parse(map['lastSeen']);
      } catch (e) {
        lastSeenDateTime = DateTime.now();
      }
    } else {
      // Default to now if null or other type
      lastSeenDateTime = DateTime.now();
    }

    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      fcmToken: map['fcmToken'],
      lastSeen: lastSeenDateTime,
      isOnline: map['isOnline'] ?? false,
      status: map['status'] ?? 'Hey there! I am using Chat App',
    );
  }

  // Copy with method for updating specific fields
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? fcmToken,
    DateTime? lastSeen,
    bool? isOnline,
    String? status,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      fcmToken: fcmToken ?? this.fcmToken,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
    );
  }
}