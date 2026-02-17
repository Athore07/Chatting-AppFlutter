import 'package:chatting_app/screens/profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chart.dart';
import 'login.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final searchController = TextEditingController();
  String searchQuery = '';
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _updateUserStatus(true);
  }

  @override
  void dispose() {
    _updateUserStatus(false);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _updateUserStatus(bool isOnline) async {
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating user status: $e');
      }
    }
  }

  Future<void> _logout() async {
    try {
      if (!mounted) return;

      await _updateUserStatus(false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Logout failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuTile(
              icon: Icons.person,
              iconColor: Colors.blue,
              title: 'View Profile',
              subtitle: 'See your profile information',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
                );
              },
            ),
            _buildMenuTile(
              icon: Icons.settings,
              iconColor: Colors.orange,
              title: 'Settings',
              subtitle: 'App preferences and settings',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Settings coming soon!', Colors.blue);
              },
            ),
            const Divider(),
            _buildMenuTile(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: 'Logout',
              subtitle: 'Sign out from your account',
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  void _navigateToChat(BuildContext context, String receiverId, String receiverEmail, String receiverName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: receiverId,
          senderId: currentUser?.uid ?? '',
          receiverName: receiverName,
        ),
      ),
    );
  }

  String _formatEmail(String email) {
    final atIndex = email.indexOf('@');
    return atIndex > 0 ? email.substring(0, atIndex) : email;
  }

  String _formatLastSeen(Timestamp? lastSeen) {
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final lastSeenDate = lastSeen.toDate();
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<Map<String, dynamic>?> _getLastMessageWithStatus(String currentUserId, String otherUserId) async {
    try {
      final chatId = currentUserId.compareTo(otherUserId) < 0
          ? '$currentUserId-$otherUserId'
          : '$otherUserId-$currentUserId';

      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final messageDoc = snapshot.docs.first.data();
      return {
        'message': messageDoc['text'] ?? '',
        'senderId': messageDoc['senderId'] ?? '',
        'isDelivered': messageDoc['isDelivered'] ?? false,
        'isRead': messageDoc['isRead'] ?? false,
        'timestamp': messageDoc['timestamp'],
      };
    } catch (e) {
      debugPrint('Error fetching last message: $e');
      return null;
    }
  }

  Future<Map<String, Timestamp>> _getRecentChatTimestamps(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recent_chats')
          .get();

      return {
        for (var doc in snapshot.docs)
          if (doc.data()['withUserId'] != null && doc.data()['timestamp'] != null)
            doc.data()['withUserId']: doc.data()['timestamp'] as Timestamp,
      };
    } catch (e) {
      debugPrint('Error fetching recent chat timestamps: $e');
      return {};
    }
  }

  Widget _buildStatusIndicator(bool isOnline, Timestamp? lastSeen) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: isOnline
          ? null
          : Container(), // Just for the colored circle
    );
  }

  Widget _buildMessageStatusIcon(Map<String, dynamic>? messageData, bool isCurrentUser) {
    if (messageData == null || !isCurrentUser) return const SizedBox.shrink();

    final isDelivered = messageData['isDelivered'] ?? false;
    final isRead = messageData['isRead'] ?? false;

    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 4),
        ],
      );
    } else if (isDelivered) {
      return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            ]
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
        ],
      );
    }
  }

  Widget _buildUserTile({
    required BuildContext context,
    required String userId,
    required String userName,
    required String userEmail,
    required String currentUserId,
    required bool isOnline,
    required Timestamp? lastSeen,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[50],
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildStatusIndicator(isOnline, lastSeen),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
              ),
            ),
            if (!isOnline && lastSeen != null)
              Text(
                _formatLastSeen(lastSeen),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
        subtitle: FutureBuilder<Map<String, dynamic>?>(
          future: _getLastMessageWithStatus(currentUserId, userId),
          builder: (context, snapshot) {
            String lastMessageText = 'No messages';
            Widget? statusIcon;

            if (snapshot.hasData && snapshot.data != null) {
              final messageData = snapshot.data!;
              final isYourMessage = messageData['senderId'] == currentUserId;
              final message = messageData['message'] ?? '';

              lastMessageText = isYourMessage ? 'You: $message' : message;

              if (isYourMessage) {
                statusIcon = _buildMessageStatusIcon(messageData, true);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  ?statusIcon,
                  Expanded(
                    child: Text(
                      lastMessageText,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Text("Chat", style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
        ),
        onTap: () => _navigateToChat(context, userId, userEmail, userName),
      ),
    );
  }

  Widget _buildErrorState(AsyncSnapshot snapshot) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text("Error loading users", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(snapshot.error.toString(), style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No users found", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text("Invite friends to start chatting", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    if (searchQuery.isEmpty) return users;

    return users.where((user) {
      final data = user.data() as Map<String, dynamic>;
      final name = (data['name'] as String?)?.toLowerCase() ?? '';
      final email = (data['email'] as String?)?.toLowerCase() ?? '';
      return name.contains(searchQuery) || email.contains(searchQuery);
    }).toList();
  }

  List<QueryDocumentSnapshot> _sortUsers(
      List<QueryDocumentSnapshot> users,
      Map<String, Timestamp> recentChats,
      ) {
    final filteredUsers = _filterUsers(users);

    filteredUsers.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aId = aData['uid'] ?? '';
      final bId = bData['uid'] ?? '';

      // Skip current user in sorting logic
      if (aId == currentUser?.uid && bId != currentUser?.uid) return 1;
      if (bId == currentUser?.uid && aId != currentUser?.uid) return -1;
      if (aId == currentUser?.uid && bId == currentUser?.uid) return 0;

      // Sort online users first
      final aOnline = aData['isOnline'] ?? false;
      final bOnline = bData['isOnline'] ?? false;

      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;

      final aHasRecent = recentChats.containsKey(aId);
      final bHasRecent = recentChats.containsKey(bId);

      if (aHasRecent && !bHasRecent) return -1;
      if (!aHasRecent && bHasRecent) return 1;
      if (aHasRecent && bHasRecent) {
        return recentChats[bId]?.compareTo(recentChats[aId] ?? Timestamp.now()) ?? 0;
      }

      return (aData['name'] ?? '').compareTo(bData['name'] ?? '');
    });

    return filteredUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
          controller: searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search users by name or email...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          onChanged: (value) => setState(() => searchQuery = value.toLowerCase().trim()),
        )
            : const Text("Chat Users", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: isSearching
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              isSearching = false;
              searchQuery = '';
              searchController.clear();
            });
          },
        )
            : null,
        actions: [
          if (!isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => isSearching = true),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: currentUser?.uid ?? '')));
                  break;
                case 'settings':
                  _showSnackBar('Settings coming soon!', Colors.blue);
                  break;
                case 'logout':
                  _showLogoutDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person, color: Colors.blue), SizedBox(width: 8), Text('Profile')])),
              const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: Colors.orange), SizedBox(width: 8), Text('Settings')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Logout')])),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("users").snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.blue));
            }
            if (snapshot.hasError) return _buildErrorState(snapshot);
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

            final allUsers = snapshot.data!.docs;

            return FutureBuilder<Map<String, Timestamp>>(
              future: _getRecentChatTimestamps(currentUser?.uid ?? ''),
              builder: (context, recentSnapshot) {
                if (recentSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blue));
                }

                final recentChats = recentSnapshot.data ?? {};
                final sortedUsers = _sortUsers(allUsers, recentChats);

                // Filter out current user
                final filteredUsers = sortedUsers.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  return userData['uid'] != currentUser?.uid;
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty ? "No other users found" : "No users match your search",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    final userData = filteredUsers[index].data() as Map<String, dynamic>;
                    final userId = userData["uid"] ?? '';
                    final userEmail = userData["email"] ?? 'No email';
                    final userName = userData["name"] ?? _formatEmail(userEmail);
                    final isOnline = userData["isOnline"] ?? false;
                    final lastSeen = userData["lastSeen"] as Timestamp?;

                    return _buildUserTile(
                      context: context,
                      userId: userId,
                      userName: userName,
                      userEmail: userEmail,
                      currentUserId: currentUser?.uid ?? '',
                      isOnline: isOnline,
                      lastSeen: lastSeen,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserTile({
    required BuildContext context,
    required String userId,
    required String userName,
    required String userEmail,
    required String currentUserId,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[50],
              child: Text(
                userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          userName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: FutureBuilder<Map<String, dynamic>?>(
          future: _getLastMessage(currentUserId, userId),
          builder: (context, snapshot) {
            String lastMessageText = 'No messages';
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData &&
                snapshot.data != null) {
              final messageData = snapshot.data!;
              final senderId = messageData['senderId'] ?? '';
              final message = messageData['message'] ?? '';
              final isYourMessage = senderId == currentUserId;
              lastMessageText = isYourMessage
                  ? 'You: $message'
                  : message;
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                lastMessageText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 18,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 4),
              Text(
                "Chat",
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        onTap: () => _navigateToChat(context, userId, userEmail, currentUserId),
      ),
    );
  }

  void _navigateToChat(
      BuildContext context,
      String receiverId,
      String receiverEmail,
      String currentUserId,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverId: receiverId,
          senderId: currentUserId,
          receiverName: _formatEmail(receiverEmail),
        ),
      ),
    );
  }

  String _formatEmail(String email) {
    // Extract username from email (part before @)
    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      return email.substring(0, atIndex);
    }
    return email;
  }

  Future<Map<String, dynamic>?> _getLastMessage(
      String currentUserId, String otherUserId) async {
    try {
      // Create chat ID (same logic as in ChatScreen)
      final chatId = currentUserId.compareTo(otherUserId) < 0
          ? '$currentUserId-$otherUserId'
          : '$otherUserId-$currentUserId';

      // Get the last message from the chat
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final messageDoc = snapshot.docs.first.data();
      return {
        'message': messageDoc['text'] ?? '',
        'senderId': messageDoc['senderId'] ?? '',
      };
    } catch (e) {
      debugPrint('Error fetching last message: $e');
      return null;
    }
  }

  Future<Map<String, Timestamp>> _getRecentChatTimestamps(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recent_chats')
          .get();

      Map<String, Timestamp> recentChats = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final withUserId = data['withUserId'] ?? '';
        final timestamp = data['timestamp'] as Timestamp?;
        if (withUserId.isNotEmpty && timestamp != null) {
          recentChats[withUserId] = timestamp;
        }
      }
      return recentChats;
    } catch (e) {
      debugPrint('Error fetching recent chat timestamps: $e');
      return {};
    }
  }
}
