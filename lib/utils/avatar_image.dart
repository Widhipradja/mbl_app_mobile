import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The server takes jpeg/png/webp up to 2 MB and does not resize.
const avatarMaxBytes = 2 * 1024 * 1024;
const _maxSide = 1024;

/// A photo shrunk for upload: upright, at most 1024 px on the long side, as
/// JPEG, and under [avatarMaxBytes]. Returns null when the bytes are not a
/// picture or cannot be brought under the limit.
Future<Uint8List?> prepareAvatar(Uint8List original) =>
    compute(_prepare, original);

Uint8List? _prepare(Uint8List original) {
  var image = img.decodeImage(original);
  if (image == null) return null;
  image = img.bakeOrientation(image);
  if (image.width > _maxSide || image.height > _maxSide) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? _maxSide : null,
      height: image.height > image.width ? _maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  for (final quality in const [85, 70, 55]) {
    final out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    if (out.length <= avatarMaxBytes) return out;
  }
  return null;
}
