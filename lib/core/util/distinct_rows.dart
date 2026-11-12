/// Drops a query result that is the same, row for row, as the one before it.
///
/// A watched Drift query runs again whenever any table it reads from is
/// touched, even when nothing it returns changed (a sync pass, the app coming
/// back from the background). Each run builds new lists, so every screen and
/// provider downstream would rebuild for nothing. Drift's generated row
/// classes compare by value, so an unchanged result can be recognised here
/// and skipped before any of that work starts.
extension DistinctRows<T> on Stream<List<T>> {
  Stream<List<T>> distinctRows() => distinct(sameRows);
}

/// True when [a] and [b] hold equal rows in the same order.
bool sameRows<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
