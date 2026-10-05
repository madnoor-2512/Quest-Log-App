import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_avatars.dart';
import '../theme/app_colors.dart';

class ProfileAvatar extends StatefulWidget {
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
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  MemoryImage? _imageProvider;

  @override
  void initState() {
    super.initState();
    _updateImageProvider();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageBase64 != oldWidget.imageBase64) {
      _updateImageProvider();
    }
  }

  void _updateImageProvider() {
    final encoded = widget.imageBase64;
    if (encoded == null || encoded.isEmpty) {
      _imageProvider = null;
      return;
    }
    try {
      _imageProvider = MemoryImage(base64Decode(encoded));
    } on FormatException {
      _imageProvider = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCircle = widget.borderRadius == 0;
    final decoration = BoxDecoration(
      color: widget.backgroundColor,
      shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: isCircle
          ? null
          : BorderRadius.circular(widget.borderRadius),
      border: widget.borderColor == null
          ? null
          : Border.all(color: widget.borderColor!, width: widget.borderWidth),
    );
    final fallback = Icon(
      heroAvatarIcon(widget.avatarIndex),
      size: widget.iconSize,
      color: widget.iconColor,
    );
    final child = _imageProvider == null
        ? fallback
        : Image(
            image: _imageProvider!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
