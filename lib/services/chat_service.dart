// services/chat_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/message_model.dart';
import 'package:flutter/material.dart';
import '../model/user_model.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get or create chat room ID
  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Send a message
  Future<void> sendMessage(Message message) async {
    try {
      final chatId = _getChatId(message.senderId, message.receiverId);

      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      // Update last message in chat document
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': message.text,
        'lastMessageTime': message.timestamp,
        'lastMessageSenderId': message.senderId,
        'participants': [message.senderId, message.receiverId],
      }, SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream
  Stream<List<Message>> getMessages(String userId1, String userId2) {
    final chatId = _getChatId(userId1, userId2);

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

  // Get last message stream
  Stream<Message?> getLastMessage(String userId1, String userId2) {
    final chatId = _getChatId(userId1, userId2);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Message.fromMap(snapshot.docs.first.data());
    });
  }

  // Mark a single message as read
  Future<void> markAsRead(String messageId, String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true, 'status': 'read'});

      notifyListeners();
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Mark all messages in a chat as read
  Future<void> markAllAsRead(String userId, String otherUserId) async {
    try {
      final chatId = _getChatId(userId, otherUserId);

      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true, 'status': 'read'});
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // Get all users except current user
  Stream<List<AppUser>> getUsers(String currentUserId) {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppUser.fromMap(doc.data());
      }).toList();
    });
  }

  // Search users
  Stream<List<AppUser>> searchUsers(String query, String currentUserId) {
    if (query.isEmpty) {
      return getUsers(currentUserId);
    }

    // Note: For better search, consider using Firebase Extensions or Algolia
    // This is a simple implementation
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .where((user) {
        final name = user.displayName.toLowerCase();
        final email = user.email.toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      })
          .toList();
    });
  }

  // Send typing status
  Future<void> sendTypingStatus(String senderId, String receiverId, bool isTyping) async {
    try {
      final chatId = _getChatId(senderId, receiverId);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
        'typingStatus.$senderId': isTyping,
        'typingStatus.$senderId UpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending typing status: $e');
    }
  }

  // Get typing status stream
  Stream<bool> getTypingStatus(String userId, String currentUserId) {
    final chatId = _getChatId(userId, currentUserId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;

      final data = snapshot.data();
      if (data == null) return false;

      final typingStatus = data['typingStatus'] as Map<String, dynamic>?;
      if (typingStatus == null) return false;

      // Check if the other user is typing
      return typingStatus[userId] == true;
    });
  }

  // Update user online status
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
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

      notifyListeners();
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  // Add reaction to message
  // Add reaction to message
  Future<void> addReaction(String messageId, String chatId, String reaction, String userId) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(messageRef);
        if (!snapshot.exists) return;

        // Get current reactions or initialize empty map
        Map<String, dynamic> reactions = {};

        if (snapshot.data() != null && snapshot.data()!.containsKey('reactions')) {
          final existingReactions = snapshot.data()!['reactions'];
          if (existingReactions != null) {
            reactions = Map<String, dynamic>.from(existingReactions);
          }
        }

        // Add or toggle reaction
        if (reactions.containsKey(userId) && reactions[userId] == reaction) {
          // If same reaction exists, remove it (toggle off)
          reactions.remove(userId);
        } else {
          // Add new reaction or replace existing one
          reactions[userId] = reaction;
        }

        // Update the message with new reactions
        transaction.update(messageRef, {'reactions': reactions});
      });

      notifyListeners();
    } catch (e) {
      print('Error adding reaction: $e');
      rethrow;
    }
  }

  // Clear entire chat
  Future<void> clearChat(String userId1, String userId2) async {
    try {
      final chatId = _getChatId(userId1, userId2);

      // Delete all messages in the chat
      final messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();

      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Update or delete chat document
      batch.set(
        _firestore.collection('chats').doc(chatId),
        {
          'lastMessage': null,
          'lastMessageTime': null,
          'lastMessageSenderId': null,
          'clearedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      notifyListeners();
    } catch (e) {
      print('Error clearing chat: $e');
      rethrow;
    }
  }

  // Get unread message count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      int totalUnread = 0;

      for (var chatDoc in snapshot.docs) {
        final chatId = chatDoc.id;

        final unreadMessages = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('receiverId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .count()
            .get();

        totalUnread += unreadMessages.count ?? 0;
      }

      return totalUnread;
    });
  }

  // Get chat participants
  Future<List<String>> getChatParticipants(String chatId) async {
    try {
      final doc = await _firestore.collection('chats').doc(chatId).get();
      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null) return [];

      return List<String>.from(data['participants'] ?? []);
    } catch (e) {
      print('Error getting chat participants: $e');
      return [];
    }
  }
}