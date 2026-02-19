import 'package:chatting_app/screens/chart.dart';
import 'package:chatting_app/screens/login.dart';
import 'package:chatting_app/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/safe_avatar.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  AppUser? _currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Track users with their last message time
  final Map<String, DateTime?> _userLastMessageTime = {};

  // List of vibrant gradient colors for avatars
  final List<List<Color>> _avatarGradients = [
    [const Color(0xFF4158D0), const Color(0xFFC850C0)],
    [const Color(0xFF0093E9), const Color(0xFF80D0C7)],
    [const Color(0xFF8EC5FC), const Color(0xFFE0C3FC)],
    [const Color(0xFFFA8BFF), const Color(0xFF2BD2FF)],
    [const Color(0xFFFF9A8B), const Color(0xFFFF6A88)],
    [const Color(0xFFA9C9FF), const Color(0xFFFFBBEC)],
    [const Color(0xFF85A8F9), const Color(0xFF9D7BFA)],
    [const Color(0xFFFBAB7E), const Color(0xFFF7CE68)],
    [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
    [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    [const Color(0xFFFDC830), const Color(0xFFF37335)],
    [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
    [const Color(0xFF36D1DC), const Color(0xFF5B86E5)],
    [const Color(0xFFAA076B), const Color(0xFF61045F)],
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
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

  // Get gradient for user based on their ID
  List<Color> _getUserGradient(String userId) {
    if (userId.isEmpty) return _avatarGradients[0];
    final hash = userId.hashCode.abs();
    return _avatarGradients[hash % _avatarGradients.length];
  }

  // Get display name
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

  // Enhanced time formatting - shows actual time after 1 hour
  String _formatMessageTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      // Show actual time after 1 hour
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  // Truncate message
  String _truncateMessage(String message, {int maxLength = 35}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  // Get message preview
  String _getMessagePreview(Message message, String currentUserId) {
    final isMe = message.senderId == currentUserId;
    final preview = _truncateMessage(message.text);
    return isMe ? 'You: $preview' : preview;
  }

  // Sort users by recent activity
  List<AppUser> _sortUsersByRecent(List<AppUser> users) {
    final sortedUsers = List<AppUser>.from(users);
    sortedUsers.sort((a, b) {
      final timeA = _userLastMessageTime[a.uid];
      final timeB = _userLastMessageTime[b.uid];

      if (timeA != null && timeB != null) {
        return timeB.compareTo(timeA);
      }
      if (timeA != null && timeB == null) return -1;
      if (timeA == null && timeB != null) return 1;
      return _getDisplayName(a).compareTo(_getDisplayName(b));
    });
    return sortedUsers;
  }

  // Beautiful dialog components
  Widget _buildLogoutDialog(BuildContext context, AuthService authService) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF5F5F5)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.redAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.logout, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            const Text(
              'Logout',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await authService.logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 60, color: Colors.red),
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadCurrentUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[50]!, Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Loading Chats...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey[50]!, Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_off, size: 60, color: Colors.orange),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unable to load user data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please login again',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Login Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[50]!, Colors.white],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Reduced App Bar with first character only
            SliverAppBar(
              expandedHeight: 80, // Reduced from 120
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 12), // Reduced bottom padding
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: SafeAvatar(
                        imageUrl: _currentUser!.photoURL,
                        name: _getDisplayName(_currentUser!),
                        radius: 15, // Slightly reduced
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getDisplayName(_currentUser!).isNotEmpty
                          ? _getDisplayName(_currentUser!)
                          : 'U',
                      style: const TextStyle(
                        fontSize: 16, // Slightly reduced
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      ).then((_) => _loadCurrentUser());
                    },
                    tooltip: 'Settings',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => _buildLogoutDialog(context, authService),
                    ),
                    tooltip: 'Logout',
                  ),
                ),
              ],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.purple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.search, color: Colors.white, size: 20),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ),
            ),

            // Users List
            SliverFillRemaining(
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
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline, size: 50, color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          Text('Error: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _searchQuery.isEmpty ? Icons.person_outline : Icons.search_off,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No users found'
                                : 'No users matching "$_searchQuery"',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                  _userLastMessageTime.clear();

                  return FutureBuilder(
                    future: Future.wait(
                      users.map((user) async {
                        try {
                          final lastMessage = await chatService.getLastMessage(
                            _currentUser!.uid,
                            user.uid,
                          ).first;

                          if (lastMessage != null && mounted) {
                            _userLastMessageTime[user.uid] = lastMessage.timestamp;
                          }
                        } catch (e) {
                          print('Error loading last message for ${user.uid}: $e');
                        }
                        return user;
                      }),
                    ),
                    builder: (context, futureSnapshot) {
                      final sortedUsers = _sortUsersByRecent(users);

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: sortedUsers.length,
                        itemBuilder: (context, index) {
                          final user = sortedUsers[index];
                          final userGradient = _getUserGradient(user.uid);
                          final hasRecentMessage = _userLastMessageTime.containsKey(user.uid);

                          return StreamBuilder<Message?>(
                            stream: chatService.getLastMessage(
                              _currentUser!.uid,
                              user.uid,
                            ),
                            builder: (context, messageSnapshot) {
                              final lastMessage = messageSnapshot.data;
                              final hasLastMessage = lastMessage != null;

                              if (hasLastMessage && mounted) {
                                _userLastMessageTime[user.uid] = lastMessage.timestamp;
                              }

                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
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
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            // Avatar with gradient and online indicator
                                            Stack(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: userGradient,
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: SafeAvatar(
                                                    imageUrl: user.photoURL,
                                                    name: _getDisplayName(user),
                                                    radius: 28,
                                                    backgroundColor: Colors.white,
                                                  ),
                                                ),
                                                if (user.isOnline == true)
                                                  Positioned(
                                                    bottom: 2,
                                                    right: 2,
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        gradient: const LinearGradient(
                                                          colors: [Colors.green, Colors.lightGreen],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
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
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
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
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: hasRecentMessage
                                                          ? Colors.blue.withOpacity(0.1)
                                                          : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
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
                                                  ),
                                                const SizedBox(height: 4),
                                                if (hasLastMessage &&
                                                    !lastMessage.isRead &&
                                                    lastMessage.receiverId == _currentUser!.uid)
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Colors.blue, Colors.purple],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.blue.withOpacity(0.3),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}