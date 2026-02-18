import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';

class ChatService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  // Generate consistent chat ID for two users
  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Get all users except current user
  Stream<List<AppUser>> getUsers(String currentUserId) {
    if (currentUserId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          if (data == null) return null;
          return AppUser.fromMap(data);
        }).whereType<AppUser>().toList();
      } catch (e) {
        print('Error mapping users: $e');
        return [];
      }
    });
  }

  // Get messages for a specific chat
  Stream<List<Message>> getMessages(String userId, String otherUserId) {
    final chatId = _getChatId(userId, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data());
      }).toList();
    });
  }

  // Get last message for a specific chat (for chat preview)
  Stream<Message?> getLastMessage(String userId, String otherUserId) {
    final chatId = _getChatId(userId, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      try {
        return Message.fromMap(snapshot.docs.first.data());
      } catch (e) {
        print('Error parsing last message: $e');
        return null;
      }
    });
  }

  // Get unread message count
  Stream<int> getUnreadCount(String userId, String otherUserId) {
    final chatId = _getChatId(userId, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Send a text message
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    try {
      _setLoading(true);

      final chatId = _getChatId(senderId, receiverId);
      final messageId = _uuid.v4();

      final messageData = {
        'id': messageId,
        'chatId': chatId,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(), // Use server timestamp
        'isRead': false,
        'messageType': 'text',
      };

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(messageData);

      // Update chat document with last message info
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [senderId, receiverId],
        'lastMessageId': messageId,
        'lastMessageText': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _setLoading(false);

    } catch (e) {
      _setError('Error sending message: $e');
      _setLoading(false);
      rethrow;
    }
  }

  // Mark message as read
  Future<void> markAsRead(String messageId, String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Mark all messages from a user as read
  Future<void> markAllAsRead(String userId, String otherUserId) async {
    try {
      final chatId = _getChatId(userId, otherUserId);

      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Delete a message
  Future<void> deleteMessage(String messageId, String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // Search users
  Stream<List<AppUser>> searchUsers(String query, String currentUserId) {
    if (query.isEmpty) {
      return getUsers(currentUserId);
    }

    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .where((user) =>
      user.displayName.toLowerCase().contains(query.toLowerCase()) ||
          user.email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  // Update user online status
  Future<void> updateUserStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  // Get all chats for a user (for chat list)
  Stream<List<Map<String, dynamic>>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> chatList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final otherUserId = (data['participants'] as List)
            .firstWhere((id) => id != userId);

        // Get other user details
        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();

        if (userDoc.exists) {
          final user = AppUser.fromMap(userDoc.data()!);

          // Get last message for this chat
          final lastMessageDoc = await _firestore
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          Message? lastMessage;
          if (lastMessageDoc.docs.isNotEmpty) {
            lastMessage = Message.fromMap(lastMessageDoc.docs.first.data());
          }

          // Get unread count
          final unreadCount = await _firestore
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .where('receiverId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .count()
              .get();

          chatList.add({
            'user': user,
            'lastMessage': lastMessage,
            'unreadCount': unreadCount.count ?? 0,
            'lastMessageTime': data['lastMessageTime']?.toDate(),
          });
        }
      }

      return chatList;
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}