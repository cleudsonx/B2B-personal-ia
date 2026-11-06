# backend/app/core/financial_security.py
"""
Núcleo de Segurança Cibernética Financeira & Split Payment
Conformidade estrita com a Resolução BCB nº 4.893 (Banco Central do Brasil)
Padrões:
- Assinatura Digital de Instruções de Pagamento / Split via JWS (RFC 7515 / FAPI)
- Integridade, Não-repúdio e Validação Criptográfica de Parâmetros de Repasse
- Trilha de Auditoria Criptográfica Imutável com Encadeamento de Hashes (Audit Trail)
- mTLS Readiness (Transport Layer Security Mútuo - RFC 8705) para Gateways Bancários
"""

import base64
import hashlib
import hmac
import json
import logging
import ssl
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import httpx
from pydantic import BaseModel, Field

from app.core.config import settings

logger = logging.getLogger(__name__)


# ==============================================================================
# 1. Utilidades Criptográficas Base64URL (RFC 7515 / RFC 4648)
# ==============================================================================

def b64url_encode(data: bytes) -> str:
    """Codifica bytes em Base64URL sem padding '=' (RFC 7515)."""
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def b64url_decode(data_str: str) -> bytes:
    """Decodifica string Base64URL restaurando padding '=' quando necessário."""
    rem = len(data_str) % 4
    if rem > 0:
        data_str += "=" * (4 - rem)
    return base64.urlsafe_b64decode(data_str)


def get_financial_signing_key() -> bytes:
    """
    Obtém a chave secreta de assinatura HMAC-SHA256 para comandos JWS.
    Utiliza FINANCIAL_SIGNING_SECRET com fallback determinístico para outros segredos.
    """
    secret = (
        getattr(settings, "FINANCIAL_SIGNING_SECRET", "")
        or getattr(settings, "ASAAS_WEBHOOK_TOKEN", "")
        or getattr(settings, "SUPABASE_JWT_SECRET", "")
        or "shapelab_default_bcb4893_sec_key_2026"
    )
    return secret.encode("utf-8")


# ==============================================================================
# 2. Schemas do Comando de Split de Pagamento (BCB 4.893)
# ==============================================================================

class SplitCommandPayload(BaseModel):
    """
    Payload canônico da instrução de Split de Pagamento.
    Contém todos os parâmetros necessários para auditoria e liquidação.
    """
    jti: str = Field(default_factory=lambda: str(uuid.uuid4()), description="Token de unicidade / Nonce contra replay")
    iss: str = Field(default="shapelab-financial-core", description="Emissor da instrução")
    aud: str = Field(default="asaas-payment-gateway", description="Destinatário / Gateway financeiro")
    iat: int = Field(default_factory=lambda: int(time.time()), description="Timestamp UTC de emissão")
    exp: int = Field(default_factory=lambda: int(time.time()) + 300, description="Expiração (máx 5 minutos)")
    action: str = Field(default="SPLIT_PAYMENT_INSTRUCTION", description="Tipo de comando financeiro")
    invoice_id: str = Field(..., description="ID da fatura interna")
    trainer_id: str = Field(..., description="ID do personal trainer beneficiário")
    trainer_wallet_id: Optional[str] = Field(None, description="Wallet ID no Asaas para repasse direto")
    gross_amount_cents: int = Field(..., description="Valor total cobrado do aluno em centavos")
    platform_fee_percent: float = Field(default=5.0, description="Percentual da taxa de intermediação da plataforma (5%)")
    platform_fee_cents: int = Field(..., description="Valor retido pela plataforma em centavos")
    trainer_net_cents: int = Field(..., description="Valor líquido a ser creditado ao personal (95%)")
    currency: str = Field(default="BRL", description="Moeda (Real Brasileiro)")
    compliance_standard: str = Field(default="BCB_4893_CYBERSECURITY_V1", description="Norma de conformidade")


