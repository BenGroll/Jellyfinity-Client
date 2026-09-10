import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfinity/app/DesktopScrollBehavior.dart';

void main() {
  testWidgets('a mouse can reach the end of a horizontal shelf', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const DesktopScrollBehavior(),
        home: Scaffold(
          body: SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              itemExtent: 200,
              itemBuilder: (_, index) => Text('Album $index'),
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final mouse = await tester.startGesture(
      const Offset(650, 60),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(-500, 0));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
  });
}
