from app.core.config import Settings


def test_cors_origins_validator():
    # Wildcard string
    assert Settings.assemble_cors_origins("*") == ["*"]
    # Empty string
    assert Settings.assemble_cors_origins("") == ["*"]
    # JSON array string
    assert Settings.assemble_cors_origins('["https://app.com", "http://localhost:5000"]') == ["https://app.com", "http://localhost:5000"]
    # Comma separated string
    assert Settings.assemble_cors_origins("https://app.com, http://localhost:5000") == ["https://app.com", "http://localhost:5000"]
    # Native list
    assert Settings.assemble_cors_origins(["*"]) == ["*"]
