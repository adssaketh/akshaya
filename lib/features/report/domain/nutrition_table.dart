import '../../pantry/domain/unit.dart';

/// Food groups used for the energy estimate and the balance check.
enum FoodGroup {
  cereals,
  pulses,
  vegetables,
  fruits,
  dairy,
  meatEggs,
  fats,
  sugars,
  nutsSeeds,
  other,
}

/// Rough energy for one kind of food, per 100 g or 100 ml as it is bought
/// (raw, uncooked), with typical piece and bunch weights.
///
/// These are ROUGH averages, typed in from general knowledge of food
/// composition tables (ICMR-NIN "Indian Food Composition Tables" and USDA
/// FoodData Central are the places to check a value). Brands, varieties and
/// cooking change the real number, so the app always shows the result as an
/// estimate.
final class FoodEnergy {
  const FoodEnergy(
    this.keywords,
    this.group, {
    this.kcalPer100g,
    this.kcalPer100ml,
    this.gramsPerPiece,
    this.gramsPerBunch,
  });

  /// Lower-case words or phrases that identify the food in an item name.
  final List<String> keywords;
  final FoodGroup group;
  final double? kcalPer100g;
  final double? kcalPer100ml;
  final double? gramsPerPiece;
  final double? gramsPerBunch;
}

/// The energy of an amount of food. [grams] is null when the weight is not
/// known (a liquid, say).
final class EnergyEstimate {
  const EnergyEstimate({required this.kcal, this.grams});

  final double kcal;
  final double? grams;
}