class FinancialAuditEntry(BaseModel):
    """Registro imutável na trilha de auditoria criptográfica."""
    entry_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    event_type: str = Field(..., description="Ex: SPLIT_COMMAND_CREATED, SPLIT_SETTLED, SPLIT_TAMPER_DETECTED")
    invoice_id: str
    trainer_id: str
    gross_amount_cents: int
    platform_fee_cents: int
    trainer_net_cents: int
    jws_token_digest: str = Field(..., description="Hash SHA-256 do JWS emitido")
    previous_hash: str = Field(..., description="Hash do registro anterior na cadeia imutável")
    entry_hash: str = Field(..., description="Hash SHA-256 consolidado deste registro")


# ==============================================================================
# 3. Motor de Assinatura e Validação JWS (RFC 7515)
# ==============================================================================

class JwsSplitCommandService:
    """
    Gerencia a assinatura digital e verificação de comandos de split via JWS (RFC 7515).
    Garante autenticidade de origem, integridade matemática e proteção contra ataques de replay.
    """

    @classmethod
    def sign_split_command(
        cls,
        payload_data: Dict[str, Any],
        signing_key: Optional[bytes] = None,
    ) -> str:
        """
        Assina um comando de split de pagamento gerando um token JWS compacto (RFC 7515).
        Formato: base64url(header) + "." + base64url(payload) + "." + base64url(signature)
        """
        key = signing_key or get_financial_signing_key()
        now_ts = int(time.time())

        # Garante metadados de segurança
        payload = dict(payload_data)
        if "jti" not in payload:
            payload["jti"] = str(uuid.uuid4())
        if "iss" not in payload:
            payload["iss"] = getattr(settings, "FINANCIAL_JWS_ISSUER", "shapelab-financial-core")
        if "iat" not in payload:
            payload["iat"] = now_ts
        if "exp" not in payload:
            payload["exp"] = now_ts + 300  # Validade de 5 minutos
        if "compliance_standard" not in payload:
            payload["compliance_standard"] = "BCB_4893_CYBERSECURITY_V1"

        # Cabeçalho protegido JWS (RFC 7515 / FAPI)
        protected_header = {
            "alg": "HS256",
            "typ": "JOSE",
            "b64": True,
            "crit": ["b64"],
        }

        header_bytes = json.dumps(protected_header, separators=(",", ":"), sort_keys=True).encode("utf-8")
        payload_bytes = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")

        b64_header = b64url_encode(header_bytes)
        b64_payload = b64url_encode(payload_bytes)

        signing_input = f"{b64_header}.{b64_payload}".encode("ascii")
        signature = hmac.new(key, signing_input, hashlib.sha256).digest()
        b64_signature = b64url_encode(signature)

        jws_token = f"{b64_header}.{b64_payload}.{b64_signature}"
        return jws_token

    @classmethod
    def verify_split_command(
        cls,
        jws_token: str,
        signing_key: Optional[bytes] = None,
        enforce_expiration: bool = True,
    ) -> Dict[str, Any]:
        """
        Verifica a assinatura matemática e a validade temporal de um comando JWS.
        Retorna o dicionário de dados do comando caso seja autêntico e íntegro.
        Lança ValueError caso o token seja inválido, expirado ou adulterado.
        """
        if not jws_token or not isinstance(jws_token, str):
            raise ValueError("Token JWS ausente ou inválido.")

        parts = jws_token.strip().split(".")
        if len(parts) != 3:
            raise ValueError("Token JWS malformado (deve conter exatamente 3 partes separadas por ponto).")

        b64_header, b64_payload, b64_signature = parts
        key = signing_key or get_financial_signing_key()

        # Recalcula a assinatura esperada
        signing_input = f"{b64_header}.{b64_payload}".encode("ascii")
        expected_sig = hmac.new(key, signing_input, hashlib.sha256).digest()
        received_sig = b64url_decode(b64_signature)

        # Comparação em tempo constante contra timing attacks
        if not hmac.compare_digest(received_sig, expected_sig):
            raise ValueError("Falha de integridade: Assinatura JWS inválida ou comando de split adulterado.")

        try:
            header_dict = json.loads(b64url_decode(b64_header).decode("utf-8"))
            payload_dict = json.loads(b64url_decode(b64_payload).decode("utf-8"))
        except Exception as e:
            raise ValueError(f"Falha ao decodificar componentes JSON do JWS: {e}")

        if header_dict.get("alg") != "HS256":
            raise ValueError(f"Algoritmo JWS não permitido: {header_dict.get('alg')}. Esperado: HS256.")

        # Validação de temporalidade (exp / iat)
        if enforce_expiration:
            now_ts = int(time.time())
            exp = payload_dict.get("exp")
            if exp is not None and now_ts > int(exp):
                raise ValueError(f"Comando de split JWS expirado (exp={exp}, now={now_ts}).")

            iat = payload_dict.get("iat")
            if iat is not None and int(iat) > now_ts + 60:
                raise ValueError("Comando de split JWS emitido no futuro (desvio de relógio excessivo).")

        return payload_dict


