import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/core/services/local_storage_service.dart';

void main() {
  test('computeStreak counts consecutive days ending today', () {
    final today = DateTime(2026, 11, 16);
    expect(
      computeStreak(
        [
          '2026-11-16',
          '2026-11-15',
          '2026-11-14',
          '2026-11-12', // gap breaks the run
          '2026-11-11',
        ],
        today: today,
      ),
      3,
    );
  });

  test('a ritual due later today does not break the streak', () {
    final today = DateTime(2026, 11, 16);
    expect(
      computeStreak(
        ['2026-11-15', '2026-11-14', '2026-11-13'],
        today: today,
      ),
      3,
    );
  });

  test('no readings today or yesterday → zero streak', () {
    final today = DateTime(2026, 11, 16);
    expect(
      computeStreak(['2026-11-10', '2026-11-09'], today: today),
      0,
    );
    expect(computeStreak(const [], today: today), 0);
  });
}
