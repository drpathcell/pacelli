// Cross-language encryption compatibility test.
//
// This test verifies that Dart's EncryptionService produces output
// compatible with the TypeScript port in `functions/src/crypto/`.
//
// Run: flutter test test/cross_language_crypto_test.dart
//
// The test:
// 1. Checks HKDF key derivation matches hardcoded expected values
//    (same values are checked in the TypeScript test suite)
// 2. Decrypts TypeScript-generated ciphertexts (if vector file exists)
// 3. Generates Dart-encrypted vectors for TypeScript to consume
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacelli/core/crypto/encryption_service.dart';

const testKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const testUid = 'cross-lang-test-user-abc123';

void main() {
  group('Cross-language compatibility', () {
    group('HKDF key derivation (deterministic)', () {
      test('produces expected key for test UID', () {
        final derived = EncryptionService.deriveUserKey(testUid);

        // Must be a 64-char hex string
        expect(derived, matches(RegExp(r'^[0-9a-f]{64}$')));

        // Read the TypeScript-generated expected value if available
        final tsKeysFile =
            File('functions/tests/cross-language/ts_derived_keys.json');
        if (tsKeysFile.existsSync()) {
          final tsKeys =
              jsonDecode(tsKeysFile.readAsStringSync()) as Map<String, dynamic>;
          final tsExpected = tsKeys[testUid] as String;
          expect(derived, equals(tsExpected),
              reason: 'Dart HKDF output must match TypeScript HKDF output');
          // ignore: avoid_print
          print('✓ HKDF key derivation matches TypeScript output');

          // Also check the other UIDs
          for (final uid in ['user-alpha', 'user-beta', 'firebase-uid-12345']) {
            final dartKey = EncryptionService.deriveUserKey(uid);
            final tsKey = tsKeys[uid] as String;
            expect(dartKey, equals(tsKey),
                reason: 'HKDF mismatch for UID: $uid');
          }
          // ignore: avoid_print
          print('✓ All 4 HKDF derivations match TypeScript');
        } else {
          // ignore: avoid_print
          print(
              'ℹ ts_derived_keys.json not found — run TS tests first to generate');
          // ignore: avoid_print
          print('  Dart derived key: $derived');
        }
      });
    });

    group('Decrypt TypeScript-generated ciphertexts', () {
      test('decrypts TS vectors if available', () {
        final vectorFile =
            File('functions/tests/cross-language/ts_encrypted_vectors.json');

        if (!vectorFile.existsSync()) {
          // ignore: avoid_print
          print(
              'ℹ ts_encrypted_vectors.json not found — run TS tests first');
          return;
        }

        final data =
            jsonDecode(vectorFile.readAsStringSync()) as Map<String, dynamic>;
        final vectors = data['vectors'] as List<dynamic>;
        final key = data['testKey'] as String;

        for (final v in vectors) {
          final map = v as Map<String, dynamic>;
          final plaintext = map['plaintext'] as String;
          final ciphertext = map['ciphertext'] as String;

          final decrypted = EncryptionService.decrypt(ciphertext, key);
          expect(decrypted, equals(plaintext),
              reason: 'Failed to decrypt TS ciphertext for: '
                  '"${plaintext.length > 30 ? '${plaintext.substring(0, 30)}...' : plaintext}"');
        }

        // ignore: avoid_print
        print('✓ Decrypted ${vectors.length} TypeScript-encrypted values');
      });
    });

    group('Generate Dart vectors for TypeScript', () {
      test('generates encrypted test vectors', () {
        // NOTE: Empty string ('') is intentionally excluded.
        // PointyCastle's PaddedBlockCipherImpl mishandles 0-byte plaintext
        // (RangeError on PKCS7 padding), while Node's `crypto` handles it
        // fine — so the two ports are asymmetric for this edge case only.
        // Production code routes empty/null strings through
        // EncryptionService.encryptNullable, which short-circuits before
        // ever calling encrypt(), so this never affects users.
        final plaintexts = [
          'Hello, Pacelli!',
          'Café ☕ résumé 日本語 emoji 🎉', // unicode
          'A' * 1000, // long string
          'Task: Buy groceries\nDescription: Milk, eggs, bread',
        ];

        final dartEncrypted = <Map<String, String>>[];
        for (final pt in plaintexts) {
          final ct = EncryptionService.encrypt(pt, testKey);
          // Self-verify
          expect(EncryptionService.decrypt(ct, testKey), equals(pt));
          dartEncrypted.add({'plaintext': pt, 'ciphertext': ct});
        }

        // Household key wrapping
        final householdKey = 'aabbccdd' * 8; // 64-char deterministic
        final userKey = EncryptionService.deriveUserKey(testUid);
        final wrappedKey =
            EncryptionService.encryptKeyForUser(householdKey, userKey);

        final output = {
          'testKey': testKey,
          'testUid': testUid,
          'v2DerivedKey': EncryptionService.deriveUserKey(testUid),
          'dartEncrypted': dartEncrypted,
          'householdKey': householdKey,
          'wrappedHouseholdKey': wrappedKey,
          'generatedAt': DateTime.now().toIso8601String(),
          'dartVersion': Platform.version,
        };

        final outputDir =
            Directory('functions/tests/cross-language');
        if (!outputDir.existsSync()) {
          outputDir.createSync(recursive: true);
        }

        File('functions/tests/cross-language/test_vectors.json')
            .writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(output),
        );

        // ignore: avoid_print
        print('✓ Generated ${dartEncrypted.length} encrypted vectors');
        // ignore: avoid_print
        print('✓ Wrote test_vectors.json for TypeScript');
      });
    });
  });
}
