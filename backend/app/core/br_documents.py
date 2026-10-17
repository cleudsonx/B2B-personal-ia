# app/core/br_documents.py
# Validação de documentos brasileiros (CPF/CNPJ) e utilitários de contato
# usados no checkout (Asaas exige cpfCnpj válido para emitir Pix e cobrar cartão).

import re
from typing import Optional


def only_digits(value: Optional[str]) -> str:
    return re.sub(r"\D", "", value or "")


def is_valid_cpf(cpf: str) -> bool:
    cpf = only_digits(cpf)
    if len(cpf) != 11 or cpf == cpf[0] * 11:
        return False
    for size in (9, 10):
        total = sum(int(cpf[i]) * (size + 1 - i) for i in range(size))
        digit = (total * 10) % 11 % 10
        if digit != int(cpf[size]):
            return False
    return True


def is_valid_cnpj(cnpj: str) -> bool:
    cnpj = only_digits(cnpj)
    if len(cnpj) != 14 or cnpj == cnpj[0] * 14:
        return False
    weights_1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    weights_2 = [6] + weights_1
    for weights, pos in ((weights_1, 12), (weights_2, 13)):
        total = sum(int(cnpj[i]) * weights[i] for i in range(len(weights)))
        rest = total % 11
        digit = 0 if rest < 2 else 11 - rest
        if digit != int(cnpj[pos]):
            return False
    return True


def normalize_cpf_cnpj(value: Optional[str]) -> Optional[str]:
    """Retorna somente dígitos se o CPF/CNPJ for válido; caso contrário None."""
    digits = only_digits(value)
    if len(digits) == 11 and is_valid_cpf(digits):
        return digits
    if len(digits) == 14 and is_valid_cnpj(digits):
        return digits
    return None


def normalize_br_phone(value: Optional[str]) -> Optional[str]:
    """Normaliza celular/telefone BR para DDD + número (10 ou 11 dígitos)."""
    digits = only_digits(value)
    if digits.startswith("55") and len(digits) in (12, 13):
        digits = digits[2:]
    return digits if len(digits) in (10, 11) else None


def normalize_cep(value: Optional[str]) -> Optional[str]:
    digits = only_digits(value)
    return digits if len(digits) == 8 else None


def resolve_asaas_base_url(api_key: str, configured_url: Optional[str]) -> str:
    """
    Garante que a chave e o ambiente do Asaas sejam coerentes:
    - Chave de produção ($aact_prod_...) => https://api.asaas.com/v3
    - Chave de sandbox  ($aact_hmlg_...) => https://sandbox.asaas.com/api/v3
    Evita o erro comum de usar a chave da conta real apontando para o sandbox (ou vice-versa).
    """
    key = (api_key or "").strip()
    if key.startswith("$aact_prod_"):
        return "https://api.asaas.com/v3"
    if key.startswith("$aact_hmlg_"):
        return "https://sandbox.asaas.com/api/v3"
    return (configured_url or "https://sandbox.asaas.com/api/v3").rstrip("/")

