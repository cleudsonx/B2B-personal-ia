from app.core.config import Settings


def test_cors_origins_validator():
    # Wildcard is permitted in development only
    s1 = Settings(ENVIRONMENT="development", CORS_ORIGINS="*")
    assert s1.cors_origins_list == ["*"]
    
    # Empty string
    s2 = Settings(ENVIRONMENT="development", CORS_ORIGINS="")
    assert s2.cors_origins_list == ["*"]

    production_wildcard = Settings(ENVIRONMENT="production", CORS_ORIGINS="*")
    assert production_wildcard.cors_origins_list == [
        "https://shaipados.com",
        "https://www.shaipados.com",
        "https://shaipados-labs.web.app",
        "https://shaipados-labs.firebaseapp.com",
        "https://mrcoach.shaipados.com",
        "https://mrcoach.app",
        "https://app.shaipados.com",
        "https://shapelab.ia.br",
        "https://www.shapelab.ia.br",
        "https://app.shapelab.ia.br",
        "https://mrcoach.shapelab.ia.br",
    ]

    # Dual-domain auto-enrichment when legacy shaipados.com list is provided in production
    legacy_prod = Settings(
        ENVIRONMENT="production",
        CORS_ORIGINS='["https://shaipados.com", "https://shaipados-labs.web.app"]',
    )
    assert "https://shaipados.com" in legacy_prod.cors_origins_list
    assert "https://shapelab.ia.br" in legacy_prod.cors_origins_list
    assert "https://www.shapelab.ia.br" in legacy_prod.cors_origins_list
    assert "https://app.shapelab.ia.br" in legacy_prod.cors_origins_list
    
    # JSON array string
    s3 = Settings(ENVIRONMENT="development", CORS_ORIGINS='["https://app.com", "http://localhost:5000"]')
    assert s3.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Comma separated string
    s4 = Settings(ENVIRONMENT="development", CORS_ORIGINS="https://app.com, http://localhost:5000")
    assert s4.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Native list
    s5 = Settings(ENVIRONMENT="development", CORS_ORIGINS=["*"])
    assert s5.cors_origins_list == ["*"]
