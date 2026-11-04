import 'dart:math';

import 'package:akshaya/features/sync/domain/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated codes are 8 characters without look-alikes', () {
    final Random random = Random(7);
    for (int i = 0; i < 200; i++) {
      final String code = InviteCode.generate(random);
      expect(code, hasLength(8));
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]+$')));
    }
  });

  test('normalize accepts dashes, spaces and lower case', () {
    expect(InviteCode.normalize('abcd-2345'), 'ABCD2345');
    expect(InviteCode.normalize(' ABCD 2345 '), 'ABCD2345');
  });

  test('normalize rejects wrong lengths and look-alike characters', () {
    expect(InviteCode.normalize('ABC'), isNull);
    expect(InviteCode.normalize('ABCD234'), isNull);
    expect(InviteCode.normalize('ABCD23455'), isNull);
    expect(InviteCode.normalize('ABCD234O'), isNull);
    expect(InviteCode.normalize(''), isNull);
  });

  test('format puts a dash in the middle', () {
    expect(InviteCode.format('ABCD2345'), 'ABCD-2345');
  });

  test('the QR payload carries the prefix and the code', () {
    expect(InviteCode.qrPayload('ABCD2345'), 'akshaya-join:ABCD2345');
  });
}