/// Specific foods first: the first entry whose keyword is in the name wins,
/// so "coconut oil" is oil, "sweet potato" is not potato and "buttermilk" is
/// not butter.
const List<FoodEnergy> kFoodEnergyTable = <FoodEnergy>[
  // Fats and oils.
  FoodEnergy(<String>['ghee'], FoodGroup.fats,
      kcalPer100g: 900, kcalPer100ml: 830),
  FoodEnergy(<String>['oil'], FoodGroup.fats,
      kcalPer100g: 884, kcalPer100ml: 820),
  FoodEnergy(<String>['peanut butter'], FoodGroup.fats, kcalPer100g: 590),
  FoodEnergy(<String>['buttermilk', 'butter milk', 'chaas', 'mor'],
      FoodGroup.dairy,
      kcalPer100g: 40, kcalPer100ml: 40),
  FoodEnergy(<String>['butter', 'vanaspati', 'dalda', 'margarine'],
      FoodGroup.fats,
      kcalPer100g: 720),
  FoodEnergy(<String>['mayonnaise'], FoodGroup.fats, kcalPer100g: 680),
  // Dairy.
  FoodEnergy(<String>['curd', 'yogurt', 'yoghurt', 'dahi', 'perugu', 'thayir'],
      FoodGroup.dairy,
      kcalPer100g: 60, kcalPer100ml: 60),
  FoodEnergy(<String>['paneer', 'cottage cheese'], FoodGroup.dairy,
      kcalPer100g: 280),
  FoodEnergy(<String>['cheese'], FoodGroup.dairy, kcalPer100g: 350),
  FoodEnergy(<String>['milk powder'], FoodGroup.dairy, kcalPer100g: 495),
  FoodEnergy(<String>['khoa', 'khova', 'mawa'], FoodGroup.dairy,
      kcalPer100g: 420),
  FoodEnergy(<String>['cream', 'malai'], FoodGroup.dairy, kcalPer100g: 340),
  FoodEnergy(<String>['coconut milk'], FoodGroup.nutsSeeds, kcalPer100ml: 190),
  FoodEnergy(<String>['coconut water'], FoodGroup.other, kcalPer100ml: 19),
  FoodEnergy(<String>['milk'], FoodGroup.dairy,
      kcalPer100g: 62, kcalPer100ml: 62),
  // Eggs, meat and fish.
  FoodEnergy(<String>['egg'], FoodGroup.meatEggs,
      kcalPer100g: 143, gramsPerPiece: 50),
  FoodEnergy(<String>['chicken'], FoodGroup.meatEggs, kcalPer100g: 140),
  FoodEnergy(<String>['mutton', 'goat', 'lamb'], FoodGroup.meatEggs,
      kcalPer100g: 150),
  FoodEnergy(<String>['prawn', 'shrimp'], FoodGroup.meatEggs, kcalPer100g: 90),
  FoodEnergy(<String>['fish', 'seafood'], FoodGroup.meatEggs,
      kcalPer100g: 110),
  // Grains and flours.
  FoodEnergy(<String>['rice flour'], FoodGroup.cereals, kcalPer100g: 360),
  FoodEnergy(
      <String>[
        'rice',
        'basmati',
        'poha',
        'aval',
        'flattened rice',
        'puffed rice',
        'murmura',
      ],
      FoodGroup.cereals,
      kcalPer100g: 355),
  FoodEnergy(
      <String>['wheat flour', 'atta', 'whole wheat', 'chapati flour'],
      FoodGroup.cereals,
      kcalPer100g: 345),
  FoodEnergy(<String>['maida', 'all purpose flour', 'refined flour'],
      FoodGroup.cereals,
      kcalPer100g: 350),
  FoodEnergy(<String>['rava', 'sooji', 'suji', 'semolina'], FoodGroup.cereals,
      kcalPer100g: 350),
  FoodEnergy(<String>['oats'], FoodGroup.cereals, kcalPer100g: 385),
  FoodEnergy(<String>['ragi', 'finger millet'], FoodGroup.cereals,
      kcalPer100g: 330),
  FoodEnergy(<String>['jowar', 'sorghum'], FoodGroup.cereals, kcalPer100g: 340),
  FoodEnergy(<String>['bajra', 'pearl millet'], FoodGroup.cereals,
      kcalPer100g: 360),
  FoodEnergy(
      <String>['millet', 'foxtail', 'kodo', 'little millet', 'barnyard'],
      FoodGroup.cereals,
      kcalPer100g: 340),
  FoodEnergy(<String>['corn flour', 'cornflour', 'cornmeal'], FoodGroup.cereals,
      kcalPer100g: 355),
  FoodEnergy(
      <String>['vermicelli', 'semiya', 'pasta', 'noodles', 'macaroni'],
      FoodGroup.cereals,
      kcalPer100g: 355),
  FoodEnergy(<String>['sabudana', 'sago'], FoodGroup.cereals, kcalPer100g: 350),
  FoodEnergy(<String>['roti', 'chapati', 'paratha'], FoodGroup.cereals,
      kcalPer100g: 300, gramsPerPiece: 40),
  FoodEnergy(<String>['bread', 'bun', 'pav'], FoodGroup.cereals,
      kcalPer100g: 265, gramsPerPiece: 30),
  // Pulses.
  FoodEnergy(<String>['besan', 'gram flour'], FoodGroup.pulses,
      kcalPer100g: 390),
  FoodEnergy(<String>['toor', 'tur', 'arhar', 'tuvar', 'pigeon pea'],
      FoodGroup.pulses,
      kcalPer100g: 335),
  FoodEnergy(<String>['moong', 'mung', 'green gram'], FoodGroup.pulses,
      kcalPer100g: 345),
  FoodEnergy(<String>['urad', 'black gram'], FoodGroup.pulses,
      kcalPer100g: 345),
  FoodEnergy(<String>['chana dal', 'bengal gram', 'split chickpea'],
      FoodGroup.pulses,
      kcalPer100g: 360),
  FoodEnergy(<String>['chana', 'chickpea', 'kabuli', 'chole', 'garbanzo'],
      FoodGroup.pulses,
      kcalPer100g: 360),
  FoodEnergy(<String>['masoor', 'lentil'], FoodGroup.pulses, kcalPer100g: 345),
  FoodEnergy(<String>['rajma', 'kidney bean'], FoodGroup.pulses,
      kcalPer100g: 335),
  FoodEnergy(<String>['lobia', 'black eyed', 'cowpea'], FoodGroup.pulses,
      kcalPer100g: 335),
  FoodEnergy(
      <String>['soya chunks', 'soy chunks', 'soya', 'soy', 'soybean'],
      FoodGroup.pulses,
      kcalPer100g: 345),
  FoodEnergy(<String>['dal', 'dhal'], FoodGroup.pulses, kcalPer100g: 340),
  // Nuts and seeds.
  FoodEnergy(<String>['peanut', 'groundnut', 'ground nut', 'pallilu'],
      FoodGroup.nutsSeeds,
      kcalPer100g: 570),
  FoodEnergy(<String>['almond', 'badam'], FoodGroup.nutsSeeds,
      kcalPer100g: 580),
  FoodEnergy(<String>['cashew', 'kaju'], FoodGroup.nutsSeeds,
      kcalPer100g: 555),
  FoodEnergy(<String>['walnut', 'akhrot'], FoodGroup.nutsSeeds,
      kcalPer100g: 650),
  FoodEnergy(<String>['pistachio', 'pista'], FoodGroup.nutsSeeds,
      kcalPer100g: 560),
  FoodEnergy(<String>['sesame', 'til', 'gingelly'], FoodGroup.nutsSeeds,
      kcalPer100g: 570),
  FoodEnergy(
      <String>['flax', 'chia', 'sunflower seed', 'pumpkin seed', 'melon seed'],
      FoodGroup.nutsSeeds,
      kcalPer100g: 540),
  FoodEnergy(<String>['coconut'], FoodGroup.nutsSeeds, kcalPer100g: 350),
  FoodEnergy(<String>['raisin', 'kismis', 'sultana'], FoodGroup.other,
      kcalPer100g: 300),
  FoodEnergy(<String>['dates', 'khajoor', 'kharjura'], FoodGroup.other,
      kcalPer100g: 280),
  FoodEnergy(<String>['fig', 'anjeer'], FoodGroup.other, kcalPer100g: 250),
  // Sugars.
  FoodEnergy(<String>['sugar', 'cheeni', 'chakkera'], FoodGroup.sugars,
      kcalPer100g: 400),
  FoodEnergy(<String>['jaggery', 'gur', 'bellam', 'vellam'], FoodGroup.sugars,
      kcalPer100g: 380),
  FoodEnergy(<String>['honey', 'madhu'], FoodGroup.sugars,
      kcalPer100g: 304, kcalPer100ml: 420),
  // Spices (small amounts, so small numbers).
  FoodEnergy(<String>['salt', 'namak', 'uppu'], FoodGroup.other,
      kcalPer100g: 0),
  FoodEnergy(<String>['tea', 'chai', 'coffee'], FoodGroup.other,
      kcalPer100g: 0),
  FoodEnergy(<String>['turmeric', 'haldi', 'pasupu'], FoodGroup.other,
      kcalPer100g: 312),
  FoodEnergy(
      <String>['chilli powder', 'red chilli', 'kashmiri', 'mirchi powder'],
      FoodGroup.other,
      kcalPer100g: 280),
  FoodEnergy(<String>['cumin', 'jeera'], FoodGroup.other, kcalPer100g: 375),
  FoodEnergy(<String>['mustard'], FoodGroup.other, kcalPer100g: 470),
  FoodEnergy(<String>['pepper'], FoodGroup.other, kcalPer100g: 250),
  FoodEnergy(<String>['cardamom', 'elaichi'], FoodGroup.other,
      kcalPer100g: 311),
  FoodEnergy(<String>['clove', 'laung'], FoodGroup.other, kcalPer100g: 274),
  FoodEnergy(<String>['cinnamon', 'dalchini'], FoodGroup.other,
      kcalPer100g: 247),
  FoodEnergy(
      <String>[
        'coriander seed',
        'coriander powder',
        'dhania powder',
        'dhaniya powder',
      ],
      FoodGroup.other,
      kcalPer100g: 298),
  FoodEnergy(<String>['fenugreek seed', 'methi seed'], FoodGroup.other,
      kcalPer100g: 323),
  FoodEnergy(<String>['hing', 'asafoetida'], FoodGroup.other, kcalPer100g: 297),
  FoodEnergy(
      <String>[
        'masala',
        'garam masala',
        'sambar powder',
        'rasam powder',
        'curry powder',
      ],
      FoodGroup.other,
      kcalPer100g: 300),
  FoodEnergy(<String>['fennel', 'saunf'], FoodGroup.other, kcalPer100g: 345),
  FoodEnergy(<String>['ajwain', 'carom'], FoodGroup.other, kcalPer100g: 305),
  FoodEnergy(<String>['tamarind', 'imli', 'chintapandu'], FoodGroup.other,
      kcalPer100g: 239),
  // Vegetables.
  FoodEnergy(<String>['sweet potato'], FoodGroup.vegetables,
      kcalPer100g: 86, gramsPerPiece: 130),
  FoodEnergy(<String>['potato', 'aloo'], FoodGroup.vegetables,
      kcalPer100g: 80, gramsPerPiece: 150),
  FoodEnergy(<String>['spring onion'], FoodGroup.vegetables, kcalPer100g: 32),
  FoodEnergy(<String>['onion', 'pyaz', 'ullipaya'], FoodGroup.vegetables,
      kcalPer100g: 40, gramsPerPiece: 110),
  FoodEnergy(<String>['tomato', 'tamatar'], FoodGroup.vegetables,
      kcalPer100g: 20, gramsPerPiece: 100),
  FoodEnergy(<String>['carrot', 'gajar'], FoodGroup.vegetables,
      kcalPer100g: 41, gramsPerPiece: 70),
  FoodEnergy(<String>['cabbage'], FoodGroup.vegetables, kcalPer100g: 25),
  FoodEnergy(<String>['cauliflower', 'gobi'], FoodGroup.vegetables,
      kcalPer100g: 25),
  FoodEnergy(<String>['brinjal', 'eggplant', 'baingan', 'vankaya'],
      FoodGroup.vegetables,
      kcalPer100g: 25, gramsPerPiece: 150),
  FoodEnergy(<String>['okra', 'ladies finger', 'bhindi', 'bendakaya'],
      FoodGroup.vegetables,
      kcalPer100g: 33),
  FoodEnergy(<String>['spinach', 'palak', 'keerai', 'thotakura'],
      FoodGroup.vegetables,
      kcalPer100g: 23, gramsPerBunch: 250),
  FoodEnergy(<String>['fenugreek leaves', 'methi leaves', 'methi'],
      FoodGroup.vegetables,
      kcalPer100g: 49, gramsPerBunch: 150),
  FoodEnergy(
      <String>['coriander', 'cilantro', 'dhania', 'kothimeera'],
      FoodGroup.vegetables,
      kcalPer100g: 23, gramsPerBunch: 50),
  FoodEnergy(<String>['mint', 'pudina'], FoodGroup.vegetables,
      kcalPer100g: 44, gramsPerBunch: 50),
  FoodEnergy(<String>['curry leaves', 'karivepaku'], FoodGroup.vegetables,
      kcalPer100g: 108, gramsPerBunch: 15),
  FoodEnergy(
      <String>['beans', 'green beans', 'french beans', 'cluster beans', 'gavar'],
      FoodGroup.vegetables,
      kcalPer100g: 31),
  FoodEnergy(<String>['capsicum', 'bell pepper', 'shimla'],
      FoodGroup.vegetables,
      kcalPer100g: 20, gramsPerPiece: 120),
  FoodEnergy(<String>['cucumber', 'kheera', 'dosakaya'], FoodGroup.vegetables,
      kcalPer100g: 15, gramsPerPiece: 250),
  FoodEnergy(<String>['pumpkin', 'kaddu'], FoodGroup.vegetables,
      kcalPer100g: 26),
  FoodEnergy(
      <String>['bottle gourd', 'lauki', 'sorakaya', 'dudhi', 'anapakaya'],
      FoodGroup.vegetables,
      kcalPer100g: 14),
  FoodEnergy(<String>['ridge gourd', 'turai', 'beerakaya'], FoodGroup.vegetables,
      kcalPer100g: 20),
  FoodEnergy(<String>['bitter gourd', 'karela', 'kakarakaya'],
      FoodGroup.vegetables,
      kcalPer100g: 19),
  FoodEnergy(<String>['gourd'], FoodGroup.vegetables, kcalPer100g: 18),
  FoodEnergy(<String>['drumstick', 'moringa'], FoodGroup.vegetables,
      kcalPer100g: 37),
  FoodEnergy(<String>['peas', 'green peas', 'matar'], FoodGroup.vegetables,
      kcalPer100g: 81),
  FoodEnergy(<String>['beetroot'], FoodGroup.vegetables,
      kcalPer100g: 43, gramsPerPiece: 100),
  FoodEnergy(<String>['radish', 'mooli'], FoodGroup.vegetables,
      kcalPer100g: 16),
  FoodEnergy(<String>['garlic', 'lahsun', 'velulli'], FoodGroup.vegetables,
      kcalPer100g: 149),
  FoodEnergy(<String>['ginger', 'adrak', 'allam'], FoodGroup.vegetables,
      kcalPer100g: 80),
  FoodEnergy(
      <String>['green chilli', 'chilli', 'mirchi', 'mirapakaya'],
      FoodGroup.vegetables,
      kcalPer100g: 40),
  FoodEnergy(<String>['lemon', 'lime', 'nimbu', 'nimma'], FoodGroup.vegetables,
      kcalPer100g: 29, gramsPerPiece: 40),
  FoodEnergy(<String>['raw banana', 'plantain'], FoodGroup.vegetables,
      kcalPer100g: 122),
  FoodEnergy(<String>['yam', 'suran', 'elephant foot'], FoodGroup.vegetables,
      kcalPer100g: 118),
  FoodEnergy(<String>['arbi', 'colocasia', 'chamadumpa'], FoodGroup.vegetables,
      kcalPer100g: 112),
  FoodEnergy(<String>['mushroom'], FoodGroup.vegetables, kcalPer100g: 22),
  FoodEnergy(<String>['broccoli'], FoodGroup.vegetables, kcalPer100g: 34),
  FoodEnergy(<String>['zucchini'], FoodGroup.vegetables, kcalPer100g: 17),
  FoodEnergy(<String>['sweet corn', 'corn', 'bhutta'], FoodGroup.vegetables,
      kcalPer100g: 86),
  // Fruits.
  FoodEnergy(<String>['banana', 'kela', 'arati'], FoodGroup.fruits,
      kcalPer100g: 89, gramsPerPiece: 100),
  FoodEnergy(<String>['apple'], FoodGroup.fruits,
      kcalPer100g: 52, gramsPerPiece: 180),
  FoodEnergy(
      <String>['orange', 'mosambi', 'sweet lime', 'kamala', 'santra'],
      FoodGroup.fruits,
      kcalPer100g: 47, gramsPerPiece: 130),
  FoodEnergy(<String>['mango', 'aam'], FoodGroup.fruits,
      kcalPer100g: 60, gramsPerPiece: 180),
  FoodEnergy(<String>['grape', 'angur'], FoodGroup.fruits, kcalPer100g: 69),
  FoodEnergy(<String>['papaya'], FoodGroup.fruits, kcalPer100g: 43),
  FoodEnergy(<String>['watermelon'], FoodGroup.fruits, kcalPer100g: 30),
  FoodEnergy(<String>['muskmelon', 'cantaloupe', 'kharbuja'], FoodGroup.fruits,
      kcalPer100g: 34),
  FoodEnergy(<String>['pomegranate', 'anar'], FoodGroup.fruits,
      kcalPer100g: 83, gramsPerPiece: 100),
  FoodEnergy(<String>['guava', 'amrud', 'jama'], FoodGroup.fruits,
      kcalPer100g: 68, gramsPerPiece: 100),
  FoodEnergy(<String>['pineapple'], FoodGroup.fruits, kcalPer100g: 50),
  FoodEnergy(<String>['pear'], FoodGroup.fruits,
      kcalPer100g: 57, gramsPerPiece: 180),
  FoodEnergy(<String>['kiwi'], FoodGroup.fruits,
      kcalPer100g: 61, gramsPerPiece: 75),
  FoodEnergy(<String>['strawberry', 'strawberries'], FoodGroup.fruits,
      kcalPer100g: 32),
  FoodEnergy(<String>['chikoo', 'sapota', 'sapodilla'], FoodGroup.fruits,
      kcalPer100g: 83, gramsPerPiece: 100),
  FoodEnergy(<String>['custard apple', 'sitaphal'], FoodGroup.fruits,
      kcalPer100g: 94),
  FoodEnergy(<String>['jackfruit', 'panasa'], FoodGroup.fruits,
      kcalPer100g: 95),
  FoodEnergy(<String>['lychee', 'litchi'], FoodGroup.fruits, kcalPer100g: 66),
  FoodEnergy(<String>['berry', 'berries'], FoodGroup.fruits, kcalPer100g: 45),
  FoodEnergy(<String>['juice'], FoodGroup.other, kcalPer100ml: 45),
];

