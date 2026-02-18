import 'package:chatting_app/screens/chart.dart';
import 'package:chatting_app/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/safe_avatar.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';  // Add this import

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  AppUser? _currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  // Track users with their last message time
  final Map<String, DateTime?> _userLastMessageTime = {};

  // List of vibrant colors for avatars
  final List<Color> _avatarColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
    Colors.red,
    Colors.lightGreen,
    Colors.deepPurple,
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _setupSearchListener();
  }

  Future<void> _loadCurrentUser() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // Get color for user based on their ID
  Color _getUserColor(String userId) {
    if (userId.isEmpty) return Colors.blue;
    final hash = userId.hashCode.abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  // Get display name - either from displayName or from email
  String _getDisplayName(AppUser user) {
    if (user.displayName.isNotEmpty) {
      return user.displayName;
    }
    final emailParts = user.email.split('@');
    if (emailParts.isNotEmpty) {
      final namePart = emailParts[0];
      return namePart
          .replaceAll('_', ' ')
          .replaceAll('.', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
          : '')
          .join(' ');
    }
    return 'Unknown User';
  }

  // Get first character for avatar
  String _getAvatarLetter(AppUser user) {
    if (user.displayName.isNotEmpty) {
      return user.displayName[0].toUpperCase();
    }
    if (user.email.isNotEmpty) {
      return user.email[0].toUpperCase();
    }
    return '?';
  }

  // Format last message time
  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  // Truncate message for preview
  String _truncateMessage(String message, {int maxLength = 35}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  // Get message preview text with sender indicator
  String _getMessagePreview(Message message, String currentUserId) {
    final isMe = message.senderId == currentUserId;
    final preview = _truncateMessage(message.text);
    return isMe ? 'You: $preview' : preview;
  }

  // Sort users by last message time (most recent first)
  List<AppUser> _sortUsersByRecent(List<AppUser> users) {
    // Create a copy of the list
    final sortedUsers = List<AppUser>.from(users);

    // Sort: users with messages appear first, then sort by last message time
    sortedUsers.sort((a, b) {
      final timeA = _userLastMessageTime[a.uid];
      final timeB = _userLastMessageTime[b.uid];

      // If both have messages, sort by time (most recent first)
      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      }
      // If only A has messages, A comes first
      if (timeA != null && timeB == null) return -1;
      // If only B has messages, B comes first
      if (timeA == null && timeB != null) return 1;
      // If neither has messages, sort alphabetically
      return _getDisplayName(a).compareTo(_getDisplayName(b));
    });

    return sortedUsers;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCurrentUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Unable to load user data. Please login again.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Current user profile badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SafeAvatar(
                  imageUrl: _currentUser!.photoURL,
                  name: _getDisplayName(_currentUser!),
                  radius: 14,
                  backgroundColor: _getUserColor(_currentUser!.uid),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _getDisplayName(_currentUser!).split(' ').first,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadCurrentUser());
            },
            tooltip: 'Settings',
          ),

          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, authService),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () => _searchController.clear(),
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),

          // Users list with chat previews
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _searchQuery.isEmpty
                  ? chatService.getUsers(_currentUser!.uid)
                  : chatService.searchUsers(_searchQuery, _currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isEmpty
                                ? Icons.person_outline
                                : Icons.search_off,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No users matching "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () => _searchController.clear(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                            child: const Text('Clear search'),
                          ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!;

                // Clear old last message times
                _userLastMessageTime.clear();

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userColor = _getUserColor(user.uid);

                    return StreamBuilder<Message?>(
                      stream: chatService.getLastMessage(
                        _currentUser!.uid,
                        user.uid,
                      ),
                      builder: (context, messageSnapshot) {
                        final lastMessage = messageSnapshot.data;
                        final hasLastMessage = lastMessage != null;
                        final hasRecentMessage = hasLastMessage;

                        // Update last message time in map
                        if (hasLastMessage && mounted) {
                          _userLastMessageTime[user.uid] = lastMessage.timestamp;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    currentUser: _currentUser!,
                                    otherUser: user,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Avatar with color and online indicator
                                  Stack(
                                    children: [
                                      SafeAvatar(
                                        imageUrl: user.photoURL,
                                        name: _getDisplayName(user),
                                        radius: 30,
                                        backgroundColor: userColor,
                                      ),
                                      // Online indicator
                                      if (user.isOnline == true)
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
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
                                  const SizedBox(width: 12),

                                  // User info and last message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Display name with recent indicator
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _getDisplayName(user),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: hasRecentMessage
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  color: hasRecentMessage
                                                      ? Colors.black87
                                                      : Colors.grey[700],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (hasRecentMessage)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        // Last message preview
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                hasLastMessage
                                                    ? _getMessagePreview(lastMessage, _currentUser!.uid)
                                                    : 'Tap to start chatting',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: hasLastMessage
                                                      ? Colors.grey[700]
                                                      : Colors.grey[500],
                                                  fontStyle: hasLastMessage
                                                      ? FontStyle.normal
                                                      : FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Time and unread indicator
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (hasLastMessage)
                                        Text(
                                          _formatMessageTime(lastMessage.timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasRecentMessage
                                                ? Colors.blue
                                                : Colors.grey[500],
                                            fontWeight: hasRecentMessage
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await authService.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}