from app.core.config import Settings


def test_cors_origins_validator():
    # Wildcard string
    s1 = Settings(CORS_ORIGINS="*")
    assert s1.cors_origins_list == ["*"]
    
    # Empty string
    s2 = Settings(CORS_ORIGINS="")
    assert s2.cors_origins_list == ["*"]
    
    # JSON array string
    s3 = Settings(CORS_ORIGINS='["https://app.com", "http://localhost:5000"]')
    assert s3.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Comma separated string
    s4 = Settings(CORS_ORIGINS="https://app.com, http://localhost:5000")
    assert s4.cors_origins_list == ["https://app.com", "http://localhost:5000"]
    
    # Native list
    s5 = Settings(CORS_ORIGINS=["*"])
    assert s5.cors_origins_list == ["*"]
