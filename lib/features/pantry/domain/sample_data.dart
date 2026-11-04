import 'storage_location.dart';
import 'unit.dart';

/// One purchase of a sample item, with dates relative to "today" so the
/// sample data always shows every status.
final class SampleStock {
  const SampleStock({
    required this.quantityBought,
    required this.quantityRemaining,
    required this.purchasedDaysAgo,
    this.expiresInDays,
    this.openedDaysAgo,
    this.useWithinDays,
    this.price,
    this.store,
    this.location,
  });

  final double quantityBought;
  final double quantityRemaining;
  final int purchasedDaysAgo;

  /// Negative values mean already expired.
  final int? expiresInDays;
  final int? openedDaysAgo;
  final int? useWithinDays;
  final double? price;
  final String? store;
  final StorageLocation? location;
}

/// A sample grocery item with aliases in Telugu and Hindi (script and
/// romanised).
final class SampleItem {
  const SampleItem({
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.aliases,
    required this.stocks,
    this.lowStockThreshold,
    this.isEssential = false,
    this.location = StorageLocation.pantry,
  });

  final String name;
  final String categoryId;
  final Unit unit;
  final List<String> aliases;
  final List<SampleStock> stocks;
  final double? lowStockThreshold;
  final bool isEssential;
  final StorageLocation location;
}

/// Ten everyday Indian grocery items covering every status: fresh, expiring
/// soon (Milk), expired (Curd), low stock (Toor Dal, Onion) and out of stock
/// (Tomato).
const List<SampleItem> kSampleItems = <SampleItem>[
  SampleItem(
    name: 'Basmati Rice',
    categoryId: 'cat_grains',
    unit: Unit.kg,
    aliases: <String>['బియ్యం', 'biyyam', 'चावल', 'chawal'],
    lowStockThreshold: 2,
    isEssential: true,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 5,
        quantityRemaining: 3.5,
        purchasedDaysAgo: 20,
        expiresInDays: 300,
        price: 650,
        store: 'DMart',
      ),
    ],
  ),
  SampleItem(
    name: 'Toor Dal',
    categoryId: 'cat_dals',
    unit: Unit.kg,
    aliases: <String>['కందిపప్పు', 'kandi pappu', 'अरहर', 'arhar'],
    lowStockThreshold: 1,
    isEssential: true,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 2,
        quantityRemaining: 0.75,
        purchasedDaysAgo: 30,
        expiresInDays: 180,
        price: 290,
        store: 'DMart',
      ),
    ],
  ),
  SampleItem(
    name: 'Milk',
    categoryId: 'cat_dairy',
    unit: Unit.l,
    aliases: <String>['పాలు', 'paalu', 'दूध', 'doodh'],
    lowStockThreshold: 0.5,
    isEssential: true,
    location: StorageLocation.fridge,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 1,
        quantityRemaining: 1,
        purchasedDaysAgo: 1,
        expiresInDays: 2,
        price: 33,
        store: 'Milk booth',
        location: StorageLocation.fridge,
      ),
    ],
  ),
  SampleItem(
    name: 'Curd',
    categoryId: 'cat_dairy',
    unit: Unit.g,
    aliases: <String>['పెరుగు', 'perugu', 'दही', 'dahi'],
    location: StorageLocation.fridge,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 400,
        quantityRemaining: 250,
        purchasedDaysAgo: 6,
        expiresInDays: -1,
        price: 30,
        store: 'Milk booth',
        location: StorageLocation.fridge,
      ),
    ],
  ),
  SampleItem(
    name: 'Onion',
    categoryId: 'cat_vegetables',
    unit: Unit.kg,
    aliases: <String>['ఉల్లిపాయ', 'ullipaya', 'प्याज', 'pyaaz'],
    lowStockThreshold: 1,
    isEssential: true,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 3,
        quantityRemaining: 0.5,
        purchasedDaysAgo: 10,
        expiresInDays: 10,
        price: 90,
        store: 'Rythu Bazaar',
      ),
    ],
  ),
  SampleItem(
    name: 'Tomato',
    categoryId: 'cat_vegetables',
    unit: Unit.kg,
    aliases: <String>['టమాటా', 'tamata', 'टमाटर', 'tamatar'],
    lowStockThreshold: 0.5,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 1,
        quantityRemaining: 0,
        purchasedDaysAgo: 5,
        expiresInDays: -2,
        price: 40,
        store: 'Rythu Bazaar',
      ),
    ],
  ),
  SampleItem(
    name: 'Ghee',
    categoryId: 'cat_oils',
    unit: Unit.g,
    aliases: <String>['నెయ్యి', 'neyyi', 'घी', 'ghee'],
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 500,
        quantityRemaining: 450,
        purchasedDaysAgo: 15,
        expiresInDays: 150,
        openedDaysAgo: 5,
        useWithinDays: 90,
        price: 340,
        store: 'DMart',
      ),
    ],
  ),
  SampleItem(
    name: 'Turmeric Powder',
    categoryId: 'cat_spices',
    unit: Unit.g,
    aliases: <String>['పసుపు', 'pasupu', 'हल्दी', 'haldi'],
    lowStockThreshold: 50,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 200,
        quantityRemaining: 150,
        purchasedDaysAgo: 40,
        expiresInDays: 400,
        price: 55,
        store: 'DMart',
      ),
    ],
  ),
  SampleItem(
    name: 'Wheat Flour (Atta)',
    categoryId: 'cat_grains',
    unit: Unit.kg,
    aliases: <String>['గోధుమ పిండి', 'godhuma pindi', 'आटा', 'atta'],
    lowStockThreshold: 1,
    isEssential: true,
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 5,
        quantityRemaining: 4,
        purchasedDaysAgo: 8,
        expiresInDays: 120,
        price: 245,
        store: 'DMart',
      ),
    ],
  ),
  SampleItem(
    name: 'Peanuts',
    categoryId: 'cat_snacks',
    unit: Unit.kg,
    aliases: <String>['పల్లీలు', 'pallilu', 'मूंगफली', 'moongphali'],
    stocks: <SampleStock>[
      SampleStock(
        quantityBought: 1,
        quantityRemaining: 0.6,
        purchasedDaysAgo: 12,
        expiresInDays: 45,
        price: 140,
        store: 'Ratnadeep',
      ),
    ],
  ),
];
