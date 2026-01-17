import 'package:flutter_test/flutter_test.dart';
import 'package:namkeen_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NamkeenFactoryApp(currentVersion: '1.0.0+1'));
  });
}
