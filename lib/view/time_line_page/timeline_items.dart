/// Indexes the two halves of the timeline without copying their note lists.
///
/// Positive indices show the five most recent older notes in reverse order,
/// followed by streaming notes. Zero and negative indices show older history.
class TimelineItems<T extends Object> {
  final List<T> older;
  final List<T> newer;

  const TimelineItems({required this.older, required this.newer});

  int get _recentCount => older.length < 5 ? older.length : 5;

  int get olderCount => older.length - _recentCount;

  int get length => older.length + newer.length;

  /// Returns null beyond either end, including the history loading row.
  T? operator [](int index) {
    final recentCount = _recentCount;
    if (index > 0) {
      final position = index - 1;
      if (position < recentCount) return older[recentCount - position - 1];
      final newerIndex = position - recentCount;
      return newerIndex < newer.length ? newer[newerIndex] : null;
    }
    final olderIndex = recentCount - index;
    return olderIndex < older.length ? older[olderIndex] : null;
  }
}
