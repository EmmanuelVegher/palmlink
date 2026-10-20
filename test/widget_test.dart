import 'package:flutter_test/flutter_test.dart';
import 'package:palmlink/main.dart';

void main() {
  testWidgets('PalmLink app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PalmLinkApp());
    expect(find.text('Select Hospital Facility'), findsOneWidget);
  });
}
