import 'package:flutter_test/flutter_test.dart';

import 'package:capy_notes/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const CapyNotesApp());
    await tester.pump();

    expect(find.text('Capy Notes'), findsOneWidget);
  });
}
