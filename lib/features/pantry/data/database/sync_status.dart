/// Local-only state of a row with respect to cloud sync (Phase 6). Stored as
/// text; every row starts as [pending] until it has been pushed.
enum SyncStatus { pending, synced, conflict }
