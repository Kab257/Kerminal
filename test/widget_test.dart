import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/main.dart';

void main() {
  testWidgets('Kerminal displays terminal interface', (tester) async {
    await tester.pumpWidget(const KerminalApp());

    expect(find.text('Kerminal'), findsOneWidget);
    expect(find.text('Kerminal v0.2.0'), findsOneWidget);
    expect(find.text('Enter command...'), findsOneWidget);
  });
}
