import 'dart:io';

import 'package:attendix/core/services/certificate_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CertificateService', () {
    test('isVorkursTenantName matches short or long name', () {
      expect(isVorkursTenantName('Vorkurs 2026', 'BFECG'), isTrue);
      expect(isVorkursTenantName('BFECG', 'Orchester VORKURS'), isTrue);
      expect(isVorkursTenantName('Chor', 'Gemeindechor'), isFalse);
      expect(isVorkursTenantName(null, null), isFalse);
    });

    test('builds one page per person on the background image', () async {
      final bg = File(vorkursCertificateAsset).readAsBytesSync();
      final bytes = await const CertificateService().buildVorkursCertificates(
        [
          (firstName: 'Anna', lastName: 'Müller'),
          (firstName: 'Bartholomäus-Maximilian', lastName: 'Schmidt-Langenberger'),
        ],
        date: DateTime(2026, 6, 7),
        backgroundBytes: bg,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(100000));
      final out = Platform.environment['CERT_TEST_OUT'];
      if (out != null) File(out).writeAsBytesSync(bytes);
    });
  });
}
