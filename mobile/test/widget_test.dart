import 'package:flutter_test/flutter_test.dart';
import 'package:resiliencemesh/main.dart';

void main() {
  testWidgets('ResilienceMeshApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ResilienceMeshApp());
    expect(find.byType(ResilienceMeshApp), findsOneWidget);
  });
}
