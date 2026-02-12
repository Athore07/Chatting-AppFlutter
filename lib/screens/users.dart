import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Users"),
      centerTitle: true,
        backgroundColor: Colors.lightBlue[400],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return const Center(child: Text("Something went wrong"));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final rawUsername = data["username"]?.toString();
              final displayName = (rawUsername != null && rawUsername.isNotEmpty)
                  ? rawUsername.replaceAll('_', '')
                  : (data["name"] ?? data["email"] ?? "No Name");
              return ListTile(
                title: Text(displayName),
                subtitle: Text(data["email"] ?? ""),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
