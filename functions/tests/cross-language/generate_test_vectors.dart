// Generates test vectors for cross-language encryption compatibility.
//
// Run from the pacelli root:
//   dart run functions/tests/cross-language/generate_test_vectors.dart
//
// Outputs a JSON file that the TypeScript tests will consume.
import 'dart:convert';
import 'dart:io';

import 'package:pacelli/core/crypto/encryption_service.dart';

void main() {
  final testKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  final testUid = 'cross-lang-test-user-abc123';

  // 1. Key derivation — these are deterministic, so output must match exactly
  final v2DerivedKey = EncryptionService.deriveUserKey(testUid);

  // 2. Encrypt known plaintexts — TypeScript must be able to decrypt these
  final plaintexts = [
    'Hello, Pacelli!',
    '', // empty string
    'Café ☕ résumé 日本語 emoji 🎉', // unicode
    'A' * 1000, // long string
    'Task: Buy groceries\nDescription: Milk, eggs, bread',
  ];

  final dartEncrypted = <Map<String, String>>[];
  for (final pt in plaintexts) {
    final ct = EncryptionService.encrypt(pt, testKey);
    // Verify our own round-trip
    assert(EncryptionService.decrypt(ct, testKey) == pt);
    dartEncrypted.add({'plaintext': pt, 'ciphertext': ct});
  }

  // 3. Household key wrapping — encrypt a known key for a known UID
  final householdKey = 'aabbccdd' * 8; // 64-char hex, deterministic for test
  final wrappedKey = EncryptionService.encryptKeyForUser(
    householdKey,
    EncryptionService.deriveUserKey(testUid),
  );

  // 4. Nullable edge cases
  final nullableEncrypted =
      EncryptionService.encryptNullable('nullable test', testKey);
  final nullableNull = EncryptionService.encryptNullable(null, testKey);
  final nullableEmpty = EncryptionService.encryptNullable('', testKey);

  final vectors = {
    'testKey': testKey,
    'testUid': testUid,
    'v2DerivedKey': v2DerivedKey,
    'dartEncrypted': dartEncrypted,
    'householdKey': householdKey,
    'wrappedHouseholdKey': wrappedKey,
    'nullable': {
      'encrypted': nullableEncrypted,
      'null': nullableNull,
      'empty': nullableEmpty,
    },
    'generatedAt': DateTime.now().toIso8601String(),
    'dartVersion': Platform.version,
  };

  final outputPath = 'functions/tests/cross-language/test_vectors.json';
  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(vectors),
  );

  // ignore: avoid_print
  print('✓ Test vectors written to $outputPath');
  // ignore: avoid_print
  print('  Key derivation (v2): $v2DerivedKey');
  // ignore: avoid_print
  print('  Encrypted ${dartEncrypted.length} plaintexts');
  // ignore: avoid_print
  print('  Wrapped household key: ${wrappedKey.substring(0, 20)}...');
}
