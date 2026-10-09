import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/client/student_profile_screen.dart';
import 'package:personal_ia/services/student_profile_service.dart';

class FakeGateway implements StudentProfileGateway {
  Map<String, dynamic>? row;
  Object? fetchError;
  Object? updateError;
  bool alertResult = true;
  Map<String, dynamic>? lastUpdate;
  int alertCalls = 0;

  FakeGateway({this.row});

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (fetchError != null) throw fetchError!;
    return row;
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> values) async {
    if (updateError != null) throw updateError!;
    lastUpdate = values;
  }

  @override
  Future<bool> sendReviewAlert({
    required String studentId,
    required String studentName,
    required String trainerId,
    required String restrictions,
  }) async {
    alertCalls++;
    return alertResult;
  }
}

Map<String, dynamic> _row({String? trainer = 'trainer-1'}) => {
      'full_name': 'Maria Real',
      'age': 31,
      'weight_kg': 62.5,
      'height_cm': 165,
      'clinical_restrictions': 'Dor Lombar',
      'trainer_id': trainer,
      'timezone': 'America/Sao_Paulo',
    };

Future<void> _pump(WidgetTester t, FakeGateway g) async {
  await t.pumpWidget(MaterialApp(
    home: StudentProfileScreen(
      service: StudentProfileService(gateway: g),
      userId: 'u1',
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  group('StudentProfileValidator', () {
    test('aceita valores válidos e campos opcionais vazios', () {
      expect(
          StudentProfileValidator.validate(
              name: 'Ana Souza', age: '', weight: '', height: ''),
          isEmpty);
      expect(
          StudentProfileValidator.validate(
              name: 'Ana', age: '30', weight: '70,5', height: '170'),
          isEmpty);
    });

    test('rejeita nome vazio e limites inválidos com o campo indicado', () {
      final e = StudentProfileValidator.validate(
          name: ' ', age: '5', weight: '10', height: '300');
      expect(e.keys, containsAll(['name', 'age', 'weight', 'height']));
    });

    test('rejeita formato não numérico', () {
      final e = StudentProfileValidator.validate(
          name: 'Ana', age: 'abc', weight: 'x', height: '1,7');
      expect(e.keys, containsAll(['age', 'weight', 'height']));
    });
  });

  group('StudentProfileService', () {
    test('load mapeia dados persistidos', () async {
      final s = StudentProfileService(gateway: FakeGateway(row: _row()));
      final d = await s.load('u1');
      expect(d!.name, 'Maria Real');
      expect(d.age, 31);
      expect(d.weightKg, 62.5);
      expect(d.restrictions, {'Dor Lombar'});
      expect(d.timezone, 'America/Sao_Paulo');
    });

    test('restrição vazia vira "Nenhuma"', () {
      final d = StudentProfileData.fromRow({'full_name': 'A'});
      expect(d.restrictions, {kNoRestriction});
      expect(d.timezone, 'UTC');
    });

    test('save persiste todos os campos e dispara revisão se restrição mudou',
        () async {
      final g = FakeGateway(row: _row());
      final s = StudentProfileService(gateway: g);
      final orig = (await s.load('u1'))!;
      final upd = StudentProfileData(
          name: 'Maria Real',
          age: 32,
          weightKg: 63,
          heightCm: 166,
          restrictions: {'Hérnia de Disco'},
          trainerId: orig.trainerId,
          timezone: 'America/Sao_Paulo');
      final r = await s.save(userId: 'u1', original: orig, updated: upd);
      expect(r.review, ReviewStatus.requested);
      expect(g.lastUpdate, {
        'full_name': 'Maria Real',
        'age': 32,
        'weight_kg': 63.0,
        'height_cm': 166,
        'clinical_restrictions': 'Hérnia de Disco',
        'timezone': 'America/Sao_Paulo',
      });
      expect(g.alertCalls, 1);
    });

    test('sem mudança de restrição não aciona revisão', () async {
      final g = FakeGateway(row: _row());
      final s = StudentProfileService(gateway: g);
      final orig = (await s.load('u1'))!;
      final r = await s.save(userId: 'u1', original: orig, updated: orig);
      expect(r.review, ReviewStatus.notNeeded);
      expect(g.alertCalls, 0);
    });

    test('falha no alerta resulta em failed (nunca em sucesso)', () async {
      final g = FakeGateway(row: _row())..alertResult = false;
      final s = StudentProfileService(gateway: g);
      final orig = (await s.load('u1'))!;
      final upd = StudentProfileData(
          name: orig.name,
          restrictions: {'Gestante'},
          trainerId: orig.trainerId);
      final r = await s.save(userId: 'u1', original: orig, updated: upd);
      expect(r.review, ReviewStatus.failed);
    });

    test('sem professor vinculado retorna noTrainer', () async {
      final g = FakeGateway(row: _row(trainer: null));
      final s = StudentProfileService(gateway: g);
      final orig = (await s.load('u1'))!;
      final upd = StudentProfileData(
          name: orig.name, restrictions: {'Gestante'}, trainerId: null);
      final r = await s.save(userId: 'u1', original: orig, updated: upd);
      expect(r.review, ReviewStatus.noTrainer);
      expect(g.alertCalls, 0);
    });

    test('falha de persistência propaga e não aciona revisão', () async {
      final g = FakeGateway(row: _row())..updateError = Exception('rls');
      final s = StudentProfileService(gateway: g);
      final orig = (await s.load('u1'))!;
      final upd = StudentProfileData(
          name: orig.name,
          restrictions: {'Gestante'},
          trainerId: orig.trainerId);
      expect(() => s.save(userId: 'u1', original: orig, updated: upd),
          throwsException);
      expect(g.alertCalls, 0);
    });
  });

  group('StudentProfileScreen', () {
    testWidgets('mostra dados salvos, sem dados de exemplo', (t) async {
      await _pump(t, FakeGateway(row: _row()));
      expect(find.widgetWithText(TextFormField, 'Maria Real'), findsOneWidget);
      expect(find.text('Aluno Silva'), findsNothing);
      expect(find.text('76.5'), findsNothing);
      expect(find.text('31'), findsOneWidget);
    });

    testWidgets('erro de carregamento mostra retry, sem formulário', (t) async {
      final g = FakeGateway()..fetchError = Exception('net');
      await _pump(t, g);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.byKey(const Key('btn_save_profile')), findsNothing);
    });

    testWidgets('valor inválido exibe erro no campo e não salva', (t) async {
      final g = FakeGateway(row: _row());
      await _pump(t, g);
      await t.enterText(find.byKey(const Key('field_age')), '5');
      await t.ensureVisible(find.byKey(const Key('btn_save_profile')));
      await t.tap(find.byKey(const Key('btn_save_profile')));
      await t.pump();
      expect(find.text('Idade entre 10 e 100.'), findsOneWidget);
      expect(g.lastUpdate, isNull);
    });
  });
}

