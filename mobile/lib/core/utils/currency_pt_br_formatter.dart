import 'package:flutter/services.dart';

/// Utilitário central de formatação e parsing para moeda Real Brasileiro (BRL / R$).
///
/// Padrão oficial brasileiro:
/// - Cifrão do Real: 'R$ '
/// - Separador de milhar: ponto ('.')
/// - Separador decimal: vírgula (',')
///
/// Exemplos:
/// - 150.0 -> "R$ 150,00"
/// - 1500.5 -> "R$ 1.500,50"
/// - 1250000.75 -> "R$ 1.250.000,75"
class CurrencyPtBrFormatter {
  CurrencyPtBrFormatter._();

  /// Símbolo oficial da moeda brasileira.
  static const String symbol = 'R\$ ';

  /// Converte um [double] para string formatada em Real brasileiro.
  ///
  /// [includeSymbol] define se inclui o prefixo "R$ " (padrão true).
  /// [decimalDigits] define a quantidade de casas decimais (padrão 2).
  static String format(
    double value, {
    bool includeSymbol = true,
    int decimalDigits = 2,
  }) {
    final isNegative = value < 0;
    final absVal = value.abs();

    final factor = _pow10(decimalDigits);
    final totalUnits = (absVal * factor).round();

    final intPart = totalUnits ~/ factor;
    final decPart = totalUnits % factor;

    final formattedInt = _formatThousands(intPart);
    final formattedDec = decimalDigits > 0
        ? ',${decPart.toString().padLeft(decimalDigits, '0')}'
        : '';
    final sign = isNegative ? '-' : '';
    final prefix = includeSymbol ? symbol : '';

    return '$sign$prefix$formattedInt$formattedDec';
  }

  /// Converte um valor em centavos inteiros (ex: 15000 -> "R$ 150,00").
  static String formatFromCents(int cents, {bool includeSymbol = true}) {
    return format(cents / 100.0, includeSymbol: includeSymbol);
  }

  /// Faz o parse resiliente de uma string monetária para [double].
  /// Suporta:
  /// - "R$ 1.500,50" -> 1500.50
  /// - "1.500,50" -> 1500.50
  /// - "150,00" -> 150.00
  /// - "150.00" -> 150.00 (fallback seguro para formato numérico do banco)
  /// - "1.250.000,75" -> 1250000.75
  static double parse(String? text, {double defaultValue = 0.0}) {
    if (text == null) return defaultValue;
    var cleaned = text.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return defaultValue;

    final isNegative = cleaned.startsWith('-');
    if (isNegative) {
      cleaned = cleaned.substring(1).trim();
    }

    if (cleaned.contains('.') && cleaned.contains(',')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Já está no formato com ponto decimal
      } else {
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) return defaultValue;
    return isNegative ? -parsed : parsed;
  }

  /// Faz o parse para centavos inteiros (int).
  /// Ex: "R$ 150,00" -> 15000.
  static int parseToCents(String? text, {int defaultValue = 0}) {
    final val = parse(text, defaultValue: defaultValue / 100.0);
    return (val * 100).round();
  }

  static int _pow10(int exp) {
    int res = 1;
    for (int i = 0; i < exp; i++) {
      res *= 10;
    }
    return res;
  }

  static String _formatThousands(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    final length = str.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

/// [TextInputFormatter] que formata valores monetários em tempo real no padrão Real brasileiro.
///
/// À medida que o usuário digita no teclado numérico, os centavos são empurrados da direita para a esquerda:
/// - Digita 1 -> 0,01
/// - Digita 5 -> 0,15
/// - Digita 0 -> 1,50
/// - Digita 0 -> 15,00
/// - Digita 0 -> 150,00
/// - Digita 0 -> 1.500,00
///
/// Ao apagar com backspace, o valor retrocede fluidamente.
///
/// Por padrão, [includeSymbol] é `false` para ser usado em campos que já possuem
/// `prefixText: 'R$ '` no [InputDecoration], o que garante excelente estética e impede
/// que o usuário apague ou altere acidentalmente o símbolo da moeda.
class CurrencyPtBrInputFormatter extends TextInputFormatter {
  final int maxDigits;
  final bool includeSymbol;

  const CurrencyPtBrInputFormatter({
    this.maxDigits = 11, // Até R$ 999.999.999,99
    this.includeSymbol = false,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    if (digitsOnly.length > maxDigits) {
      digitsOnly = digitsOnly.substring(0, maxDigits);
    }

    final cents = int.tryParse(digitsOnly) ?? 0;
    final formatted = CurrencyPtBrFormatter.formatFromCents(
      cents,
      includeSymbol: includeSymbol,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