/// Used when no keyword matches: a typical value for the item's category,
/// flagged as a group estimate. Categories not listed have no fallback.
const Map<String, FoodEnergy> kCategoryEnergyFallback = <String, FoodEnergy>{
  'cat_vegetables':
      FoodEnergy(<String>[], FoodGroup.vegetables, kcalPer100g: 35),
  'cat_fruits': FoodEnergy(<String>[], FoodGroup.fruits, kcalPer100g: 60),
  'cat_grains': FoodEnergy(<String>[], FoodGroup.cereals, kcalPer100g: 350),
  'cat_dals': FoodEnergy(<String>[], FoodGroup.pulses, kcalPer100g: 340),
  'cat_oils': FoodEnergy(<String>[], FoodGroup.fats,
      kcalPer100g: 884, kcalPer100ml: 820),
  'cat_meat_eggs':
      FoodEnergy(<String>[], FoodGroup.meatEggs, kcalPer100g: 150),
};

/// Food group when only the category is known (no energy value).
FoodGroup groupForCategory(String categoryId) {
  switch (categoryId) {
    case 'cat_vegetables':
      return FoodGroup.vegetables;
    case 'cat_fruits':
      return FoodGroup.fruits;
    case 'cat_dairy':
      return FoodGroup.dairy;
    case 'cat_grains':
    case 'cat_bakery':
      return FoodGroup.cereals;
    case 'cat_dals':
      return FoodGroup.pulses;
    case 'cat_oils':
      return FoodGroup.fats;
    case 'cat_meat_eggs':
      return FoodGroup.meatEggs;
    default:
      return FoodGroup.other;
  }
}

