import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindreader/design_system/taro.dart';

/// Тесты логики компонентов Tarot Tree.
///
/// Компоненты проверяются в режиме [TaroGlassMode.simple], чтобы тесты были
/// детерминированными и не зависели от GPU/шейдеров (рендеринг собственно
/// стекла — ответственность liquid_glass_renderer). Семантика и обработчики
/// проверяются на обычных виджетах.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: TaroGlassLayer(mode: TaroGlassMode.simple, child: child),
  ),
);

void main() {
  testWidgets('button fires onPressed when enabled', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(TaroGlassButton(label: 'Primary', onPressed: () => tapped++)),
    );
    await tester.tap(find.text('Primary'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('disabled button does not fire', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(TaroGlassButton(label: 'Disabled', onPressed: null)),
    );
    await tester.tap(find.text('Disabled'));
    await tester.pump();
    expect(tapped, 0);
  });

  testWidgets('loading button shows a spinner and blocks tap', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _wrap(TaroGlassButton(label: 'Loading', loading: true, onPressed: () => tapped++)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Loading'));
    await tester.pump();
    expect(tapped, 0);
  });

  testWidgets('segmented control reports selection', (tester) async {
    int? changed;
    await tester.pumpWidget(
      _wrap(
        TaroGlassSegmentedControl<int>(
          segments: const [
            TaroGlassSegment(value: 0, label: 'A'),
            TaroGlassSegment(value: 1, label: 'B'),
            TaroGlassSegment(value: 2, label: 'C'),
          ],
          value: 0,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(changed, 1);
  });

  testWidgets('input shows error text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TaroGlassInput(hint: 'Email', errorText: 'Please enter a valid email'),
      ),
    );
    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('dock reports tapped index', (tester) async {
    int? idx;
    await tester.pumpWidget(
      _wrap(
        TaroGlassDock(
          items: const [
            TaroDockItem(icon: Icons.abc, label: 'A'),
            TaroDockItem(icon: Icons.abc, label: 'B'),
            TaroDockItem(icon: Icons.abc, label: 'C'),
          ],
          index: 0,
          onTap: (i) => idx = i,
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(idx, 1);
  });

  testWidgets('select opens a sheet and reports choice', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _wrap(
        TaroGlassSelect<String>(
          value: 'rider',
          options: const [
            TaroSelectOption(value: 'rider', label: 'Rider–Waite'),
            TaroSelectOption(value: 'marseille', label: 'Marseille'),
          ],
          onChanged: (v) => selected = v,
        ),
      ),
    );
    expect(find.text('Rider–Waite'), findsOneWidget);

    await tester.tap(find.text('Rider–Waite'));
    await tester.pumpAndSettle();
    expect(find.text('Marseille'), findsOneWidget);

    await tester.tap(find.text('Marseille'));
    await tester.pumpAndSettle();
    expect(selected, 'marseille');
  });
}
