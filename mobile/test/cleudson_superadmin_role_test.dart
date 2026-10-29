import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/auth_service.dart';
import 'package:personal_ia/features/auth/login_screen.dart';
import 'package:personal_ia/features/auth/register_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canonical Owner & Privilege Escalation Hardening Tests', () {
    test('availableRoles recognizes ONLY canonical owner UUIDs/exact emails as admin', () {
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

    test('blocks WhatsApp synthetic accounts and substring spoofing from getting admin role', () {
      // Caso real reportado: novo usuário criado via WhatsApp com nome "Cleudson Hotmail"
      // e e-mail sintético wa_5561982912174@mrcoach.app (mesmo se poluído com is_admin: true)
      final whatsappNewUser = {
        'id': 'a1b2c3d4-1111-4222-8333-444455556666',
        'email': 'wa_5561982912174@mrcoach.app',
        'full_name': 'Cleudson Hotmail',
        'role': 'trainer',
        'roles': ['trainer', 'admin'],
        'is_admin': true,
      };
      final waRoles = AuthService.availableRoles(whatsappNewUser);
      expect(waRoles, contains('trainer'));
      expect(waRoles, isNot(contains('admin')));

      // Novo domínio sintético isolado (@wa.mrcoach.internal)
      final internalWaUser = {
        'id': 'b1b2c3d4-1111-4222-8333-444455556666',
        'email': 'wa_5511999998888@wa.mrcoach.internal',
        'full_name': 'Cleudson Teste',
        'role': 'trainer',
      };
      expect(AuthService.availableRoles(internalWaUser), isNot(contains('admin')));

      // Spoofing por substring em nome, e-mail ou username
      final spoofedUser = {
        'id': 'c1b2c3d4-1111-4222-8333-444455556666',
        'email': 'cleudson.outro@gmail.com',
        'username': 'mrcoach',
        'full_name': 'Cleudson Cavalcante',
        'role': 'trainer',
      };
      expect(AuthService.availableRoles(spoofedUser), isNot(contains('admin')));
      expect(AuthService.isCanonicalOwnerEmail('wa_5561982912174@mrcoach.app'), isFalse);
      expect(AuthService.isCanonicalOwnerEmail('cleudson.outro@gmail.com'), isFalse);
      expect(AuthService.isCanonicalOwnerEmail('cleudsonx@hotmail.com'), isTrue);
    });

    test('getActiveRole defaults to trainer for canonical owner accounts', () async {
      final hotmailProfile = {
        'id': '92dfd58c-845f-473e-b846-a2b8fdd3e508',
        'email': 'cleudsonx@hotmail.com',
      };
      final activeRole = await AuthService.getActiveRole(hotmailProfile);
      expect(activeRole, equals('trainer'));
    });

    testWidgets('LoginScreen auto-selects trainer role ONLY for exact canonical owner email',
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

      expect(find.text('cleudsonx@hotmail.com'), findsOneWidget);
      expect(find.text('Treinador Pro'), findsOneWidget);
    });

    testWidgets(
        'RegisterScreen blocks uninvited student with spoofed substring email, but allows exact owner email',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Spoofed email must NOT bypass student invite requirement
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(
            initialRole: 'client',
            initialEmail: 'cleudson.spoof@mrcoach.app',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cadastro exclusivo via convite'), findsOneWidget);

      // Exact canonical owner email continues working
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(
            initialRole: 'client',
            initialEmail: 'cleudsonx@hotmail.com',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cadastro exclusivo via convite'), findsNothing);
      expect(find.text('Criar sua conta'), findsOneWidget);
    });
  });
}
