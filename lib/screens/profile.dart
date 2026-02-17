import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      };

      _nameController.text = _originalValues['name']!;
      _bioController.text = _originalValues['bio']!;
      _phoneController.text = _originalValues['phoneNumber']!;
    });
  }

  void _checkChanges() {
    final changed = _nameController.text.trim() != _originalValues['name'] ||
        _bioController.text.trim() != _originalValues['bio'] ||
        _phoneController.text.trim() != _originalValues['phoneNumber'];

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
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _auth.currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
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
                                offset: const Offset(0, 8))
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
                                      data['photoURL']
                                          .toString()
                                          .isNotEmpty)
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
                                        color: Colors.blue),
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
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                                // Edit icon on avatar
                                if (isOwnProfile)
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
                            Text(
                              data['email'] ?? "",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 5),
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
                              style: const TextStyle(
                                  color: Colors.blue),
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
                            _infoRow(Icons.calendar_today, "Member since",
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
                    ],
                  ),
                ),
              ),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Row(
                    children: [
                      const SizedBox(width:16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text("Save Changes"),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
