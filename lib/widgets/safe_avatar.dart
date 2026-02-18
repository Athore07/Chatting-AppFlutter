import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const SafeAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // If no image URL, show initials
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildInitialsAvatar();
    }

    // Try to load image with error handling
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsAvatar(),
          errorWidget: (context, url, error) {
            print('Error loading image: $error for URL: $url');
            return _buildInitialsAvatar();
          },
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _getColorFromName(name ?? ''),
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: radius * 0.6,
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';

    // Get first letter of first word
    final words = name.trim().split(' ');
    if (words.isEmpty) return '?';

    final firstWord = words.first;
    if (firstWord.isEmpty) return '?';

    return firstWord[0].toUpperCase();
  }

  Color _getColorFromName(String name) {
    if (name.isEmpty) return Colors.blue;

    // Generate consistent color based on name
    final hash = name.hashCode.abs();
    final colors = [
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
      Colors.red,
    ];
    return colors[hash % colors.length];
  }
}