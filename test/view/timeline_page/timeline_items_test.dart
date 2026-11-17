import "dart:collection";

import "package:flutter_test/flutter_test.dart";
import "package:dmsky_client/view/time_line_page/timeline_items.dart";

void main() {
  test("empty timelines expose only the history loading position", () {
    const items = TimelineItems<int>(older: [], newer: []);
    expect(items.length, 0);
    expect(items.olderCount, 0);
    expect(items[0], isNull);
    expect(items[1], isNull);
    expect(items[-1], isNull);
  });

  test("recent history precedes streamed notes without changing order", () {
    const items = TimelineItems(
      older: ["a", "b", "c", "d", "e", "f", "g"],
      newer: ["x", "y"],
    );
    expect(items.length, 9);
    expect(items.olderCount, 2);
    expect(
      [for (var i = 1; i <= 7; i++) items[i]],
      ["e", "d", "c", "b", "a", "x", "y"],
    );
    expect(items[0], "f");
    expect(items[-1], "g");
    expect(items[-2], isNull);
    expect(items[8], isNull);
  });

  test("short history and new notes share the positive side", () {
    const items = TimelineItems(older: ["a", "b"], newer: ["x"]);
    expect(items.olderCount, 0);
    expect([items[1], items[2], items[3]], ["b", "a", "x"]);
    expect(items[0], isNull);
    expect(items[4], isNull);
  });

  test("exactly five history notes leave the loading row at zero", () {
    const items = TimelineItems<int>(older: [0, 1, 2, 3, 4], newer: []);
    expect(items.olderCount, 0);
    expect([for (var i = 1; i <= 5; i++) items[i]], [4, 3, 2, 1, 0]);
    expect(items[0], isNull);
  });

  test("the index follows live list changes", () {
    final older = ["a"];
    final newer = <String>[];
    final items = TimelineItems(older: older, newer: newer);
    newer.add("x");
    expect(items[2], "x");
    older.insert(0, "b");
    expect([items[1], items[2], items[3]], ["a", "b", "x"]);
    expect(items.length, 3);
  });

  test("looking up a row touches only that note in large histories", () {
    final older = _CountingList(1000000);
    final newer = _CountingList(1000000);
    final items = TimelineItems(older: older, newer: newer);
    expect(items[1], 4);
    expect(items[0], 5);
    expect(items[6], 0);
    expect(items[-999995], isNull);
    expect(older.reads, 2);
    expect(newer.reads, 1);
  });
}

class _CountingList extends ListBase<int> {
  _CountingList(this._length);

  final int _length;
  int reads = 0;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError("read only");

  @override
  int operator [](int index) {
    RangeError.checkValidIndex(index, this);
    reads++;
    return index;
  }

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError("read only");
}
