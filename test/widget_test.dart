import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_it/app.dart';
<<<<<<< HEAD
import 'package:split_it/features/auth/presentation/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
<<<<<<< HEAD
    GoogleFonts.config.allowRuntimeFetching = false;
=======
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

<<<<<<< HEAD
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SplitItApp()),
    );
    await tester.pumpAndSettle();
=======
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SplitItApp()));
    await tester.pump();
>>>>>>> 256bad7a74c0ded4604d24e4f10508428fe75ac3

    expect(find.byType(SplitItApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
