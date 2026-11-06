import '../../../core/util/date_only.dart';
import '../../pantry/domain/storage_location.dart';
import '../../pantry/domain/unit.dart';

/// One bought product as read from an order screenshot, before it is matched
/// to anything in the pantry.
final class OrderRow {
  const OrderRow({
    required this.rawName,
    required this.quantity,
    required this.unit,
    required this.sizeKnown,
    this.price,
    this.truncated = false,
    this.hints = const <String>[],
  });

  /// The product name as printed (without the "..." the app cut it with).
  final String rawName;

  /// Everything bought on this line, in [unit] (pack size times packs).
  final double quantity;
  final Unit unit;

  /// False when the screenshot shows no pack size, so [quantity] only counts
  /// packs.
  final bool sizeKnown;

  /// What was paid for the whole line (the lower of two shown prices).
  final double? price;

  /// The shop's app cut the name short ("Tata Sampann Toor/A...").
  final bool truncated;

  /// Text read from the product's thumbnail, used only to identify a cut name.
  final List<String> hints;
}

/// The quick-commerce apps this reads. The guess only fills the store field;
/// it can be changed on the review screen.
enum OrderStore {
  blinkit('Blinkit'),
  zepto('Zepto'),
  amazonNow('Amazon Now'),
  instamart('Swiggy Instamart'),
  flipkartMinutes('Flipkart Minutes');

  const OrderStore(this.label);

  final String label;

  static final RegExp _flipkart =
      RegExp(r'order\s+delivered\s*!', caseSensitive: false);
  static final RegExp _zeptoRate =
      RegExp(r'rate\s+order', caseSensitive: false);
  static final RegExp _zeptoAgain =
      RegExp(r'order\s+again', caseSensitive: false);
  static final RegExp _blinkit =
      RegExp(r'items?\s+in\s+this\s+order', caseSensitive: false);
  static final RegExp _instamart = RegExp(
    r'total\s+order\s+bill\s+details|completed\s*\|\s*\d+\s*items?',
    caseSensitive: false,
  );
  static final RegExp _amazon = RegExp(
    r'delivered\s+in\s+\d+\s+minutes?|\d+\s*items?\s+in\s+order',
    caseSensitive: false,
  );

  /// Which app a screenshot came from, judged by its fixed headings, or null.
  static OrderStore? guess(Iterable<String> lines) {
    final String text = lines.join('\n');
    if (_flipkart.hasMatch(text)) {
      return OrderStore.flipkartMinutes;
    }
    if (_zeptoRate.hasMatch(text) && _zeptoAgain.hasMatch(text)) {
      return OrderStore.zepto;
    }
    if (_blinkit.hasMatch(text)) {
      return OrderStore.blinkit;
    }
    if (_instamart.hasMatch(text)) {
      return OrderStore.instamart;
    }
    if (_amazon.hasMatch(text)) {
      return OrderStore.amazonNow;
    }
    return null;
  }
}

/// Why a line is not ticked by default.
enum SkipReason {
  notFood('Not food'),
  notVegetarian('Not vegetarian');

  const SkipReason(this.label);

  final String label;
}

/// Something about a line the person should look at.
enum DraftNote {
  /// The shop's app cut the name and it could not be worked out.
  nameCutOff('Name was cut off, please check it'),

  /// The screenshot shows no pack size, only how many packs.
  amountNotShown('Pack size not shown, please check the amount'),

  /// No price was found for the line.
  priceNotFound('Price not found');

  const DraftNote(this.message);

  final String message;
}

/// One line of the review screen: what will be added to the pantry.
final class OrderDraft {
  const OrderDraft({
    required this.id,
    required this.sourceName,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.categoryId,
    required this.location,
    required this.include,
    this.brand,
    this.price,
    this.expiry,
    this.estimateDays,
    this.skip,
    this.matchedItemId,
    this.notes = const <DraftNote>[],
  });

  final String id;

  /// The name as it was printed in the screenshot.
  final String sourceName;

  /// The English pantry name.
  final String name;
  final String? brand;
  final double quantity;
  final Unit unit;

  /// Total paid for the line.
  final double? price;
  final String categoryId;
  final StorageLocation location;

  /// A date the person chose or typed.
  final DateTime? expiry;

  /// Days after the purchase that fresh food usually keeps, as a guess. Used
  /// when [expiry] is not set.
  final int? estimateDays;
  final bool include;

  /// Set for lines that start unticked because they are not food or not
  /// vegetarian.
  final SkipReason? skip;

  /// The pantry item this line adds stock to, when one matched.
  final String? matchedItemId;
  final List<DraftNote> notes;

  /// The expiry date to save for a purchase on [boughtOn]: the chosen date,
  /// else the guess, else none.
  DateTime? effectiveExpiry(DateTime boughtOn) {
    final DateTime? chosen = expiry;
    if (chosen != null) {
      return chosen;
    }
    final int? days = estimateDays;
    return days == null ? null : addDays(dateOnly(boughtOn), days);
  }

  /// True when the shown expiry is only a guess.
  bool get expiryIsGuess => expiry == null && estimateDays != null;

  OrderDraft copyWith({
    String? name,
    String? brand,
    bool clearBrand = false,
    double? quantity,
    Unit? unit,
    double? price,
    bool clearPrice = false,
    String? categoryId,
    StorageLocation? location,
    DateTime? expiry,
    bool clearExpiry = false,
    bool? include,
    List<DraftNote>? notes,
  }) {
    return OrderDraft(
      id: id,
      sourceName: sourceName,
      name: name ?? this.name,
      brand: clearBrand ? null : (brand ?? this.brand),
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: clearPrice ? null : (price ?? this.price),
      categoryId: categoryId ?? this.categoryId,
      location: location ?? this.location,
      expiry: clearExpiry ? null : (expiry ?? this.expiry),
      // Choosing or clearing a date replaces the guess.
      estimateDays: (expiry != null || clearExpiry) ? null : estimateDays,
      include: include ?? this.include,
      skip: skip,
      matchedItemId: matchedItemId,
      notes: notes ?? this.notes,
    );
  }
}
