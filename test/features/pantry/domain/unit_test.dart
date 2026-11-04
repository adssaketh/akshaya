import 'package:akshaya/features/pantry/domain/failures.dart';
import 'package:akshaya/features/pantry/domain/unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('g <-> kg', () {
    expect(Unit.kg.convertTo(1.5, Unit.g), 1500);
    expect(Unit.g.convertTo(250, Unit.kg), 0.25);
  });

  test('ml <-> L', () {
    expect(Unit.l.convertTo(2, Unit.ml), 2000);
    expect(Unit.ml.convertTo(500, Unit.l), 0.5);
  });

  test('same unit is identity', () {
    expect(Unit.pcs.convertTo(3, Unit.pcs), 3);
  });

  test('mismatched families throw', () {
    expect(() => Unit.kg.convertTo(1, Unit.l), throwsA(isA<UnitMismatchFailure>()));
    expect(() => Unit.pcs.convertTo(1, Unit.dozen), throwsA(isA<UnitMismatchFailure>()));
  });

  test('compatibleUnits', () {
    expect(Unit.g.compatibleUnits, <Unit>[Unit.g, Unit.kg]);
    expect(Unit.packet.compatibleUnits, <Unit>[Unit.packet]);
  });

  test('format pluralises', () {
    expect(Unit.packet.format(1), '1 packet');
    expect(Unit.packet.format(3), '3 packets');
    expect(Unit.kg.format(0.5), '0.5 kg');
  });
}
