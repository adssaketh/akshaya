import 'nutrition_table.dart';

/// Headline figures from the ICMR-NIN "Dietary Guidelines for Indians" (2024),
/// used only as GUIDES to compare what was eaten with. Only a few numbers are
/// used, each with the place it comes from; the guideline's tables and text
/// are not copied (its copyright notice asks for permission before they are
/// built into a product).
///
/// Check any figure against the guideline itself (www.nin.res.in) before
/// relying on it: they are typed in by hand, and the app cannot know a
/// person's age, weight or health. They are not medical advice.
const String kDgiSource = 'ICMR-NIN, Dietary Guidelines for Indians (2024)';

/// "My Plate for the Day", per person per day, raw weights.
const double kVegetablesGuideGrams = 400; // incl. leafy; excl. potato and roots
const double kFruitGuideGrams = 100;
const double kMilkGuideMl = 300; // milk or curd

/// Added sugar: keep it to 25 to 30 g a day (under 5% of energy).
const double kAddedSugarLimitGrams = 30;

/// Vegetables and fruit together in the plate.
const double kVegFruitGoalGrams = kVegetablesGuideGrams + kFruitGuideGrams;

/// Fats and oils are about 12% of energy in the plate (27 g of 2,000 kcal);
/// the guideline's threshold for added fat in a food is about 15% of energy.
const double kVisibleFatEnergyShare = 0.15;

/// Total fat should not pass 30% of energy.
const double kTotalFatEnergyShare = 0.30;

/// The sample diets give 57 g of protein at 1,660 kcal up to 90 g at 2,680
/// kcal: about 3.4 g for every 100 kcal.
const double kProteinGramsPerKcal = 0.0343;

/// The guideline mentions fibre of around 25 g for every 1,000 kcal (in its
/// pregnancy section; used here as an indicative figure for adults). WHO's
/// minimum for adults is 25 g a day.
const double kFibreGramsPer1000Kcal = 25;
const double kFibreMinimumGrams = 25;

double proteinGuideFor(int kcal) => kcal * kProteinGramsPerKcal;
double fibreGuideFor(int kcal) => kcal * kFibreGramsPer1000Kcal / 1000;

/// A reference adult from the guideline's sample diets (a 55 kg woman or a
/// 65 kg man).
final class ReferenceAdult {
  const ReferenceAdult(this.label, this.kcal);

  final String label;
  final int kcal;
}

const List<ReferenceAdult> kReferenceAdults = <ReferenceAdult>[
  ReferenceAdult('Woman', 1660),
  ReferenceAdult('Man', 2080),
  ReferenceAdult('Woman, active', 2125),
  ReferenceAdult('Man, active', 2680),
];

/// One line of the plate: how much of a food group a person should have in a
/// day. [isLimit] is true where the figure is a ceiling, not an aim.
final class PlateTarget {
  const PlateTarget({
    required this.label,
    required this.group,
    required this.amount,
    required this.unit,
    this.isLimit = false,
  });

  final String label;
  final FoodGroup group;
  final double amount;

  /// "g" or "ml".
  final String unit;
  final bool isLimit;
}

// Grains, pulses, nuts and oils go up with energy in the guideline's sample
// diets; vegetables, fruit and milk stay the same. (kcal, cereals, pulses,
// nuts, fats): the sample diets of a 55 kg woman and a 65 kg man (sedentary
// and moderately active) and the 2,000 kcal My Plate.
const List<List<double>> _scaled = <List<double>>[
  <double>[1660, 190, 60, 30, 25],
  <double>[2000, 250, 85, 35, 27], // My Plate for the Day
  <double>[2080, 260, 85, 40, 30],
  <double>[2125, 270, 90, 40, 30],
  <double>[2680, 370, 120, 45, 40],
];

double _along(int kcal, int column) {
  final double k = kcal.toDouble();
  if (k <= _scaled.first[0]) {
    return _scaled.first[column] * k / _scaled.first[0];
  }
  for (int i = 1; i < _scaled.length; i++) {
    final List<double> a = _scaled[i - 1];
    final List<double> b = _scaled[i];
    if (k <= b[0]) {
      final double t = (k - a[0]) / (b[0] - a[0]);
      return a[column] + t * (b[column] - a[column]);
    }
  }
  return _scaled.last[column] * k / _scaled.last[0];
}

/// The plate for a person at [kcal] a day: what to aim for in each group.
/// With [eggs], dal is a little lower and eggs (about 70 g) join the plate,
/// as in the guideline's non-vegetarian plate.
List<PlateTarget> plateFor({required int kcal, required bool eggs}) {
  double r(double v) => (v / 5).round() * 5;
  final double pulses = _along(kcal, 2) * (eggs ? 55 / 85 : 1);
  return <PlateTarget>[
    PlateTarget(
      label: 'Grains and millets',
      group: FoodGroup.cereals,
      amount: r(_along(kcal, 1)),
      unit: 'g',
    ),
    PlateTarget(
      label: 'Dals and pulses',
      group: FoodGroup.pulses,
      amount: r(pulses),
      unit: 'g',
    ),
    if (eggs)
      const PlateTarget(
        label: 'Eggs',
        group: FoodGroup.meatEggs,
        amount: 70,
        unit: 'g',
      ),
    const PlateTarget(
      label: 'Milk and curd',
      group: FoodGroup.dairy,
      amount: kMilkGuideMl,
      unit: 'ml',
    ),
    const PlateTarget(
      label: 'Vegetables (without potato)',
      group: FoodGroup.vegetables,
      amount: kVegetablesGuideGrams,
      unit: 'g',
    ),
    const PlateTarget(
      label: 'Fruit',
      group: FoodGroup.fruits,
      amount: kFruitGuideGrams,
      unit: 'g',
    ),
    PlateTarget(
      label: 'Nuts and seeds',
      group: FoodGroup.nutsSeeds,
      amount: r(_along(kcal, 3)),
      unit: 'g',
    ),
    PlateTarget(
      label: 'Oils and ghee',
      group: FoodGroup.fats,
      amount: r(_along(kcal, 4)),
      unit: 'g',
      isLimit: true,
    ),
    const PlateTarget(
      label: 'Sugar and jaggery',
      group: FoodGroup.sugars,
      amount: kAddedSugarLimitGrams,
      unit: 'g',
      isLimit: true,
    ),
  ];
}
