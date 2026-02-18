import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? messageType;
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.messageType = 'text',
    this.mediaUrl,
    this.fileName,
    this.fileSize,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp, // Will be converted to Timestamp by Firestore
      'isRead': isRead,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    // Handle timestamp - it could be Timestamp or DateTime
    DateTime timestampDateTime;

    if (map['timestamp'] is Timestamp) {
      timestampDateTime = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is DateTime) {
      timestampDateTime = map['timestamp'];
    } else {
      timestampDateTime = DateTime.now();
    }

    return Message(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      timestamp: timestampDateTime,
      isRead: map['isRead'] ?? false,
      messageType: map['messageType'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
    );
  }

  bool isFromUser(String userId) => senderId == userId;
  bool isToUser(String userId) => receiverId == userId;
}