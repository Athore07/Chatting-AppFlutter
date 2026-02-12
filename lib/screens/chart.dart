import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  ChatScreen({required this.userId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final auth = AuthService();

  String chatId(String uid1, String uid2) =>
      uid1.compareTo(uid2) > 0 ? uid1 + uid2 : uid2 + uid1;

  void sendMessage() async {
    if (_msgController.text.isEmpty) return;

    final id = chatId(auth.currentUser!.uid, widget.userId);

    await FirebaseFirestore.instance
        .collection("chats")
        .doc(id)
        .collection("messages")
        .add({
      "text": _msgController.text,
      "sender": auth.currentUser!.uid,
      "time": Timestamp.now(),
    });

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final id = chatId(auth.currentUser!.uid, widget.userId);

    return Scaffold(
      appBar: AppBar(title: Text("Chat"),
      centerTitle: true,
        backgroundColor: Colors.grey[600],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(id)
                  .collection("messages")
                  .orderBy("time")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    return ListTile(
                      title: Text(doc["text"]),
                      subtitle: Text(doc["sender"]),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _msgController),
              ),
              IconButton(icon: Icon(Icons.send), onPressed: sendMessage)
            ],
          )
        ],
      ),
    );
  }
}
