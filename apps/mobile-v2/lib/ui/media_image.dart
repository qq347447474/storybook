/// Renders a [ResolvedMedia] whether the file behind it is raster or vector.
///
/// The pipeline draws illustrations with an LLM and saves them as **SVG**,
/// while the bundled sample ships a **PNG** cover. `Image.asset/file/network`
/// cannot decode SVG at all — it fails silently into the error builder, which
/// is why a freshly downloaded book showed a placeholder instead of its cover.
/// Every screen that paints pack media goes through this one widget so the two
/// formats cannot drift apart again.
library;

import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.errorFallback,
  });

  /// Already resolved media: bundled asset, cached file or remote URL.
  final ResolvedMedia media;

  final BoxFit fit;

  /// Shown when the bytes cannot be decoded. `null` leaves the slot empty,
  /// which the caller usually backs with its own placeholder plate.
  final Widget? errorFallback;

  /// True when [location] points at an SVG document.
  static bool isVector(String location) {
    final String path = location.split('?').first.toLowerCase();
    return path.endsWith('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final String assetKey = media.assetKey ?? media.location;
    final String location = media.origin == MediaOrigin.bundled
        ? assetKey
        : media.location;
    final bool vector = isVector(location);

    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        errorFallback ?? const SizedBox.shrink();

    switch (media.origin) {
      case MediaOrigin.bundled:
        return vector
            ? SvgPicture.asset(
                assetKey,
                fit: fit,
                errorBuilder: (BuildContext context, Object error, StackTrace? s) =>
                    fallback(context, error, s),
              )
            : Image.asset(
                assetKey,
                fit: fit,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    fallback(c, e, s),
              );
      case MediaOrigin.cached:
        return vector
            ? SvgPicture.file(
                _file(location),
                fit: fit,
                errorBuilder: (BuildContext context, Object error, StackTrace? s) =>
                    fallback(context, error, s),
              )
            : Image.file(
                _file(location),
                fit: fit,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    fallback(c, e, s),
              );
      case MediaOrigin.remote:
        return vector
            ? SvgPicture.network(
                location,
                fit: fit,
                errorBuilder: (BuildContext context, Object error, StackTrace? s) =>
                    fallback(context, error, s),
              )
            : Image.network(
                location,
                fit: fit,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    fallback(c, e, s),
              );
    }
  }

  File _file(String path) => File(path);
}
