import jwt
from typing import Optional, Dict, Any
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.config import settings

security_bearer = HTTPBearer(auto_error=False)


def decode_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Decodes and validates Supabase JWT token.
    If SUPABASE_JWT_SECRET is set, enforces cryptographic signature verification.
    """
    if not settings.SUPABASE_JWT_SECRET:
        # In early dev without secret configured, decode payload without verification (warn in dev)
        try:
            return jwt.decode(token, options={"verify_signature": False})
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token inválido: {str(e)}"
            )
            
    try:
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expirado. Faça login novamente."
        )
    except jwt.PyJWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Assinatura do token inválida: {str(e)}"
        )


async def get_current_user_payload(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer)
) -> Dict[str, Any]:
    """
    FastAPI dependency to extract and validate the authenticated user from the Authorization header.
    """
    if not credentials:
        # If in development mode and no auth provided, return a mock user payload for easy testing
        if settings.ENVIRONMENT == "development":
            return {
                "sub": "dev-user-0000-0000-000000000001",
                "role": "authenticated",
                "email": "dev@local.test"
            }
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Header de Autorização ausente."
        )

    return decode_supabase_jwt(credentials.credentials)
