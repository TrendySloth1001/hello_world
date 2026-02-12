import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A widget that automatically handles both SVG and regular image assets
class AppImage extends StatelessWidget {
  final String assetPath;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Color? color;

  const AppImage({
    super.key,
    required this.assetPath,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the asset is an SVG
    if (assetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        height: height,
        width: width,
        fit: fit,
        colorFilter: color != null
            ? ColorFilter.mode(color!, BlendMode.srcIn)
            : null,
      );
    }

    // Otherwise, use regular Image.asset
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      color: color,
    );
  }
}
