import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A friendly, smiling robot icon used as the AI assistant branding
/// throughout the app. Renders the custom Pacelli AI SVG asset with
/// the specified [size] and [color].
///
/// Falls back to a Material icon if the SVG fails to load.
class PacelliAiIcon extends StatelessWidget {
  const PacelliAiIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  /// The icon size in logical pixels. Defaults to 24.
  final double size;

  /// The icon color. Defaults to the current [IconTheme] color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.asset(
      'assets/icons/pacelli_ai.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