String _normalise(String text) {
  final String lower = text.toLowerCase();
  final String letters = lower.replaceAll(RegExp(r'[^a-z]+'), ' ').trim();
  return ' $letters ';
}

bool _hasWord(String padded, String keyword) {
  return padded.contains(' $keyword ') ||
      padded.contains(' ${keyword}s ') ||
      padded.contains(' ${keyword}es ');
}

/// The table entry for an item, from its name and aliases. Null when nothing
/// matches.
FoodEnergy? findFoodEnergy(String name, [Iterable<String> aliases = const <String>[]]) {
  final String padded = _normalise('$name ${aliases.join(' ')}');
  for (final FoodEnergy entry in kFoodEnergyTable) {
    for (final String keyword in entry.keywords) {
      if (_hasWord(padded, keyword)) {
        return entry;
      }
    }
  }
  return null;
}

/// The energy of [quantity] [unit] of [food], or null when the amount cannot
/// be turned into grams or millilitres (a packet, a portion, a piece whose
/// weight is not known).
EnergyEstimate? estimateEnergy(FoodEnergy food, double quantity, Unit unit) {
  if (quantity <= 0) {
    return null;
  }
  switch (unit.family) {
    case UnitFamily.mass:
      final double? per = food.kcalPer100g ?? food.kcalPer100ml;
      if (per == null) {
        return null;
      }
      final double g = unit.convertTo(quantity, Unit.g);
      return EnergyEstimate(kcal: g / 100 * per, grams: g);
    case UnitFamily.volume:
      final double? per = food.kcalPer100ml ?? food.kcalPer100g;
      if (per == null) {
        return null;
      }
      final double ml = unit.convertTo(quantity, Unit.ml);
      return EnergyEstimate(kcal: ml / 100 * per);
    case UnitFamily.pieces:
      return _fromPieces(food, quantity);
    case UnitFamily.dozen:
      return _fromPieces(food, quantity * 12);
    case UnitFamily.bunch:
      final double? perBunch = food.gramsPerBunch;
      final double? per = food.kcalPer100g;
      if (perBunch == null || per == null) {
        return null;
      }
      final double g = quantity * perBunch;
      return EnergyEstimate(kcal: g / 100 * per, grams: g);
    case UnitFamily.packet:
    case UnitFamily.portion:
      return null;
  }
}

EnergyEstimate? _fromPieces(FoodEnergy food, double pieces) {
  final double? perPiece = food.gramsPerPiece;
  final double? per = food.kcalPer100g;
  if (perPiece == null || per == null) {
    return null;
  }
  final double g = pieces * perPiece;
  return EnergyEstimate(kcal: g / 100 * per, grams: g);
}
