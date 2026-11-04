/// Keys of the sync settings in the local settings table (never synced).
abstract final class SyncSettingKeys {
  /// "true" or "false"; sync is on unless switched off.
  static const String enabled = 'sync.enabled';

  static const String userName = 'sync.userName';
  static const String userEmail = 'sync.userEmail';
  static const String householdName = 'sync.householdName';
  static const String inviteCode = 'sync.inviteCode';

  /// The household this phone last synced with, so a different one asks what
  /// to do with the data already here.
  static const String lastHouseholdId = 'sync.lastHouseholdId';

  /// Estimated Firestore use today (Phase 8 shows it in Settings > Usage).
  static const String usageDate = 'usage.fs.date';
  static const String usageReads = 'usage.fs.reads';
  static const String usageWrites = 'usage.fs.writes';
}

/// The saved sync settings, with defaults for anything missing.
final class SyncSettings {
  const SyncSettings({
    this.enabled = true,
    this.userName,
    this.userEmail,
    this.householdName,
    this.inviteCode,
    this.lastHouseholdId,
  });

  factory SyncSettings.fromMap(Map<String, String> map) {
    String? text(String key) {
      final String? value = map[key];
      return value == null || value.isEmpty ? null : value;
    }

    return SyncSettings(
      enabled: map[SyncSettingKeys.enabled] != 'false',
      userName: text(SyncSettingKeys.userName),
      userEmail: text(SyncSettingKeys.userEmail),
      householdName: text(SyncSettingKeys.householdName),
      inviteCode: text(SyncSettingKeys.inviteCode),
      lastHouseholdId: text(SyncSettingKeys.lastHouseholdId),
    );
  }

  final bool enabled;
  final String? userName;
  final String? userEmail;
  final String? householdName;
  final String? inviteCode;
  final String? lastHouseholdId;
}

/// Firestore reads and writes this phone made today (an estimate).
final class FirestoreUsage {
  const FirestoreUsage({this.date, this.reads = 0, this.writes = 0});

  factory FirestoreUsage.fromMap(Map<String, String> map) {
    return FirestoreUsage(
      date: map[SyncSettingKeys.usageDate],
      reads: int.tryParse(map[SyncSettingKeys.usageReads] ?? '') ?? 0,
      writes: int.tryParse(map[SyncSettingKeys.usageWrites] ?? '') ?? 0,
    );
  }

  /// `yyyy-MM-dd` of the day the counts are for.
  final String? date;
  final int reads;
  final int writes;

  /// The usage after adding [moreReads] and [moreWrites] on [today]. A new day
  /// starts from zero.
  FirestoreUsage add(String today, {int moreReads = 0, int moreWrites = 0}) {
    final bool sameDay = date == today;
    return FirestoreUsage(
      date: today,
      reads: (sameDay ? reads : 0) + moreReads,
      writes: (sameDay ? writes : 0) + moreWrites,
    );
  }

  Map<String, String> toMap() => <String, String>{
        SyncSettingKeys.usageDate: date ?? '',
        SyncSettingKeys.usageReads: reads.toString(),
        SyncSettingKeys.usageWrites: writes.toString(),
      };
}
