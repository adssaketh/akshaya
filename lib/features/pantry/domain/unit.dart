import '../../../core/util/quantity.dart';
import 'failures.dart';

/// Units that can be converted into each other. Only g<->kg and ml<->L are
/// convertible; every other unit converts only to itself.
enum UnitFamily { pieces, mass, volume, packet, dozen, bunch, portion }

/// Measurement units. The enum [name] is what the database stores, so never
/// rename a value without a migration.
enum Unit {
  pcs('pcs', 'pcs', UnitFamily.pieces, 1),
  g('g', 'g', UnitFamily.mass, 1),
  kg('kg', 'kg', UnitFamily.mass, 1000),
  ml('ml', 'ml', UnitFamily.volume, 1),
  l('L', 'L', UnitFamily.volume, 1000),
  packet('packet', 'packets', UnitFamily.packet, 1),
  dozen('dozen', 'dozen', UnitFamily.dozen, 1),
  bunch('bunch', 'bunches', UnitFamily.bunch, 1),

  /// One serving of cooked food (a bowl, a plate, a container).
  portion('portion', 'portions', UnitFamily.portion, 1);

  const Unit(this.symbol, this.pluralSymbol, this.family, this.baseFactor);

  /// Short English label, e.g. "kg" or "packet".
  final String symbol;

  /// Label used for quantities other than one, e.g. "packets".
  final String pluralSymbol;

  final UnitFamily family;

  /// Size of one of this unit in the family's base unit (g or ml).
  final double baseFactor;

  /// True when quantities can be converted between this unit and [other].
  bool isCompatibleWith(Unit other) => family == other.family;

  /// All units that can be converted to and from this one (including itself).
  List<Unit> get compatibleUnits {
    return Unit.values
        .where((Unit u) => u.family == family)
        .toList(growable: false);
  }

  /// Converts [value] from this unit to [target].
  ///
  /// Throws [UnitMismatchFailure] when the units are not compatible.
  double convertTo(double value, Unit target) {
    if (!isCompatibleWith(target)) {
      throw UnitMismatchFailure(symbol, target.symbol);
    }
    if (this == target) {
      return value;
    }
    return value * baseFactor / target.baseFactor;
  }

  /// "2 kg", "1 packet", "3 packets", "0.5 L".
  String format(double quantity) {
    final String label = roundQty(quantity) == 1 ? symbol : pluralSymbol;
    return '${formatNumber(quantity)} $label';
  }

  /// One-tap amounts shown in the "Use" sheet.
  List<double> get quickAmounts {
    switch (this) {
      case Unit.kg:
      case Unit.l:
        return const <double>[0.25, 0.5, 1];
      case Unit.g:
      case Unit.ml:
        return const <double>[50, 100, 250, 500];
      case Unit.pcs:
        return const <double>[1, 2, 3];
      case Unit.packet:
      case Unit.dozen:
      case Unit.bunch:
        return const <double>[0.5, 1];
      case Unit.portion:
        return const <double>[0.5, 1, 2];
    }
  }
}
