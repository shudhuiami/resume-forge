import 'dart:convert';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

/// Serializes image bytes as base64 so a resume document round-trips through
/// JSON unchanged on every platform.
///
/// Photos are downscaled on import (see `PhotoService`), so the encoded payload
/// stays in the tens of kilobytes rather than carrying a multi-megabyte camera
/// original into every autosave write.
class Uint8ListConverter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return base64Decode(json);
    } on FormatException {
      // A corrupt photo must not take the whole resume down with it.
      return null;
    }
  }

  @override
  String? toJson(Uint8List? object) =>
      object == null ? null : base64Encode(object);
}
