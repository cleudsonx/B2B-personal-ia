class DocumentValidationResult {
  final bool isValid;
  final String? formatted;
  final String? errorMessage;
  final String? verificationUrl;

  const DocumentValidationResult({
    required this.isValid,
    this.formatted,
    this.errorMessage,
    this.verificationUrl,
  });
}

class DocumentValidator {
  static const Set<String> _validUfs = {
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
  };

  /// Validação oficial do CPF com verificação matemática dos dois dígitos (Módulo 11 da Receita Federal)
  static DocumentValidationResult validateCpf(String? input) {
    if (input == null || input.trim().isEmpty) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'Informe o número do CPF.',
      );
    }

    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 11) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'O CPF deve conter exatamente 11 dígitos.',
      );
    }

    // Rejeita sequências de dígitos repetidos conhecidas
    final allSame = RegExp(r'^(\d)\1{10}$');
    if (allSame.hasMatch(digits)) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'CPF inválido (sequência não permitida pela Receita Federal).',
      );
    }

    // 1º Dígito Verificador
    int sum1 = 0;
    for (int i = 0; i < 9; i++) {
      sum1 += int.parse(digits[i]) * (10 - i);
    }
    int rest1 = (sum1 * 10) % 11;
    if (rest1 == 10) rest1 = 0;
    if (rest1 != int.parse(digits[9])) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'CPF inválido (primeiro dígito verificador incorreto).',
      );
    }

    // 2º Dígito Verificador
    int sum2 = 0;
    for (int i = 0; i < 10; i++) {
      sum2 += int.parse(digits[i]) * (11 - i);
    }
    int rest2 = (sum2 * 10) % 11;
    if (rest2 == 10) rest2 = 0;
    if (rest2 != int.parse(digits[10])) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'CPF inválido (segundo dígito verificador incorreto).',
      );
    }

    final formatted =
        '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9, 11)}';

    return DocumentValidationResult(
      isValid: true,
      formatted: formatted,
      verificationUrl:
          'https://servicos.receita.fazenda.gov.br/servicos/cpf/consultasituacao/consultapublica.asp',
    );
  }

  /// Validação do CREF (Conselho Regional de Educação Física / CONFEF)
  /// Padrão: [CREF ]019284-G/SP ou 019284-P/RJ
  static DocumentValidationResult validateCref(String? input) {
    if (input == null || input.trim().isEmpty) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'Informe o número do registro CREF.',
      );
    }

    final clean = input.trim().toUpperCase();

    // Regex abrangente para variações: "CREF 019284-G/SP", "019284-G/SP", "19284G/SP", "019284-P-SP"
    final regex = RegExp(
      r'^(?:CREF\s*)?(\d{3,6})\s*[-/.]?\s*([GPTEgpte])\s*[-/.]?\s*([A-Za-z]{2})$',
    );

    final match = regex.firstMatch(clean);
    if (match == null) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'Formato de CREF inválido. Exemplo: 019284-G/SP',
      );
    }

    final number = match.group(1)!;
    final category = match.group(2)!.toUpperCase(); // G = Graduado, P = Provisionado, T = Treinador
    final uf = match.group(3)!.toUpperCase();

    if (!_validUfs.contains(uf)) {
      return DocumentValidationResult(
        isValid: false,
        errorMessage: 'UF "$uf" não corresponde a um estado brasileiro válido.',
      );
    }

    // Normaliza número com zero à esquerda até 6 dígitos se necessário
    final paddedNumber = number.padLeft(6, '0');
    final formatted = 'CREF $paddedNumber-$category/$uf';

    return DocumentValidationResult(
      isValid: true,
      formatted: formatted,
      verificationUrl: 'https://www.confef.org.br/confef/registrados/',
    );
  }

  /// Validação do CBMF (Confederação Brasileira de Musculação e Fitness)
  /// Portal do Filiado: https://portaldofiliadocbmf.abacusai.app/
  static DocumentValidationResult validateCbmf(String? input) {
    if (input == null || input.trim().isEmpty) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'Informe o número de registro de filiado CBMF.',
      );
    }

    final clean = input.trim().toUpperCase();

    // Aceita variações: "CBMF-10294", "CBMF 10294", "10294", "CBMF-BR-1234"
    final regex = RegExp(r'^(?:CBMF\s*[-/:]?\s*)?([A-Za-z0-9\-]{3,12})$');
    final match = regex.firstMatch(clean);

    if (match == null) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'Formato CBMF inválido. Exemplo: CBMF-10294',
      );
    }

    final rawCode = match.group(1)!.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (rawCode.length < 3) {
      return const DocumentValidationResult(
        isValid: false,
        errorMessage: 'O registro CBMF deve conter pelo menos 3 caracteres alfanuméricos.',
      );
    }

    final formatted = 'CBMF-$rawCode';

    return DocumentValidationResult(
      isValid: true,
      formatted: formatted,
      verificationUrl: 'https://portaldofiliadocbmf.abacusai.app/',
    );
  }

  /// Validador unificado baseado no tipo selecionado ('CREF', 'CBMF', 'CPF')
  static DocumentValidationResult validate({
    required String type,
    required String? value,
  }) {
    switch (type.toUpperCase()) {
      case 'CREF':
        return validateCref(value);
      case 'CBMF':
        return validateCbmf(value);
      case 'CPF':
        return validateCpf(value);
      default:
        return const DocumentValidationResult(
          isValid: false,
          errorMessage: 'Tipo de documento não suportado.',
        );
    }
  }
}
