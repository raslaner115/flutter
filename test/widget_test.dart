import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:untitled1/main.dart';
import 'package:untitled1/services/language_provider.dart';
import 'package:untitled1/widgets/splash_screen.dart';

void main() {
  testWidgets('MyApp shows splash screen while initialization is in progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const MyApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
