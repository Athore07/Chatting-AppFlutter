import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String date;
  _DateHeaderDelegate(this.date);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          date,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) {
    return oldDelegate.date != date;
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final auth = AuthService();
  final String groupChatId = "group_chat_room";
  final ScrollController _scrollController = ScrollController();

  String formatTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('HH:mm').format(dateTime);
  }

  String formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    
    if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
      return 'Today';
    } else if (dateTime.day == now.day - 1 && dateTime.month == now.month && dateTime.year == now.year) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  void sendMessage() async {
    if (_msgController.text.isEmpty) return;

    // fetch current user's username (if any)
    String senderUsername = '';
    try {
      final udoc = await FirebaseFirestore.instance.collection('users').doc(auth.currentUser!.uid).get();
      if (udoc.exists) {
        final data = udoc.data();
        senderUsername = data?['username'] ?? '';
      }
    } catch (_) {}

    await FirebaseFirestore.instance
        .collection("group_chats")
        .doc(groupChatId)
        .collection("messages")
        .add({
      "text": _msgController.text,
      "sender": auth.currentUser!.uid,
      "senderEmail": auth.currentUser!.email,
      "senderName": auth.currentUser!.displayName ?? auth.currentUser!.email,
      "senderUsername": senderUsername,
      "time": Timestamp.now(),
    });

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
        centerTitle: true,
        backgroundColor: Colors.grey[600],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("group_chats")
                  .doc(groupChatId)
                  .collection("messages")
                  .orderBy("time", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No messages yet. Start chatting!"));
                }

                // Group docs by date string
                final Map<String, List<QueryDocumentSnapshot>> groups = {};
                for (var doc in docs) {
                  final timestamp = doc["time"] as Timestamp;
                  final date = formatDate(timestamp);
                  groups.putIfAbsent(date, () => []).add(doc);
                }

                final slivers = <Widget>[];
                groups.forEach((date, groupDocs) {
                  slivers.add(SliverPersistentHeader(
                    pinned: true,
                    delegate: _DateHeaderDelegate(date),
                  ));
                  slivers.add(SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = groupDocs[index];
                      final isSender = doc["sender"] == auth.currentUser!.uid;
                      final timestamp = doc["time"] as Timestamp;
                      final time = formatTime(timestamp);

                      return Column(
                        crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSender ? Colors.blue[400] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSender
                                        ? 'You'
                                        : (doc["senderUsername"] != null && (doc["senderUsername"] as String).isNotEmpty
                                            ? doc["senderUsername"]
                                            : (doc["senderName"] ?? doc["senderEmail"] ?? "Anonymous")),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSender ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doc["text"],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSender ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            child: Text(
                              time,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      );
                    }, childCount: groupDocs.length),
                  ));
                });

                // Ensure we scroll to bottom when new messages appear
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: slivers,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
