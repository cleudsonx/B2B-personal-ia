import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/b2b_landing_screen.dart';
import 'package:personal_ia/features/landing/public_trainer_directory_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  group('B2BLandingScreen - Páginas Públicas Institucionais', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1280, 10000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const B2BLandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHAIPADOS LABS'), findsOneWidget);
      expect(find.text('Termos de Uso'), findsOneWidget);
      expect(find.text('Privacidade'), findsOneWidget);

      // Abre modal de Termos de Uso
      await tester.tap(find.text('Termos de Uso'));
      await tester.pumpAndSettle();

      expect(find.text('Termos de Uso • Mr. Coach'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1280, 10000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const B2BLandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHAIPADOS LABS'), findsOneWidget);
      expect(find.text('Termos de Uso'), findsOneWidget);
      expect(find.text('Privacidade'), findsOneWidget);

      // Abre modal de Privacidade
      await tester.tap(find.text('Privacidade'));
      await tester.pumpAndSettle();

      expect(find.text('Política de Privacidade & LGPD'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
    });
  });

  group('PublicTrainerDirectoryScreen - Diretório Nacional de Treinadores', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const PublicTrainerDirectoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Encontre seu Personal Trainer Especialista'), findsOneWidget);
      expect(find.text('DIRETÓRIO OFICIAL • CREF REGISTRADO'), findsOneWidget);
      expect(find.text('🛡️ Só CREF Verificado'), findsOneWidget);
      expect(find.text('Ver Vitrine'), findsWidgets);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const PublicTrainerDirectoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Encontre seu Personal Trainer Especialista'), findsOneWidget);
      expect(find.text('DIRETÓRIO OFICIAL • CREF REGISTRADO'), findsOneWidget);
      expect(find.text('🛡️ Só CREF Verificado'), findsOneWidget);
      expect(find.text('Ver Vitrine'), findsWidgets);
    });
  });
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final List<int> _transparentImage = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
