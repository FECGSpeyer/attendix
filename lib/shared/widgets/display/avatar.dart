import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar widget that displays a person's image or initials
///
/// Shows a circular avatar with either:
/// - A cached network image if imageUrl is provided
/// - Initials (first letter of firstName + lastName) as fallback
class Avatar extends StatelessWidget {
  final String? imageUrl;
  final String firstName;
  final String lastName;
  final double size;

  const Avatar({
    super.key,
    this.imageUrl,
    required this.firstName,
    required this.lastName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    // Show network image if available
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          backgroundImage: imageProvider,
          radius: size / 2,
        ),
        placeholder: (context, url) => _buildInitials(context),
        errorWidget: (context, url, error) => _buildInitials(context),
      );
    }

    // Fallback to initials
    return _buildInitials(context);
  }

  Widget _buildInitials(BuildContext context) {
    final initials = _getInitials();
    final theme = Theme.of(context);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  String _getInitials() {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// IOS_THEME2: Ionic `assets/icon/avatar-placeholder.svg` – grey disc
/// (#c7c9cc) with a light (#f4f5f6) head and shoulders. Ionic shows it for
/// people without a picture (`player.img || 'assets/icon/avatar-placeholder.svg'`)
/// in light and dark mode.
class IonAvatarPlaceholder extends StatelessWidget {
  const IonAvatarPlaceholder({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const ClipOval(
          child: CustomPaint(painter: _AvatarPlaceholderPainter()),
        ),
      );
}

class _AvatarPlaceholderPainter extends CustomPainter {
  const _AvatarPlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // viewBox 0 0 128 128
    canvas.scale(size.shortestSide / 128);
    canvas.drawCircle(
        const Offset(64, 64), 64, Paint()..color = const Color(0xFFC7C9CC));
    final light = Paint()..color = const Color(0xFFF4F5F6);
    canvas.drawCircle(const Offset(64, 50), 24, light);
    // M64 82c-24 0-42 14-46 34a64 64 0 0 0 92 0c-4-20-22-34-46-34z
    final body = Path()
      ..moveTo(64, 82)
      ..cubicTo(40, 82, 22, 96, 18, 116)
      ..arcToPoint(const Offset(110, 116),
          radius: const Radius.circular(64), clockwise: false)
      ..cubicTo(106, 96, 88, 82, 64, 82)
      ..close();
    canvas.drawPath(body, light);
  }

  @override
  bool shouldRepaint(_AvatarPlaceholderPainter oldDelegate) => false;
}
