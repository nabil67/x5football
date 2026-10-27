import 'package:flutter_test/flutter_test.dart';
import 'package:x5football/app.dart';
import 'package:x5football/config/app_config.dart';

void main() {
  testWidgets("l'application démarre", (tester) async {
    const config = AppConfig(
      environment: AppEnvironment.test,
      supabaseUrl: 'http://localhost:54321',
      supabasePublishableKey: 'sb_publishable_test',
    );
    await tester.pumpWidget(const X5FootballApp(config: config));
    expect(find.text('x5football'), findsOneWidget);
  });
}
