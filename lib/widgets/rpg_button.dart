import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// RPG-styled button with press-down depth animation
class RpgButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  final double height;
  final double? width;
  final bool isLoading;

  const RpgButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor = AppColors.primary,
    this.borderColor = AppColors.primaryDark,
    this.textColor = Colors.white,
    this.icon,
    this.height = 50,
    this.width,
    this.isLoading = false,
  });

  @override
  State<RpgButton> createState() => _RpgButtonState();
}

class _RpgButtonState extends State<RpgButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final depth = _isPressed ? 0.0 : 4.0;
    final topMargin = _isPressed ? 4.0 : 0.0;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height,
        margin: EdgeInsets.only(top: topMargin, bottom: 4.0 - topMargin),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade400 : widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled ? Colors.grey.shade600 : widget.borderColor,
            width: 2.5,
          ),
          boxShadow: depth > 0
              ? [
                  BoxShadow(
                    color: isDisabled
                        ? Colors.grey.shade700
                        : widget.borderColor,
                    offset: Offset(0, depth),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.textColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