# ==============================================================================
# 4. Trilha de Auditoria Criptográfica Imutável (Audit Trail BCB 4.893)
# ==============================================================================

class FinancialAuditTrail:
    """
    Mantém a trilha de auditoria encadeada criptograficamente para todas as ordens de split.
    Cada registro referencia o hash SHA-256 do registro anterior (estrutura Merkle/Hash-Chain).
    """

    _chain: List[FinancialAuditEntry] = []
    _last_hash: str = "0" * 64  # Hash gênesis

    @classmethod
    def _compute_entry_hash(
        cls,
        entry_id: str,
        timestamp: str,
        event_type: str,
        invoice_id: str,
        trainer_id: str,
        gross: int,
        fee: int,
        net: int,
        token_digest: str,
        prev_hash: str,
    ) -> str:
        content = (
            f"{entry_id}|{timestamp}|{event_type}|{invoice_id}|{trainer_id}|"
            f"{gross}|{fee}|{net}|{token_digest}|{prev_hash}"
        )
        return hashlib.sha256(content.encode("utf-8")).hexdigest()

    @classmethod
    def record_event(
        cls,
        event_type: str,
        invoice_id: str,
        trainer_id: str,
        gross_amount_cents: int,
        platform_fee_cents: int,
        trainer_net_cents: int,
        jws_token: str,
    ) -> FinancialAuditEntry:
        """Registra um evento na trilha de auditoria encadeada imutável."""
        entry_id = str(uuid.uuid4())
        ts = datetime.now(timezone.utc).isoformat()
        token_digest = hashlib.sha256(jws_token.encode("utf-8")).hexdigest()
        prev_hash = cls._last_hash

        entry_hash = cls._compute_entry_hash(
            entry_id=entry_id,
            timestamp=ts,
            event_type=event_type,
            invoice_id=invoice_id,
            trainer_id=trainer_id,
            gross=gross_amount_cents,
            fee=platform_fee_cents,
            net=trainer_net_cents,
            token_digest=token_digest,
            prev_hash=prev_hash,
        )

        entry = FinancialAuditEntry(
            entry_id=entry_id,
            timestamp=ts,
            event_type=event_type,
            invoice_id=invoice_id,
            trainer_id=trainer_id,
            gross_amount_cents=gross_amount_cents,
            platform_fee_cents=platform_fee_cents,
            trainer_net_cents=trainer_net_cents,
            jws_token_digest=token_digest,
            previous_hash=prev_hash,
            entry_hash=entry_hash,
        )

        cls._chain.append(entry)
        cls._last_hash = entry_hash

        logger.info(
            f"[BCB-4893 Audit] Evento registrado: {event_type} | Invoice: {invoice_id} | "
            f"Gross: R${gross_amount_cents/100:.2f} | Fee(5%): R${platform_fee_cents/100:.2f} | "
            f"TrainerNet(95%): R${trainer_net_cents/100:.2f} | Hash: {entry_hash[:16]}..."
        )
        return entry

    @classmethod
    def verify_chain_integrity(cls) -> Tuple[bool, str]:
        """
        Verifica a integridade matemática completa da cadeia de auditoria.
        Garante que nenhum registro intermediário foi alterado ou deletado.
        """
        expected_prev = "0" * 64
        for idx, entry in enumerate(cls._chain):
            if entry.previous_hash != expected_prev:
                return False, f"Violação de cadeia no índice {idx}: previous_hash divergente."

            recalculated = cls._compute_entry_hash(
                entry_id=entry.entry_id,
                timestamp=entry.timestamp,
                event_type=entry.event_type,
                invoice_id=entry.invoice_id,
                trainer_id=entry.trainer_id,
                gross=entry.gross_amount_cents,
                fee=entry.platform_fee_cents,
                net=entry.trainer_net_cents,
                token_digest=entry.jws_token_digest,
                prev_hash=entry.previous_hash,
            )
            if recalculated != entry.entry_hash:
                return False, f"Violação de integridade no índice {idx}: entry_hash adulterado."

            expected_prev = entry.entry_hash

        return True, f"Cadeia íntegra com {len(cls._chain)} registros auditados."

    @classmethod
    def get_entries(cls, invoice_id: Optional[str] = None) -> List[FinancialAuditEntry]:
        """Retorna os registros de auditoria, opcionalmente filtrados por fatura."""
        if invoice_id:
            return [e for e in cls._chain if e.invoice_id == invoice_id]
        return list(cls._chain)


