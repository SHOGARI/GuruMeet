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
  bool _isHovered = false;
  bool _isFocused = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  void _setHovered(bool value) {
    if (widget.onPressed != null && _isHovered != value) {
      setState(() => _isHovered = value);
    }
  }

  void _setFocused(bool value) {
    if (widget.onPressed != null && _isFocused != value) {
      setState(() => _isFocused = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isInteractive = widget.onPressed != null;

    return Focus(
      onFocusChange: _setFocused,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        cursor: isInteractive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Listener(
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedScale(
            scale: _isPressed ? AppMotion.pressedScale : 1,
            duration: AppMotion.quick,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                boxShadow: isInteractive && (_isHovered || _isFocused)
                    ? AppShadows.elevatedAction(colors.primary)
                    : const [],
              ),
              child: FilledButton(
                onPressed: widget.onPressed,
                style: ButtonStyle(
                  side: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused) || _isFocused) {
                      return BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.72),
                        width: 1.4,
                      );
                    }
                    return BorderSide.none;
                  }),
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
