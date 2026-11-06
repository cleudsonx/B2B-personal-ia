# backend/tests/test_financial_security_bcb4893.py
"""
Suíte de Testes de Segurança Cibernética & Split Payment (Resolução BCB nº 4.893)
Verifica:
- Assinatura Digital JWS (RFC 7515) para comandos de split
- Detecção e bloqueio de adulteração de parâmetros (integridade matemática)
- Validação temporal contra ataques de replay
- Trilha de Auditoria Criptográfica com encadeamento de hashes SHA-256
- Transporte seguro mTLS readiness
"""

import time
import pytest
from app.core.financial_security import (
    JwsSplitCommandService,
    FinancialAuditTrail,
    create_financial_ssl_context,
    b64url_encode,
    b64url_decode,
    get_financial_signing_key,
)


def test_b64url_roundtrip():
    """Valida encode e decode Base64URL sem padding (RFC 7515)."""
    raw = b"Shaipados Labs BCB 4893 - Open Finance Split 2026!?"
    encoded = b64url_encode(raw)
    assert "=" not in encoded
    decoded = b64url_decode(encoded)
    assert decoded == raw


def test_jws_sign_and_verify_valid_split_command():
    """Gera e valida comando de split de 5% / 95% via JWS."""
    payload = {
        "invoice_id": "inv_test_bcb_001",
        "trainer_id": "trainer_uuid_12345",
        "trainer_wallet_id": "wal_asaas_9999",
        "gross_amount_cents": 20000,
        "platform_fee_percent": 5.0,
        "platform_fee_cents": 1000,
        "trainer_net_cents": 19000,
    }

    token = JwsSplitCommandService.sign_split_command(payload)
    assert isinstance(token, str)
    assert len(token.split(".")) == 3

    verified = JwsSplitCommandService.verify_split_command(token)
    assert verified["invoice_id"] == "inv_test_bcb_001"
    assert verified["gross_amount_cents"] == 20000
    assert verified["platform_fee_cents"] == 1000
    assert verified["trainer_net_cents"] == 19000
    assert verified["compliance_standard"] == "BCB_4893_CYBERSECURITY_V1"
    assert "jti" in verified
    assert "iat" in verified
    assert "exp" in verified


def test_jws_tampering_detection():
    """Garante que qualquer alteração de valor no payload invalida a assinatura."""
    payload = {
        "invoice_id": "inv_test_tamper",
        "trainer_id": "trainer_orig",
        "gross_amount_cents": 20000,
        "platform_fee_cents": 1000,
        "trainer_net_cents": 19000,
    }
    token = JwsSplitCommandService.sign_split_command(payload)
    parts = token.split(".")

    # Decodifica payload original e altera valor líquido para fraude
    import json
    p_dict = json.loads(b64url_decode(parts[1]).decode("utf-8"))
    p_dict["trainer_net_cents"] = 19999  # Fraude de valor
    tampered_b64 = b64url_encode(json.dumps(p_dict, separators=(",", ":"), sort_keys=True).encode("utf-8"))
    tampered_token = f"{parts[0]}.{tampered_b64}.{parts[2]}"

    with pytest.raises(ValueError, match="Assinatura JWS inválida ou comando de split adulterado"):
        JwsSplitCommandService.verify_split_command(tampered_token)


def test_jws_expired_token_rejection():
    """Garante que comandos expirados são sumariamente rejeitados."""
    past_ts = int(time.time()) - 400
    payload = {
        "invoice_id": "inv_expired",
        "trainer_id": "trainer_1",
        "gross_amount_cents": 10000,
        "platform_fee_cents": 500,
        "trainer_net_cents": 9500,
        "iat": past_ts - 100,
        "exp": past_ts,
    }
    token = JwsSplitCommandService.sign_split_command(payload)
    with pytest.raises(ValueError, match="Comando de split JWS expirado"):
        JwsSplitCommandService.verify_split_command(token, enforce_expiration=True)


def test_financial_audit_trail_chain_integrity():
    """Valida encadeamento criptográfico imutável na trilha de auditoria BCB 4.893."""
    FinancialAuditTrail._chain.clear()
    FinancialAuditTrail._last_hash = "0" * 64

    # Registro 1
    e1 = FinancialAuditTrail.record_event(
        event_type="SPLIT_COMMAND_CREATED",
        invoice_id="inv_audit_1",
        trainer_id="trainer_1",
        gross_amount_cents=10000,
        platform_fee_cents=500,
        trainer_net_cents=9500,
        jws_token="dummy.jws.token1",
    )
    assert e1.previous_hash == "0" * 64
    assert len(e1.entry_hash) == 64

    # Registro 2
    e2 = FinancialAuditTrail.record_event(
        event_type="SPLIT_SETTLED",
        invoice_id="inv_audit_1",
        trainer_id="trainer_1",
        gross_amount_cents=10000,
        platform_fee_cents=500,
        trainer_net_cents=9500,
        jws_token="dummy.jws.token1_settled",
    )
    assert e2.previous_hash == e1.entry_hash

    # Verifica integridade da cadeia
    is_valid, msg = FinancialAuditTrail.verify_chain_integrity()
    assert is_valid is True
    assert "2 registros auditados" in msg


def test_financial_audit_trail_detects_tampering():
    """Garante que alteração em qualquer bloco histórico corrompe a verificação da cadeia."""
    FinancialAuditTrail._chain.clear()
    FinancialAuditTrail._last_hash = "0" * 64

    FinancialAuditTrail.record_event(
        event_type="SPLIT_COMMAND_CREATED",
        invoice_id="inv_1",
        trainer_id="trainer_1",
        gross_amount_cents=15000,
        platform_fee_cents=750,
        trainer_net_cents=14250,
        jws_token="token.1",
    )
    FinancialAuditTrail.record_event(
        event_type="SPLIT_SETTLED",
        invoice_id="inv_1",
        trainer_id="trainer_1",
        gross_amount_cents=15000,
        platform_fee_cents=750,
        trainer_net_cents=14250,
        jws_token="token.2",
    )

    # Violação maliciosa no registro 0
    FinancialAuditTrail._chain[0].gross_amount_cents = 99999

    is_valid, err_msg = FinancialAuditTrail.verify_chain_integrity()
    assert is_valid is False
    assert "Violação de integridade" in err_msg


def test_mtls_ssl_context_configuration():
    """Valida que o contexto SSL financeiro enforce TLS 1.2+ e cifras seguras."""
    import ssl
    ctx = create_financial_ssl_context()
    assert ctx.minimum_version == ssl.TLSVersion.TLSv1_2
