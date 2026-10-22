import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/auth_service.dart';
import 'package:personal_ia/features/auth/login_screen.dart';
import 'package:personal_ia/features/auth/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Professor Cleudson Cavalcante SuperAdmin & Trainer Access Tests', () {
    test('availableRoles recognizes all Cleudson accounts as trainer and admin', () {
      final hotmailProfile = {
        'id': '92dfd58c-845f-473e-b846-a2b8fdd3e508',
        'email': 'cleudsonx@hotmail.com',
        'full_name': 'Prof. Cleudson Cavalcante',
        'role': 'trainer',
      };
      final hotmailRoles = AuthService.availableRoles(hotmailProfile);
      expect(hotmailRoles, contains('trainer'));
      expect(hotmailRoles, contains('admin'));

      final mrcoachProfile = {
        'id': '6f645308-f1b2-4d73-ac45-9890c27e20d4',
        'email': 'cleudsonx2021@gmail.com',
        'username': 'mrcoach',
        'full_name': 'Cleudson Cavalcante',
      };
      final mrcoachRoles = AuthService.availableRoles(mrcoachProfile);
      expect(mrcoachRoles, contains('trainer'));
      expect(mrcoachRoles, contains('admin'));

      final antigoProfile = {
        'id': '50c26610-8054-4b05-9274-7f414f91f52f',
        'email': 'cleudsonx@gmail.com',
        'username': 'cleudson-antigo',
        'full_name': 'Cleudson Cavalcante',
      };
      final antigoRoles = AuthService.availableRoles(antigoProfile);
      expect(antigoRoles, contains('trainer'));
      expect(antigoRoles, contains('admin'));
    });

    test('getActiveRole defaults to trainer for Cleudson accounts', () async {
      final hotmailProfile = {
        'id': '92dfd58c-845f-473e-b846-a2b8fdd3e508',
        'email': 'cleudsonx@hotmail.com',
      };
      final activeRole = await AuthService.getActiveRole(hotmailProfile);
      expect(activeRole, equals('trainer'));
    });

    testWidgets('LoginScreen auto-selects trainer role for Cleudson email',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(
            initialRole: 'client',
            initialEmail: 'cleudsonx@hotmail.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Email field is filled
      expect(find.text('cleudsonx@hotmail.com'), findsOneWidget);
      // Because it is Cleudson, the tab selected should be Treinador Pro
      expect(find.text('Treinador Pro'), findsOneWidget);
    });

    testWidgets(
        'RegisterScreen does not block Cleudson email with student invite requirement',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(
            initialRole: 'client',
            initialEmail: 'cleudsonx@hotmail.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Does NOT show "Cadastro exclusivo via convite"
      expect(find.text('Cadastro exclusivo via convite'), findsNothing);
      expect(find.text('Criar sua conta'), findsOneWidget);
    });
  });
}
