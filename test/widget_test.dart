import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_tracker/app/app.dart';

void main() {
  testWidgets('FinTrack application loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PersonalFinanceApp());

    expect(find.text('FinTrack'), findsOneWidget);
  });
}