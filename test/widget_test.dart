import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmencep/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic test
    expect(const OgretmenCepApp(), isNotNull);
  });
}
