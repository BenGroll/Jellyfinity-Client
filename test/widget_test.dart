import 'package:flutter_test/flutter_test.dart';

import 'package:jellyfinity/main.dart';

void main() {
  testWidgets('shows the development shell', (WidgetTester tester) async {
    await tester.pumpWidget(const JellyfinityApp());

    expect(find.text('Jellyfinity'), findsOneWidget);
    expect(find.text('Development environment ready'), findsOneWidget);
  });
}
