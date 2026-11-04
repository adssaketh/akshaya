import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Opens the app's SQLite database (`akshaya.sqlite` in the documents folder).
///
/// The app and the background alert check each open this same file. A short
/// wait for a busy file keeps one of them from failing with "database is
/// locked" while the other is writing.
AppDatabase openAppDatabase() {
  return AppDatabase(
    driftDatabase(
      name: 'akshaya',
      native: DriftNativeOptions(
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000');
        },
      ),
    ),
  );
}
