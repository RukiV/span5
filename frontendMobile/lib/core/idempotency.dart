import 'dart:math';

/// Generates a unique idempotency key (v4-like UUID) for duplicate-submission
/// protection.  The backend dedupes POSTs carrying the same X-Idempotency-Key
/// (method + path + key), so retries of the same logical submission never
/// create duplicates — even if the body differs between clicks.
class Idempotency {
  static final Random _rng = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
