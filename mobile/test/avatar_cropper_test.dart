import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/avatar_cropper_dialog.dart';

// PNG mínimo válido de 1x1 pixel transparente
final Uint8List _samplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('AvatarCropperDialog renders UI controls, zoom slider and rotation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarCropperDialog(
          imageBytes: _samplePngBytes,
          cropSize: 200,
        ),
      ),
    );

    // Valida elementos principais da tela
    expect(find.text('Ajustar Foto do Perfil'), findsOneWidget);
    expect(find.textContaining('Arraste e use o zoom'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Concluir Enquadramento'), findsOneWidget);
    expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Testa rotação 90 graus
    await tester.tap(find.byIcon(Icons.rotate_right_rounded));
    await tester.pumpAndSettle();

    // Testa reset de transformação
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    // Testa alteração de zoom via slider
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(50, 0));
    await tester.pumpAndSettle();
  });
}
