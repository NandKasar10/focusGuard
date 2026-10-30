import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('FocusGuardApp builds cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusGuardApp());
    expect(find.byType(FocusGuardApp), findsOneWidget);
  });
}
