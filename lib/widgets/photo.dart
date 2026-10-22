import 'dart:math';

import 'package:flutter/material.dart';

/// A diary photo decoded at about the size it's shown, not its full 2048 px:
/// much faster to show and far lighter on memory in grids and lists.
class SizedPhoto extends StatelessWidget {
  const SizedPhoto(this.image, {super.key, this.fit = BoxFit.cover});
  final ImageProvider image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final side = max(box.maxWidth.isFinite ? box.maxWidth : 0.0, box.maxHeight.isFinite ? box.maxHeight : 0.0);
        // Room for a photo of another shape to still cover the box (cropping).
        final target = side == 0 ? null : (side * dpr * 1.5).round();
        final sized = target == null
            ? image
            : ResizeImage(image, width: target, height: target, policy: ResizeImagePolicy.fit);
        return Image(image: sized, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