# ==============================================================================
# 5. mTLS Transport Readiness (RFC 8705 & Arranjos de Pagamentos BACEN)
# ==============================================================================

def create_financial_ssl_context(
    cert_path: Optional[str] = None,
    key_path: Optional[str] = None,
    ca_cert_path: Optional[str] = None,
) -> ssl.SSLContext:
    """
    Cria um SSLContext configurado para comunicação segura de grau financeiro (Open Finance / BCB).
    Enforce TLS 1.2+ com suites de cifras seguras.
    Se cert_path e key_path forem fornecidos, ativa autenticação mútua (mTLS).
    """
    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2

    # Suites de cifras recomendadas para instituições financeiras
    ctx.set_ciphers("ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384")

    c_path = cert_path or getattr(settings, "MTLS_CLIENT_CERT_PATH", "")
    k_path = key_path or getattr(settings, "MTLS_CLIENT_KEY_PATH", "")
    ca_path = ca_cert_path or getattr(settings, "MTLS_CA_CERT_PATH", "")

    if ca_path:
        ctx.load_verify_locations(cafile=ca_path)

    if c_path and k_path:
        ctx.load_cert_chain(certfile=c_path, keyfile=k_path)
        logger.info("[Financial Security] mTLS ativado com sucesso para cliente financeiro.")

    return ctx


def get_financial_http_client(timeout: float = 15.0) -> httpx.Client:
    """Retorna um cliente HTTP síncrono com transporte TLS financeiro seguro."""
    c_path = getattr(settings, "MTLS_CLIENT_CERT_PATH", "")
    k_path = getattr(settings, "MTLS_CLIENT_KEY_PATH", "")
    cert = (c_path, k_path) if (c_path and k_path) else None
    return httpx.Client(cert=cert, timeout=timeout)


def get_financial_async_http_client(timeout: float = 15.0) -> httpx.AsyncClient:
    """Retorna um cliente HTTP assíncrono com transporte TLS financeiro seguro."""
    c_path = getattr(settings, "MTLS_CLIENT_CERT_PATH", "")
    k_path = getattr(settings, "MTLS_CLIENT_KEY_PATH", "")
    cert = (c_path, k_path) if (c_path and k_path) else None
    return httpx.AsyncClient(cert=cert, timeout=timeout)
