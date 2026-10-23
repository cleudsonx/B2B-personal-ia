import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/utils/currency_pt_br_formatter.dart';

void main() {
  group('CurrencyPtBrFormatter unit tests', () {
    test('formata valores com e sem símbolo do Real BRL', () {
      expect(CurrencyPtBrFormatter.format(0.0), 'R\$ 0,00');
      expect(CurrencyPtBrFormatter.format(0.0, includeSymbol: false), '0,00');
      expect(CurrencyPtBrFormatter.format(150.0), 'R\$ 150,00');
      expect(CurrencyPtBrFormatter.format(150.0, includeSymbol: false), '150,00');
      expect(CurrencyPtBrFormatter.format(1500.5), 'R\$ 1.500,50');
      expect(CurrencyPtBrFormatter.format(1500.5, includeSymbol: false), '1.500,50');
      expect(CurrencyPtBrFormatter.format(1250000.75), 'R\$ 1.250.000,75');
      expect(CurrencyPtBrFormatter.format(-89.90), '-R\$ 89,90');
    });

    test('formatFromCents converte centavos inteiros', () {
      expect(CurrencyPtBrFormatter.formatFromCents(0), 'R\$ 0,00');
      expect(CurrencyPtBrFormatter.formatFromCents(1), 'R\$ 0,01');
      expect(CurrencyPtBrFormatter.formatFromCents(150), 'R\$ 1,50');
      expect(CurrencyPtBrFormatter.formatFromCents(15000), 'R\$ 150,00');
      expect(CurrencyPtBrFormatter.formatFromCents(150000), 'R\$ 1.500,00');
      expect(CurrencyPtBrFormatter.formatFromCents(125000075), 'R\$ 1.250.000,75');
    });

    test('parse converte strings variadas para double com segurança', () {
      expect(CurrencyPtBrFormatter.parse('R\$ 1.500,00'), 1500.0);
      expect(CurrencyPtBrFormatter.parse('1.500,00'), 1500.0);
      expect(CurrencyPtBrFormatter.parse('150,00'), 150.0);
      expect(CurrencyPtBrFormatter.parse('150.00'), 150.0);
      expect(CurrencyPtBrFormatter.parse('1.250.000,75'), 1250000.75);
      expect(CurrencyPtBrFormatter.parse(''), 0.0);
      expect(CurrencyPtBrFormatter.parse(null), 0.0);
      expect(CurrencyPtBrFormatter.parse('inválido', defaultValue: 10.0), 10.0);
    });

    test('parseToCents converte para centavos inteiros', () {
      expect(CurrencyPtBrFormatter.parseToCents('R\$ 150,00'), 15000);
      expect(CurrencyPtBrFormatter.parseToCents('1.500,00'), 150000);
      expect(CurrencyPtBrFormatter.parseToCents('0,01'), 1);
    });
  });

  group('CurrencyPtBrInputFormatter tests', () {
    test('formata digitação progressiva em centavos da direita para esquerda', () {
      const formatter = CurrencyPtBrInputFormatter(includeSymbol: false);

      TextEditingValue val = const TextEditingValue(text: '');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1'));
      expect(val.text, '0,01');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '0,015'));
      expect(val.text, '0,15');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '0,150'));
      expect(val.text, '1,50');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1,500'));
      expect(val.text, '15,00');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '15,000'));
      expect(val.text, '150,00');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '150,000'));
      expect(val.text, '1.500,00');
    });

    test('formata incluindo símbolo quando includeSymbol for true', () {
      const formatter = CurrencyPtBrInputFormatter(includeSymbol: true);
      final res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '150000'),
      );
      expect(res.text, 'R\$ 1.500,00');
    });
  });
}
