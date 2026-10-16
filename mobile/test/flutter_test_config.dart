import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:personal_ia/core/widgets/app_version_footer.dart';

/// Configuração global da suite de testes Flutter (mobile/test)
/// - Desativa busca de fontes em runtime pelo GoogleFonts (elimina erros HTTP de fonte em ambiente CI)
/// - Desativa abertura automática de modal via timer no AppVersionFooter
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  AppVersionFooter.enableAutoModal = false;
  await testMain();
}
