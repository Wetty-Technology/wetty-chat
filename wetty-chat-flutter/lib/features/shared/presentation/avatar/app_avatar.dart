import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/cache/app_cached_network_image.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    required this.size,
    this.memCacheWidth,
    this.fallbackBackgroundColor,
    this.fallbackTextStyle,
  });

  final String? name;
  final String? imageUrl;
  final double size;
  final int? memCacheWidth;
  final Color? fallbackBackgroundColor;
  final TextStyle? fallbackTextStyle;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = imageUrl?.trim();
    final fallback = _FallbackAvatar(
      label: _fallbackLabel(name),
      size: size,
      backgroundColor:
          fallbackBackgroundColor ?? context.appColors.avatarBackground,
      textStyle:
          fallbackTextStyle ??
          appOnDarkTextStyle(
            context,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
          ),
    );

    if (resolvedImageUrl == null ||
        resolvedImageUrl.isEmpty ||
        _isUnsupportedImageUrl(resolvedImageUrl)) {
      return fallback;
    }

    return ClipOval(
      child: AppCachedNetworkImage(
        imageUrl: resolvedImageUrl,
        width: size,
        height: size,
        memCacheWidth: memCacheWidth,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }

  static String _fallbackLabel(String? name) {
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName.characters.first.toUpperCase();
  }

  static bool _isUnsupportedImageUrl(String imageUrl) {
    final normalizedUrl = imageUrl.toLowerCase();
    if (normalizedUrl.startsWith('data:image/svg')) {
      return true;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return true;
    }

    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
      return true;
    }

    final path = uri.path.toLowerCase();
    return path.endsWith('.svg');
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({
    required this.label,
    required this.size,
    required this.backgroundColor,
    required this.textStyle,
  });

  final String label;
  final double size;
  final Color backgroundColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(label, style: textStyle),
    );
  }
}
