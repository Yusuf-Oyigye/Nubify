
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

void main() {
  final engine = fsrs.Scheduler(
    enableFuzzing: false,
  );

  //===================================================
  // TEST FSRS REVIEW RATINGS
  //===================================================

  test('All four ratings generate future due dates', () {
    final now = DateTime.utc(2026, 10, 23, 12);

    final dates = <fsrs.Rating, DateTime>{};

    for (final rating in fsrs.Rating.values) {
      final card = fsrs.Card(cardId: 123);

      final result = engine.reviewCard(
        card,
        rating,
        reviewDateTime: now,
      );

      expect(
        result.card.due.isAfter(now),
        isTrue,
      );

      dates[rating] = result.card.due;
    }

    expect(
      dates[fsrs.Rating.again]!.isBefore(
        dates[fsrs.Rating.easy]!,
      ),
      isTrue,
    );
  });

  //===================================================
  // TEST SCHEDULING SERIALIZATION
  //===================================================

  test('FSRS card data survives serialization', () {
    final original = fsrs.Card(cardId: 991);

    final serialized = original.toMap();

    final restored = fsrs.Card.fromMap(serialized);

    expect(restored.cardId, 991);
    expect(restored.state, original.state);
  });
}
