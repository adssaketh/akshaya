import 'package:akshaya/core/design/design.dart' show StatusKind;

import '../../../core/util/date_only.dart';
import '../../pantry/domain/entities.dart';
import '../../pantry/domain/stock_logic.dart';
import 'freeze_rules.dart';

/// The sections of the Food rescue list, most urgent first.
enum RescueGroup {
  /// Stock that is past its date: nothing to save, but it can be written off.
  expired('Already expired'),

  /// Stock whose date is today.
  today('Expires today'),

  /// Stock expiring from tomorrow up to the warning window.
  soon('Expiring soon'),

  /// Cooked food still in stock whose date is further away.
  leftovers('Leftovers'),

  /// Opened packs whose date is further away (or missing).
  opened('Opened');

  const RescueGroup(this.label);

  final String label;
}

/// One batch worth acting on.
final class RescueEntry {
  const RescueEntry({
    required this.stock,
    required this.batch,
    required this.group,
    required this.daysLeft,
    required this.openedDaysAgo,
    required this.canFreeze,
  });

  /// The item with all its stock, as the Use sheet needs it.
  final ItemStock stock;

  /// The batch the rescue actions act on.
  final StockBatch batch;

  final RescueGroup group;

  /// Calendar days to the batch's effective expiry (negative when past), or
  /// null when it has no date.
  final int? daysLeft;

  /// Days since the pack was opened, or null when it was not.
  final int? openedDaysAgo;

  /// Whether Freeze is offered for this batch.
  final bool canFreeze;

  Item get item => stock.item;

  bool get isExpired => daysLeft != null && daysLeft! < 0;

  /// "Fridge · 2 kg left · steel dabba · opened 3d ago".
  String get subtitle {
    final String? container = batch.containerLabel;
    final int? opened = openedDaysAgo;
    return <String>[
      if (item.kind.isMadeAtHome) item.kind.label,
      batch.storageLocation.label,
      '${batch.unit.format(batch.quantityRemaining)} left',
      if (container != null && container.isNotEmpty) container,
      if (opened != null) opened == 0 ? 'opened today' : 'opened ${opened}d ago',
    ].join(' · ');
  }

  /// The status chip kind for the card.
  StatusKind get status {
    final int? days = daysLeft;
    if (days == null) {
      return StatusKind.fresh;
    }
    if (days < 0) {
      return StatusKind.expired;
    }
    return group == RescueGroup.today || group == RescueGroup.soon
        ? StatusKind.expiring
        : StatusKind.fresh;
  }

  /// The chip text: "Today", "In 2 days", "Expired 3d ago", "No date".
  String get statusLabel {
    final int? days = daysLeft;
    if (days == null) {
      return 'No date';
    }
    if (days < 0) {
      return StockLogic.expiredLabel(-days);
    }
    return StockLogic.expiringLabel(days);
  }
}

/// Works out the Food rescue list. Pure Dart.
abstract final class FoodRescue {
  /// Every batch worth acting on for [today], grouped in [RescueGroup] order
  /// and sorted by date within a group (soonest first, no date last, then by
  /// name).
  ///
  /// A batch appears once, in the first group that fits: expired, today,
  /// soon, then leftovers (cooked food) and opened packs.
  static List<RescueEntry> build({
    required List<ItemStock> stocks,
    required DateTime today,
    required int warningDays,
    required FreezeSettings freeze,
  }) {
    final DateTime day = dateOnly(today);
    final List<RescueEntry> out = <RescueEntry>[];
    for (final ItemStock stock in stocks) {
      for (final StockBatch batch in stock.inStock) {
        final DateTime? expiry = batch.effectiveExpiry;
        final int? days = expiry == null ? null : daysBetween(day, expiry);
        final DateTime? openedOn = batch.openedDate;
        final int? openedAgo =
            openedOn == null ? null : daysBetween(openedOn, day);

        final RescueGroup? group = _groupFor(
          days: days,
          warningDays: warningDays,
          isLeftover: stock.item.isLeftover,
          isOpened: openedOn != null,
        );
        if (group == null) {
          continue;
        }
        out.add(
          RescueEntry(
            stock: stock,
            batch: batch,
            group: group,
            daysLeft: days,
            openedDaysAgo: openedAgo,
            canFreeze: Freezer.canFreeze(
              item: stock.item,
              batch: batch,
              settings: freeze,
              today: day,
            ),
          ),
        );
      }
    }
    out.sort(_compare);
    return out;
  }

  static RescueGroup? _groupFor({
    required int? days,
    required int warningDays,
    required bool isLeftover,
    required bool isOpened,
  }) {
    if (days != null) {
      if (days < 0) {
        return RescueGroup.expired;
      }
      if (days == 0) {
        return RescueGroup.today;
      }
      if (days <= warningDays) {
        return RescueGroup.soon;
      }
    }
    if (isLeftover) {
      return RescueGroup.leftovers;
    }
    if (isOpened) {
      return RescueGroup.opened;
    }
    return null;
  }

  static int _compare(RescueEntry a, RescueEntry b) {
    final int byGroup = a.group.index.compareTo(b.group.index);
    if (byGroup != 0) {
      return byGroup;
    }
    final int? da = a.daysLeft;
    final int? db = b.daysLeft;
    if (da != null && db != null && da != db) {
      return da.compareTo(db);
    }
    if (da != null && db == null) {
      return -1;
    }
    if (da == null && db != null) {
      return 1;
    }
    return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  }

  /// The entries of [group], in order.
  static List<RescueEntry> inGroup(List<RescueEntry> entries, RescueGroup g) {
    return <RescueEntry>[
      for (final RescueEntry e in entries)
        if (e.group == g) e,
    ];
  }
}
