import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/api.dart' show PublicKeyParameter;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';

class EncryptedPayload {
  final String encryptedBlobB64;
  final String nonceB64;
  final String wrappedKeyB64;

  const EncryptedPayload({
    required this.encryptedBlobB64,
    required this.nonceB64,
    required this.wrappedKeyB64,
  });

  Map<String, String> toJson() => {
        'encrypted_blob': encryptedBlobB64,
        'nonce_b64': nonceB64,
        'wrapped_key_b64': wrappedKeyB64,
      };
}

class CryptoService {
  static const _serverPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzmTHLfhRnBYvXp2ic19s
jYv9BnA9wGRxlKRjNuB/kvY0wabQ6QzCTOVURNUSUuhaIVWG+VradNjHaxDJuI4c
+BIoQQrK+zCJ7Th65WrG2hKmI6p3naEYgpM8PCQQcox7ai+x9skHjTEuwWG/qD5u
lOJUrkkROIuYjX+AU57cJvBAxxccoUYKWZO5VE4ahHJdU+IcBcxkmpLOmh/qIWtL
XJoxJz2w35gKtgbZhq7wei4Ox4N0W/Cc3yTtWTB+6MzrLV8W3LqOu5iiQ8944s7x
6/Pf9i5jmYL//gV+F+/J+ngpcEObktAN51j0+j6NUArq1oZhd3Kfg3zMGfiDYBL/
SwIDAQAB
-----END PUBLIC KEY-----''';

  static final _rng = Random.secure();

  static EncryptedPayload encryptFile(Uint8List wavBytes) {
    final aesKeyBytes = _randomBytes(32);
    final nonceBytes = _randomBytes(12);

    final key = enc.Key(aesKeyBytes);
    final iv = enc.IV(nonceBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(wavBytes, iv: iv);

    final wrappedKey = _wrapKeyRsaOaep(aesKeyBytes);

    return EncryptedPayload(
      encryptedBlobB64: base64Encode(encrypted.bytes),
      nonceB64: base64Encode(nonceBytes),
      wrappedKeyB64: base64Encode(wrappedKey),
    );
  }

  static Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => _rng.nextInt(256)));

  static Uint8List _wrapKeyRsaOaep(Uint8List aesKey) {
    final publicKey = _parsePublicKey(_serverPublicKeyPem);
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(aesKey);
  }

  static RSAPublicKey _parsePublicKey(String pem) {
    final lines = pem
        .split('\n')
        .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
        .join('');
    final der = base64Decode(lines);

    final outerParser = ASN1Parser(Uint8List.fromList(der));
    final outerSeq = outerParser.nextObject() as ASN1Sequence;
    final bitString = outerSeq.elements![1] as ASN1BitString;

    final bytes = bitString.stringValues as Uint8List;
    final inner = bytes.isNotEmpty && bytes.first == 0x00 ? bytes.sublist(1) : bytes;

    final innerParser = ASN1Parser(inner);
    final keySeq = innerParser.nextObject() as ASN1Sequence;

    final modulus = (keySeq.elements![0] as ASN1Integer).integer!;
    final exponent = (keySeq.elements![1] as ASN1Integer).integer!;

    return RSAPublicKey(modulus, exponent);
  }
}