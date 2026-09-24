import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// RPG-styled button with 16-bit retro press-down depth (2px shift + shadow drop)
/// and optional punchy bounce/scale animation on tap
class RpgButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData? icon;
  final double height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double fontSize;
  final bool isLoading;
  final bool bounceOnTap;

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
    this.padding,
    this.fontSize = 16,
    this.isLoading = false,
    this.bounceOnTap = false,
  });

  @override
  State<RpgButton> createState() => _RpgButtonState();
}

class _RpgButtonState extends State<RpgButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _bounceCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.90), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.90, end: 1.08), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.08, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.bounceOnTap) {
      _bounceCtrl.forward(from: 0.0);
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Widget buttonBody = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      transform: Matrix4.translationValues(0, _isPressed ? 2.0 : 0.0, 0),
      width: widget.width,
      height: widget.height,
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade400 : widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDisabled ? Colors.grey.shade600 : widget.borderColor,
          width: 2.0,
        ),
        boxShadow: (_isPressed || isDisabled)
            ? []
            : [
                BoxShadow(
                  color: isDisabled
                      ? Colors.grey.shade700
                      : widget.borderColor,
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
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
                  Icon(widget.icon,
                      color: widget.textColor, size: widget.fontSize + 2),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
    );

    if (widget.bounceOnTap) {
      buttonBody = ScaleTransition(scale: _scaleAnim, child: buttonBody);
    }

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() => _isPressed = false);
              _handleTap();
            },
      onTapCancel: isDisabled ? null : () => setState(() => _isPressed = false),
      child: buttonBody,
    );
  }
}
