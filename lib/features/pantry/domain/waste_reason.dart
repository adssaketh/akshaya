/// Why food was thrown away. The enum [name] is what the database stores in
/// `consumption_logs.waste_reason`, so never rename a value without a
/// migration.
///
/// Logs written before reasons existed (and waste logged without picking one)
/// have no stored reason; reports show them as [unspecified], which is never
/// stored.
enum WasteReason {
  /// It passed its date before it was used.
  expired('Expired'),

  /// It went off, spoiled or was found bad before its date.
  spoiled('Spoiled'),

  /// It was forgotten at the back of the shelf.
  forgot('Forgot about it'),

  /// More was bought than could be eaten.
  boughtTooMuch('Bought too much'),

  /// Anything else.
  other('Other'),

  /// Reports only: waste with no recorded reason. Never stored.
  unspecified('Not recorded');

  const WasteReason(this.label);

  final String label;

  /// The reasons a person can pick, in the order they are offered.
  static const List<WasteReason> choices = <WasteReason>[
    WasteReason.expired,
    WasteReason.spoiled,
    WasteReason.forgot,
    WasteReason.boughtTooMuch,
    WasteReason.other,
  ];

  /// The choices for food that has not passed its date yet: it cannot have
  /// "expired".
  static const List<WasteReason> choicesBeforeExpiry = <WasteReason>[
    WasteReason.spoiled,
    WasteReason.forgot,
    WasteReason.boughtTooMuch,
    WasteReason.other,
  ];

  /// The reason stored as [text] (an enum name), or null for null, an unknown
  /// value or [unspecified] (which is never stored).
  static WasteReason? fromName(String? text) {
    for (final WasteReason reason in WasteReason.choices) {
      if (reason.name == text) {
        return reason;
      }
    }
    return null;
  }
}
