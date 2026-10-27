import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/app_version_footer.dart';
import 'package:personal_ia/core/widgets/pwa_update_wrapper.dart';
import 'package:personal_ia/main.dart';
import 'package:personal_ia/features/landing/trainer_public_landing_screen.dart';
import 'package:personal_ia/features/referral/screens/referral_landing_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppVersionFooter.enableAutoModal = false;
    PwaUpdateWrapper.enableAutoCheck = false;
  });

  tearDown(() {
    AppVersionFooter.enableAutoModal = true;
    PwaUpdateWrapper.enableAutoCheck = true;
  });

  testWidgets('B2BPersonalIaApp routes /p/mrcoach to TrainerPublicLandingScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const B2BPersonalIaApp(
        initialRouteOverride: '/p/mrcoach',
      ),
    );
    await tester.pump();

    expect(find.byType(TrainerPublicLandingScreen), findsOneWidget);
  });

  testWidgets('B2BPersonalIaApp routes /r/PARCEIRO to ReferralLandingScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const B2BPersonalIaApp(
        initialRouteOverride: '/r/PARCEIRO',
      ),
    );
    await tester.pump();

    expect(find.byType(ReferralLandingScreen), findsOneWidget);
  });
}
