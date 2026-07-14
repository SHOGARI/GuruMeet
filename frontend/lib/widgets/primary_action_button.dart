import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.pressedScale : 1,
        duration: AppMotion.quick,
        curve: Curves.easeOut,
        child: FilledButton(
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}
