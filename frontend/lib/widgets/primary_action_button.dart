import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _isPressed = false;
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isInteractive => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (_isInteractive && _isPressed != value) {
      setState(() => _isPressed = value);
    }
  }

  void _setHovered(bool value) {
    if (_isInteractive && _isHovered != value) {
      setState(() => _isHovered = value);
    }
  }

  void _setFocused(bool value) {
    if (_isInteractive && _isFocused != value) {
      setState(() => _isFocused = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isInteractive = _isInteractive;

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
                onPressed: isInteractive ? widget.onPressed : null,
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
                child: widget.isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: AppSizes.iconMedium,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Text(widget.loadingLabel ?? widget.label),
                        ],
                      )
                    : Text(widget.label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
