import 'dart:io';

import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppInitialAvatar extends StatelessWidget {
  const AppInitialAvatar({
    super.key,
    required this.initial,
    this.size = 54,
    this.color,
    this.avatarUri,
  });

  final String initial;
  final double size;
  final Color? color;
  final String? avatarUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final accent = color ?? colorScheme.primary;
    final fallback = _InitialAvatarFallback(
      initial: initial,
      size: size,
      color: accent,
    );
    final normalizedAvatarUri = avatarUri?.trim();

    if (normalizedAvatarUri == null || normalizedAvatarUri.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.lg),
      child: Image.file(
        File(normalizedAvatarUri),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _InitialAvatarFallback extends StatelessWidget {
  const _InitialAvatarFallback({
    required this.initial,
    required this.size,
    required this.color,
  });

  final String initial;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.radiusTokens;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
