import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saving and opening files through the Android system file picker (storage
/// access framework). A seam so tests do not need the platform.
abstract interface class BackupFiles {
  /// Lets the person choose where to save [bytes]. Returns false when they
  /// cancelled.
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String dialogTitle,
  });

  /// Lets the person choose a `.json` backup. Null when cancelled.
  Future<Uint8List?> pickBackup();
}

class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
    required String dialogTitle,
  }) async {
    final String? path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );
    return path != null;
  }

  @override
  Future<Uint8List?> pickBackup() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final PlatformFile file = result.files.single;
    return file.bytes ?? await file.xFile.readAsBytes();
  }
}

final Provider<BackupFiles> backupFilesProvider =
    Provider<BackupFiles>((Ref ref) => const PlatformBackupFiles());
