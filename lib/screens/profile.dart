import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Edit mode
  bool _isEditing = false;

  // Controller for username
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(String userId) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final newName = _nameController.text.trim();

      if (newName.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        _showSnackBar('Name cannot be empty', Colors.red);
        return;
      }

      // Update Firestore
      await _firestore.collection('users').doc(userId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth profile
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
      }

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        _isEditing = false;
      });

      _showSnackBar('Username updated successfully!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Error updating username: $e', Colors.red);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = _auth.currentUser?.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Username' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isCurrentUser && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing) ...[
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _saveProfile(widget.userId),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final currentUser = _auth.currentUser;

          // Initialize controller with user data
          if (!_isEditing) {
            _nameController.text = userData['name'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Profile Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue[50],
                        backgroundImage: userData['photoURL'] != null
                            ? NetworkImage(userData['photoURL'])
                            : null,
                        child: userData['photoURL'] == null
                            ? Text(
                          (userData['name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Username field (editable)
                      if (!_isEditing)
                        Text(
                          _nameController.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'Enter your username',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Email (non-editable)
                      Text(
                        userData['email'] ?? 'No Email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Bio (non-editable, display only)
                      if (userData['bio'] != null && userData['bio'].toString().isNotEmpty)
                        Text(
                          userData['bio'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Profile Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Member Since',
                        value: _formatDate(userData['createdAt']),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: 'Last Active',
                        value: userData['isOnline'] == true
                            ? 'Online'
                            : _formatDate(userData['lastSeen']),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: userData['phoneNumber'] ?? 'Not provided',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Delete Account Button (only for current user)
                if (currentUser?.uid == widget.userId && !_isEditing)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showDeleteConfirmation,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action will permanently delete your account and all associated data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Delete user document from Firestore
      await _firestore.collection('users').doc(currentUser.uid).delete();

      // Delete user from Firebase Auth
      await currentUser.delete();

      // Sign out
      await _auth.signOut();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted: $e')),
        );
      }
    }
  }
}