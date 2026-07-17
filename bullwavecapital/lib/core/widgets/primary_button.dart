import 'package:flutter/material.dart';

import '../theme/theme_a.dart';
import '../constants/dimensions.dart';
import 'scale_tap.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool compact;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? p.primary : Colors.black;
    final fg = isDark ? p.onPrimary : Colors.white;
    final fontSize = compact ? 14.0 : 16.0;
    final iconSize = compact ? 18.0 : 20.0;
    final hPad = compact ? 10.0 : 16.0;

    return ScaleTap(
      onTap: isLoading ? null : onPressed,
      child: SizedBox(
        height: AppDimensions.buttonHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: bg,
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: fg,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: p.textGrey,
              minimumSize: const Size(0, AppDimensions.buttonHeight),
              padding: EdgeInsets.symmetric(horizontal: hPad),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: iconSize),
                        SizedBox(width: compact ? 4 : 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize, color: fg),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fontSize = compact ? 14.0 : 16.0;
    final iconSize = compact ? 18.0 : 20.0;
    final hPad = compact ? 10.0 : 16.0;

    return ScaleTap(
      onTap: onPressed,
      child: SizedBox(
        height: AppDimensions.buttonHeight,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: p.card,
            foregroundColor: p.textDark,
            minimumSize: const Size(0, AppDimensions.buttonHeight),
            padding: EdgeInsets.symmetric(horizontal: hPad),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            side: BorderSide(color: p.borderLight, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                SizedBox(width: compact ? 4 : 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AccentButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(label: label, onPressed: onPressed);
  }
}
