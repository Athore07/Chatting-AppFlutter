import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/safe_avatar.dart';
import '../../widgets/message_bubble.dart';
import '../model/message_model.dart';
import '../model/user_model.dart';

class ChatScreen extends StatefulWidget {
  final AppUser currentUser;
  final AppUser otherUser;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isOtherUserOnline = false;
  bool _isTyping = false;
  bool _isEmojiPickerVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupTypingListener();
    _updateUserOnlineStatus(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _updateUserOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      _updateUserOnlineStatus(true);
      _markMessagesAsRead();
    }
  }

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.updateUserOnlineStatus(widget.currentUser.uid, isOnline);
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        setState(() => _isTyping = true);
        _sendTypingStatus(true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        setState(() => _isTyping = false);
        _sendTypingStatus(false);
      }
    });
  }

  Future<void> _sendTypingStatus(bool isTyping) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.sendTypingStatus(
        widget.currentUser.uid,
        widget.otherUser.uid,
        isTyping,
      );
    } catch (e) {
      print('Error sending typing status: $e');
    }
  }

  Future<void> _initializeChat() async {
    _checkOnlineStatus();
    await _markMessagesAsRead();
  }

  void _checkOnlineStatus() {
    setState(() {
      _isOtherUserOnline = widget.otherUser.isOnline ?? false;
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.markAllAsRead(
        widget.currentUser.uid,
        widget.otherUser.uid,
      );
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final notificationService = NotificationService();

      final message = Message(
        senderId: widget.currentUser.uid,
        receiverId: widget.otherUser.uid,
        text: text,
        timestamp: DateTime.now(),
        isRead: false,
        chatId: '${widget.currentUser.uid}_${widget.otherUser.uid}',
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await chatService.sendMessage(message);

      // Send push notification
      if (widget.otherUser.fcmToken != null) {
        await notificationService.sendNotification(
          token: widget.otherUser.fcmToken!,
          title: widget.currentUser.displayName,
          body: text,
          data: {
            'type': 'message',
            'senderId': widget.currentUser.uid,
            'receiverId': widget.otherUser.uid,
          },
        );
      }

      _messageController.clear();
      _scrollToBottom();

      if (_isEmojiPickerVisible) {
        setState(() => _isEmojiPickerVisible = false);
      }

    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
      if (_isEmojiPickerVisible) {
        _focusNode.unfocus();
        _animationController.forward();
      } else {
        _focusNode.requestFocus();
        _animationController.reverse();
      }
    });
  }

  void _onEmojiSelected(emoji.Emoji emoji) {
    _messageController.text = _messageController.text + emoji.emoji;
  }

  void _onBackspacePressed() {
    if (_messageController.text.isNotEmpty) {
      _messageController.text = _messageController.text
          .substring(0, _messageController.text.length - 1);
    }
  }

  String _getDisplayName(AppUser user) {
    if (user.displayName.isNotEmpty) return user.displayName;

    final emailParts = user.email.split('@');
    if (emailParts.isNotEmpty) {
      return emailParts[0]
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .split(' ')
          .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
          : '')
          .join(' ');
    }
    return 'User';
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Online';
    } else if (difference.inHours < 1) {
      return 'Last seen ${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} h ago';
    } else {
      return 'Last seen ${lastSeen.day}/${lastSeen.month}';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.otherUser.photoURL != null
                        ? NetworkImage(widget.otherUser.photoURL!)
                        : null,
                    child: widget.otherUser.photoURL == null
                        ? Text(
                      _getDisplayName(widget.otherUser)[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getDisplayName(widget.otherUser),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.otherUser.email,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isOtherUserOnline
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOtherUserOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOtherUserOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOtherUserOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.otherUser.status != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.otherUser.status!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBlockUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Block ${_getDisplayName(widget.otherUser)}?',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will no longer receive messages from ${_getDisplayName(widget.otherUser)}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context); // Return to users screen
                          _showSuccessSnackBar('User blocked successfully');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Block'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep, color: Colors.orange, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Clear Chat',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will delete all messages. This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSuccessSnackBar('Chat cleared successfully');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
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
                const Text(
                  'Search Messages',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter search term...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSuccessSnackBar('Searching for: ${searchController.text}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Provider.of<ChatService>(context);

    return GestureDetector(
      onTap: () {
        if (_isEmojiPickerVisible) {
          setState(() => _isEmojiPickerVisible = false);
        }
        _focusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Row(
            children: [
              // User avatar with online indicator
              Stack(
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
                      imageUrl: widget.otherUser.photoURL,
                      name: _getDisplayName(widget.otherUser),
                      radius: 18,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: _isOtherUserOnline
                            ? const LinearGradient(
                          colors: [Colors.green, Colors.lightGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: _isOtherUserOnline ? null : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // User name and typing status
              Expanded(
                child: StreamBuilder<bool>(
                  stream: chatService.getTypingStatus(
                    widget.otherUser.uid,
                    widget.currentUser.uid,
                  ),
                  builder: (context, snapshot) {
                    final isTyping = snapshot.data ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplayName(widget.otherUser),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTyping ? 'Typing...' : _formatLastSeen(widget.otherUser.lastSeen),
                          style: TextStyle(
                            fontSize: 12,
                            color: isTyping ? Colors.yellow : Colors.white70,
                            fontWeight: isTyping ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            // Search button
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: _showSearchDialog,
                tooltip: 'Search messages',
              ),
            ),

            // More options menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'view_profile':
                    _showUserProfile();
                    break;
                  case 'block':
                    _showBlockUserDialog();
                    break;
                  case 'clear':
                    _showClearChatDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Block User'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        body: Column(
          children: [
            // Messages list
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: chatService.getMessages(
                  widget.currentUser.uid,
                  widget.otherUser.uid,
                ),
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Say hello to ${_getDisplayName(widget.otherUser)}!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!;

                  // Mark messages as read
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    for (var message in messages) {
                      if (!message.isRead && message.receiverId == widget.currentUser.uid) {
                        chatService.markAsRead(message.id, message.chatId);
                      }
                    }
                  });

                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == widget.currentUser.uid;
                      final showAvatar = !isMe && (index == 0 ||
                          messages[index - 1].senderId != message.senderId);

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        showAvatar: showAvatar,
                        otherUser: widget.otherUser,
                      );
                    },
                  );
                },
              ),
            ),

            // Emoji Picker - FIXED VERSION
            if (_isEmojiPickerVisible)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: emoji.EmojiPicker(
                    onEmojiSelected: (emoji.Category? category, emoji.Emoji? selectedEmoji) {
                      if (selectedEmoji != null) {
                        _onEmojiSelected(selectedEmoji);
                      }
                    },
                    onBackspacePressed: _onBackspacePressed,
                    config: const emoji.Config(
                      height: 256,
                      emojiViewConfig: emoji.EmojiViewConfig(
                        columns: 7,
                        emojiSizeMax: 28,
                      ),
                      categoryViewConfig: emoji.CategoryViewConfig(
                        initCategory: emoji.Category.RECENT,
                      ),
                      bottomActionBarConfig: emoji.BottomActionBarConfig(
                        showBackspaceButton: true,

                      ),
                      skinToneConfig: emoji.SkinToneConfig(
                        dialogBackgroundColor: Colors.white,
                        indicatorColor: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

            // Message input field
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji button
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isEmojiPickerVisible
                            ? [Colors.blue, Colors.purple]
                            : [Colors.grey[300]!, Colors.grey[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isEmojiPickerVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
                        color: Colors.white,
                      ),
                      onPressed: _toggleEmojiPicker,
                      tooltip: _isEmojiPickerVisible ? 'Show keyboard' : 'Show emoji',
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text field
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      constraints: const BoxConstraints(maxHeight: 100),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () {
                          if (_isEmojiPickerVisible) {
                            setState(() => _isEmojiPickerVisible = false);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: _messageController.text.trim().isEmpty
                          ? LinearGradient(
                        colors: [Colors.grey[300]!, Colors.grey[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                          : const LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (_messageController.text.trim().isNotEmpty)
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    _updateUserOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}