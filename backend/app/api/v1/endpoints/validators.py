import re
from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()

VALID_UFS = {
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
    'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
    'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
}

class DocumentVerifyRequest(BaseModel):
    document_type: str = Field(..., description="'CREF', 'CBMF' ou 'CPF'")
    document_value: str = Field(..., description="Valor informado pelo professor")

class DocumentVerifyResponse(BaseModel):
    is_valid: bool
    document_type: str
    formatted: Optional[str] = None
    error_message: Optional[str] = None
    verification_url: Optional[str] = None

def validate_cpf(raw_value: str) -> DocumentVerifyResponse:
    digits = re.sub(r'\D', '', raw_value or '')
    if len(digits) != 11:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CPF',
            error_message="O CPF deve conter exatamente 11 dígitos numéricos."
        )

    # Rejeita dígitos repetidos
    if len(set(digits)) == 1:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CPF',
            error_message="CPF inválido (sequência não permitida pela Receita Federal)."
        )

    # 1º dígito verificador
    sum1 = sum(int(digits[i]) * (10 - i) for i in range(9))
    rest1 = (sum1 * 10) % 11
    if rest1 == 10:
        rest1 = 0
    if rest1 != int(digits[9]):
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CPF',
            error_message="CPF inválido (primeiro dígito verificador incorreto)."
        )

    # 2º dígito verificador
    sum2 = sum(int(digits[i]) * (11 - i) for i in range(10))
    rest2 = (sum2 * 10) % 11
    if rest2 == 10:
        rest2 = 0
    if rest2 != int(digits[10]):
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CPF',
            error_message="CPF inválido (segundo dígito verificador incorreto)."
        )

    formatted = f"{digits[:3]}.{digits[3:6]}.{digits[6:9]}-{digits[9:]}"
    return DocumentVerifyResponse(
        is_valid=True,
        document_type='CPF',
        formatted=formatted,
        verification_url="https://servicos.receita.fazenda.gov.br/servicos/cpf/consultasituacao/consultapublica.asp"
    )

def validate_cref(raw_value: str) -> DocumentVerifyResponse:
    clean = (raw_value or '').strip().upper()
    pattern = r'^(?:CREF\s*)?(\d{3,6})\s*[-/.]?\s*([GPTEgpte])\s*[-/.]?\s*([A-Za-z]{2})$'
    match = re.match(pattern, clean)
    if not match:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CREF',
            error_message="Formato de CREF inválido. Exemplo: 019284-G/SP"
        )

    number, category, uf = match.groups()
    category = category.upper()
    uf = uf.upper()

    if uf not in VALID_UFS:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CREF',
            error_message=f'UF "{uf}" não corresponde a um estado brasileiro válido.'
        )

    padded = number.zfill(6)
    formatted = f"CREF {padded}-{category}/{uf}"
    return DocumentVerifyResponse(
        is_valid=True,
        document_type='CREF',
        formatted=formatted,
        verification_url="https://www.confef.org.br/confef/registrados/"
    )

def validate_cbmf(raw_value: str) -> DocumentVerifyResponse:
    clean = (raw_value or '').strip().upper()
    pattern = r'^(?:CBMF\s*[-/:]?\s*)?([A-Za-z0-9\-]{3,12})$'
    match = re.match(pattern, clean)
    if not match:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CBMF',
            error_message="Formato CBMF inválido. Exemplo: CBMF-10294"
        )

    raw_code = re.sub(r'[^A-Za-z0-9]', '', match.group(1))
    if len(raw_code) < 3:
        return DocumentVerifyResponse(
            is_valid=False,
            document_type='CBMF',
            error_message="O registro CBMF deve conter pelo menos 3 caracteres alfanuméricos."
        )

    formatted = f"CBMF-{raw_code}"
    return DocumentVerifyResponse(
        is_valid=True,
        document_type='CBMF',
        formatted=formatted,
        verification_url="https://portaldofiliadocbmf.abacusai.app/"
    )

@router.post("/verify-document", response_model=DocumentVerifyResponse)
async def verify_professional_document(req: DocumentVerifyRequest):
    """
    Valida CREF, CBMF ou CPF de treinadores segundo os padrões oficiais:
    - CREF: CONFEF (registro regional e UF)
    - CBMF: Portal do Filiado CBMF
    - CPF: Algoritmo Módulo 11 da Receita Federal
    """
    doc_type = req.document_type.upper().strip()
    if doc_type == 'CPF':
        return validate_cpf(req.document_value)
    elif doc_type == 'CREF':
        return validate_cref(req.document_value)
    elif doc_type == 'CBMF':
        return validate_cbmf(req.document_value)
    else:
        raise HTTPException(
            status_code=400,
            detail=f"Tipo de documento '{req.document_type}' inválido. Utilize 'CREF', 'CBMF' ou 'CPF'."
        )
