import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final int avatarIndex;
  final String? imageBase64;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;

  const ProfileAvatar({
    super.key,
    required this.avatarIndex,
    this.imageBase64,
    required this.size,
    required this.iconSize,
    this.backgroundColor = AppColors.primaryLight,
    this.iconColor = AppColors.primaryDark,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeImage();
    final isCircle = borderRadius == 0;
    final decoration = BoxDecoration(
      color: backgroundColor,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: borderWidth),
    );
    final child = bytes == null
        ? Icon(heroAvatarIcon(avatarIndex), size: iconSize, color: iconColor)
        : Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Uint8List? _decodeImage() {
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    try {
      return base64Decode(imageBase64!);
    } on FormatException {
      return null;
    }
  }
}
