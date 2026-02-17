import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEditing = false;
  bool _hasChanges = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  DateTime? _memberSinceDate; // Add this for member since date

  // store original values
  Map<String, dynamic> _originalValues = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getInitial(String? name) {
    if (name == null || name.trim().isEmpty) return "U";
    return name.trim()[0].toUpperCase();
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    final date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  void _startEditing(Map<String, dynamic> data) {
    setState(() {
      _isEditing = true;
      _hasChanges = false;

      // save original values
      _originalValues = {
        "name": data['name'] ?? "",
        "bio": data['bio'] ?? "",
        "phoneNumber": data['phoneNumber'] ?? "",
        "createdAt": data['createdAt'],
      };

      _nameController.text = _originalValues['name']!;
      _bioController.text = _originalValues['bio']!;
      _phoneController.text = _originalValues['phoneNumber']!;
      _memberSinceDate = (data['createdAt'] as Timestamp?)?.toDate();
    });
  }

  void _checkChanges() {
    final changed = _nameController.text.trim() != _originalValues['name'] ||
        _bioController.text.trim() != _originalValues['bio'] ||
        _phoneController.text.trim() != _originalValues['phoneNumber'] ||
        _memberSinceDate != (_originalValues['createdAt'] as Timestamp?)?.toDate();

    if (_hasChanges != changed) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _hasChanges = false;

      // revert to original values
      _nameController.text = _originalValues['name']!;
      _bioController.text = _originalValues['bio']!;
      _phoneController.text = _originalValues['phoneNumber']!;
      _memberSinceDate = (_originalValues['createdAt'] as Timestamp?)?.toDate();
    });
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      _cancelEditing(); // if nothing changed, just cancel
      return;
    }

    Map<String, dynamic> updates = {};

    if (_nameController.text.trim() != _originalValues['name']) {
      updates['name'] = _nameController.text.trim();
    }
    if (_bioController.text.trim() != _originalValues['bio']) {
      updates['bio'] = _bioController.text.trim();
    }
    if (_phoneController.text.trim() != _originalValues['phoneNumber']) {
      updates['phoneNumber'] = _phoneController.text.trim();
    }
    if (_memberSinceDate != (_originalValues['createdAt'] as Timestamp?)?.toDate()) {
      updates['createdAt'] = Timestamp.fromDate(_memberSinceDate!);
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(widget.userId).update(updates);

      setState(() {
        _isEditing = false;
        _hasChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
    } else {
      _cancelEditing(); // no updates, just cancel
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _memberSinceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _memberSinceDate) {
      setState(() {
        _memberSinceDate = picked;
        _checkChanges();
      });
    }
  }

  InputDecoration _modernInput(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Text(title),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _editableDateRow(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _selectDate,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 10),
            Text(title),
            const Spacer(),
            Text(
              _memberSinceDate != null
                  ? "${_memberSinceDate!.day}/${_memberSinceDate!.month}/${_memberSinceDate!.year}"
                  : "Select date",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _auth.currentUser?.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Profile' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isOwnProfile && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Get current data and start editing
                _firestore.collection('users').doc(widget.userId).get().then((doc) {
                  if (doc.exists) {
                    _startEditing(doc.data() as Map<String, dynamic>);
                  }
                });
              },
            ),
          if (_isEditing) ...[
            TextButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _hasChanges ? _saveChanges : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasChanges ? Colors.blue : Colors.grey[300],
                foregroundColor: _hasChanges ? Colors.white : Colors.grey[600],
              ),
              child: const Text('Save'),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 15,
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: (data['photoURL'] != null &&
                                data['photoURL'].toString().isNotEmpty)
                                ? NetworkImage(data['photoURL'])
                                : null,
                            child: (data['photoURL'] == null ||
                                data['photoURL'].toString().isEmpty)
                                ? Text(
                              _getInitial(_isEditing
                                  ? _nameController.text
                                  : data['name']),
                              style: const TextStyle(
                                fontSize: 45,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            )
                                : null,
                          ),
                          // Online indicator
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: data['isOnline'] == true
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          // Edit icon on avatar
                          if (isOwnProfile && !_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  _startEditing(data);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name
                      _isEditing
                          ? TextField(
                        controller: _nameController,
                        onChanged: (_) => _checkChanges(),
                        decoration: _modernInput("Name"),
                      )
                          : Text(
                        data['name'] ?? "No Name",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Email
                      Text(
                        data['email'] ?? "",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 5),

                      // Online status
                      Text(
                        data['isOnline'] == true
                            ? "Online"
                            : "Last seen ${_formatDate(data['lastSeen'])}",
                        style: TextStyle(
                          color: data['isOnline'] == true
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Bio
                      _isEditing
                          ? TextField(
                        controller: _bioController,
                        maxLines: 2,
                        onChanged: (_) => _checkChanges(),
                        decoration: _modernInput("Bio"),
                      )
                          : Text(
                        data['bio']?.isNotEmpty == true
                            ? data['bio']
                            : "Add bio",
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _isEditing
                          ? _editableDateRow(Icons.calendar_today, "Member since")
                          : _infoRow(Icons.calendar_today, "Member since",
                          _formatDate(data['createdAt'])),
                      const Divider(),
                      _isEditing
                          ? TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => _checkChanges(),
                        decoration: _modernInput("Phone Number"),
                      )
                          : _infoRow(
                        Icons.phone,
                        "Phone",
                        data['phoneNumber']?.isNotEmpty == true
                            ? data['phoneNumber']
                            : "Not provided",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Delete Account Button (only for current user)
                if (isOwnProfile && !_isEditing)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }
}