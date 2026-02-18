import 'package:chatting_app/screens/profile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../model/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state with default values
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkModeEnabled = false;
  bool _onlineStatusVisible = true;
  String _language = 'English';
  String _theme = 'Light';

  // User data
  AppUser? _currentUser;

  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadPreferences();
  }

  Future<void> _loadUserData() async {
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

  Future<void> _loadPreferences() async {
    // Load from SharedPreferences or Firestore
    // For now, using default values
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading
  }

  Future<void> _logout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          );
        },
      );

      if (confirm == true && mounted) {
        await authService.logout();
        // Navigation will be handled by auth state listener
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                leading: Radio<String>(
                  value: 'English',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Language changed to English');
                  },
                ),
              ),
              ListTile(
                title: const Text('Spanish'),
                leading: Radio<String>(
                  value: 'Spanish',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Language changed to Spanish');
                  },
                ),
              ),
              ListTile(
                title: const Text('French'),
                leading: Radio<String>(
                  value: 'French',
                  groupValue: _language,
                  onChanged: (value) {
                    setState(() {
                      _language = value!;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Language changed to French');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Light'),
                leading: Radio<String>(
                  value: 'Light',
                  groupValue: _theme,
                  onChanged: (value) {
                    setState(() {
                      _theme = value!;
                      _darkModeEnabled = false;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Light theme applied');
                  },
                ),
              ),
              ListTile(
                title: const Text('Dark'),
                leading: Radio<String>(
                  value: 'Dark',
                  groupValue: _theme,
                  onChanged: (value) {
                    setState(() {
                      _theme = value!;
                      _darkModeEnabled = true;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Dark theme applied');
                  },
                ),
              ),
              ListTile(
                title: const Text('System Default'),
                leading: Radio<String>(
                  value: 'System',
                  groupValue: _theme,
                  onChanged: (value) {
                    setState(() {
                      _theme = value!;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('System theme applied');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _updateNotificationSettings() async {
    try {
      final notificationService = NotificationService();

      if (_notificationsEnabled) {
        if (_currentUser != null) {
          await notificationService.subscribeToUser(_currentUser!.uid);
        }
      } else {
        if (_currentUser != null) {
          await notificationService.unsubscribeFromUser(_currentUser!.uid);
        }
      }

      _showSuccessMessage('Notification settings updated');
    } catch (e) {
      _showErrorMessage('Failed to update notification settings');
    }
  }

  void _showChangePasswordDialog() {
    final _oldPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _oldPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_newPasswordController.text == _confirmPasswordController.text) {
                  Navigator.pop(context);
                  _showSuccessMessage('Password changed successfully');
                } else {
                  _showErrorMessage('Passwords do not match');
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showBlockedUsers() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Blocked Users',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('No blocked users'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChatWallpaperDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chat Wallpaper'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Default'),
                leading: Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[200],
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessMessage('Wallpaper changed to default');
                },
              ),
              ListTile(
                title: const Text('Solid Colors'),
                leading: Container(
                  width: 40,
                  height: 40,
                  color: Colors.blue,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessMessage('Wallpaper changed');
                },
              ),
              ListTile(
                title: const Text('Choose from Gallery'),
                leading: const Icon(Icons.image),
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessMessage('Feature coming soon');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Font Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('Small'),
                value: 1,
                groupValue: 2,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Font size changed');
                },
              ),
              RadioListTile<int>(
                title: const Text('Normal'),
                value: 2,
                groupValue: 2,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Font size changed');
                },
              ),
              RadioListTile<int>(
                title: const Text('Large'),
                value: 3,
                groupValue: 2,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Font size changed');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStorageUsage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Storage Usage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(value: 0.3),
              const SizedBox(height: 16),
              const Text('Used: 150 MB of 500 MB'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessMessage('Cache cleared successfully');
                },
                child: const Text('Clear Cache'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAutoDownloadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Auto-download Media'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('Never'),
                value: 0,
                groupValue: 1,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Auto-download set to Never');
                },
              ),
              RadioListTile<int>(
                title: const Text('Wi-Fi Only'),
                value: 1,
                groupValue: 1,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Auto-download set to Wi-Fi Only');
                },
              ),
              RadioListTile<int>(
                title: const Text('Wi-Fi and Cellular'),
                value: 2,
                groupValue: 1,
                onChanged: (value) {
                  Navigator.pop(context);
                  _showSuccessMessage('Auto-download set to Wi-Fi and Cellular');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help Center'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Frequently Asked Questions:'),
              SizedBox(height: 8),
              Text('• How to send messages?'),
              Text('• How to block users?'),
              Text('• How to change password?'),
              Text('• How to enable notifications?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showFeedbackDialog() {
    final _feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Feedback'),
          content: TextField(
            controller: _feedbackController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Tell us how we can improve...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage('Thank you for your feedback!');
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Firebase Chat',
      applicationVersion: 'Version 1.0.0',
      applicationIcon: const Icon(Icons.chat, size: 50),
      applicationLegalese: '© 2024 Your Company',
      children: [
        const SizedBox(height: 16),
        const Text('A real-time chat application built with Flutter and Firebase.'),
        const SizedBox(height: 8),
        const Text('Features:'),
        const Text('• Real-time messaging'),
        const Text('• User authentication'),
        const Text('• Push notifications'),
        const Text('• User profiles'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile Section
          if (_currentUser != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: _currentUser!.photoURL != null
                        ? NetworkImage(_currentUser!.photoURL!)
                        : null,
                    backgroundColor: Colors.blue[100],
                    child: _currentUser!.photoURL == null
                        ? Text(
                      _currentUser!.displayName.isNotEmpty
                          ? _currentUser!.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.blue),
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.displayName.isNotEmpty
                              ? _currentUser!.displayName
                              : 'Unknown User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser!.email.isNotEmpty
                              ? _currentUser!.email
                              : 'No email',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      ).then((_) => _loadUserData());
                    },
                  ),
                ],
              ),
            ),

          const Divider(),

          // Account Settings
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            subtitle: 'Change your name and profile picture',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              ).then((_) => _loadUserData());
            },
          ),
          _buildSettingsTile(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: _currentUser?.email ?? 'Loading...',
            showArrow: false,
          ),
          _buildSettingsTile(
            icon: Icons.password_outlined,
            title: 'Change Password',
            subtitle: 'Update your password',
            onTap: _showChangePasswordDialog,
          ),

          const Divider(),

          // Notifications Settings
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _updateNotificationSettings();
            },
          ),
          _buildSwitchTile(
            icon: Icons.volume_up_outlined,
            title: 'Sound',
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
            },
            enabled: _notificationsEnabled,
          ),
          _buildSwitchTile(
            icon: Icons.vibration,
            title: 'Vibration',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
            },
            enabled: _notificationsEnabled,
          ),

          const Divider(),

          // Privacy Settings
          _buildSectionHeader('Privacy'),
          _buildSwitchTile(
            icon: Icons.visibility_outlined,
            title: 'Show Online Status',
            value: _onlineStatusVisible,
            onChanged: (value) {
              setState(() {
                _onlineStatusVisible = value;
              });
              _showSuccessMessage('Online status updated');
            },
          ),
          _buildSettingsTile(
            icon: Icons.block_outlined,
            title: 'Blocked Users',
            subtitle: 'Manage blocked contacts',
            onTap: _showBlockedUsers,
          ),

          const Divider(),

          // Appearance
          _buildSectionHeader('Appearance'),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: _language,
            onTap: _showLanguageDialog,
          ),
          _buildSettingsTile(
            icon: _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
            title: 'Theme',
            subtitle: _theme,
            onTap: _showThemeDialog,
          ),
          _buildSwitchTile(
            icon: Icons.nightlight_round,
            title: 'Dark Mode',
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
                _theme = value ? 'Dark' : 'Light';
              });
            },
          ),

          const Divider(),

          // Chat Settings
          _buildSectionHeader('Chat'),
          _buildSettingsTile(
            icon: Icons.wallpaper_outlined,
            title: 'Chat Wallpaper',
            subtitle: 'Change chat background',
            onTap: _showChatWallpaperDialog,
          ),
          _buildSettingsTile(
            icon: Icons.font_download_outlined,
            title: 'Font Size',
            subtitle: 'Normal',
            onTap: _showFontSizeDialog,
          ),
          _buildSwitchTile(
            icon: Icons.send_outlined,
            title: 'Send with Enter',
            value: true,
            onChanged: (value) {
              _showSuccessMessage('Setting updated');
            },
          ),

          const Divider(),

          // Storage & Data
          _buildSectionHeader('Storage & Data'),
          _buildSettingsTile(
            icon: Icons.storage_outlined,
            title: 'Storage Usage',
            subtitle: 'Manage cached files',
            onTap: _showStorageUsage,
          ),
          _buildSettingsTile(
            icon: Icons.download_outlined,
            title: 'Auto-download Media',
            subtitle: 'Wi-Fi only',
            onTap: _showAutoDownloadDialog,
          ),

          const Divider(),

          // Support
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            subtitle: 'Get help and support',
            onTap: _showHelpCenter,
          ),
          _buildSettingsTile(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Help us improve',
            onTap: _showFeedbackDialog,
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: _showAboutDialog,
          ),

          const Divider(),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}