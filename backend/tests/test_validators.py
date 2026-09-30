from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_validate_cref_valid():
    res = client.post("/api/v1/validators/verify-document", json={
        "document_type": "CREF",
        "document_value": "019284-G/SP"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["is_valid"] is True
    assert data["formatted"] == "CREF 019284-G/SP"
    assert "confef.org.br" in data["verification_url"]

def test_validate_cref_invalid_uf():
    res = client.post("/api/v1/validators/verify-document", json={
        "document_type": "CREF",
        "document_value": "019284-G/XX"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["is_valid"] is False
    assert "válido" in data["error_message"]

def test_validate_cbmf_valid():
    res = client.post("/api/v1/validators/verify-document", json={
        "document_type": "CBMF",
        "document_value": "CBMF-10294"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["is_valid"] is True
    assert data["formatted"] == "CBMF-10294"
    assert "portaldofiliadocbmf.abacusai.app" in data["verification_url"]

def test_validate_cpf_valid():
    # Exemplo clássico de CPF válido (teste padrão com dígitos verificadores corretos)
    res = client.post("/api/v1/validators/verify-document", json={
        "document_type": "CPF",
        "document_value": "52998224725"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["is_valid"] is True
    assert data["formatted"] == "529.982.247-25"

def test_validate_cpf_invalid():
    res = client.post("/api/v1/validators/verify-document", json={
        "document_type": "CPF",
        "document_value": "111.111.111-11"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["is_valid"] is False
    assert "repetida" in data["error_message"] or "permitida" in data["error_message"]
