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
        "https://shaipados-labs.web.app",
        "https://mrcoach.shaipados.com",
        "https://mrcoach.app",
        "https://app.shaipados.com",
    ]
    
    # JSON array string
    s3 = Settings(ENVIRONMENT="development", CORS_ORIGINS='["https://app.com", "http://localhost:5000"]')
    assert s3.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Comma separated string
    s4 = Settings(ENVIRONMENT="development", CORS_ORIGINS="https://app.com, http://localhost:5000")
    assert s4.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Native list
    s5 = Settings(ENVIRONMENT="development", CORS_ORIGINS=["*"])
    assert s5.cors_origins_list == ["*"]
