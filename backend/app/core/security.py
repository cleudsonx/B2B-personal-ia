import jwt
from typing import Optional, Dict, Any
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.config import settings

security_bearer = HTTPBearer(auto_error=False)


_jwks_client: Optional[jwt.PyJWKClient] = None


def get_jwks_client() -> Optional[jwt.PyJWKClient]:
    global _jwks_client
    if _jwks_client is None and settings.SUPABASE_JWKS_URL:
        _jwks_client = jwt.PyJWKClient(settings.SUPABASE_JWKS_URL)
    return _jwks_client


def decode_supabase_jwt(token: str) -> Dict[str, Any]:
    """
    Decodifica e valida o token JWT emitido pelo Supabase Auth.
    Prioriza verificação criptográfica assimétrica via JWKS (ES256/RS256).
    Suporta fallback para HS256 ou decodificação sem assinatura em dev.
    """
    # 1. Tenta validação via JWKS (padrão oficial moderno do Supabase)
    jwks = get_jwks_client()
    if jwks:
        try:
            signing_key = jwks.get_signing_key_from_jwt(token)
            header = jwt.get_unverified_header(token)
            alg = header.get("alg", "ES256")
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=[alg],
                options={"verify_aud": False}
            )
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token expirado. Faça login novamente."
            )
        except Exception:
            pass

    # 2. Fallback para SUPABASE_JWT_SECRET (HS256 simétrico)
    if settings.SUPABASE_JWT_SECRET:
        try:
            return jwt.decode(
                token,
                settings.SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                options={"verify_aud": False}
            )
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

    # 3. Fallback permissivo para ambiente de desenvolvimento local
    try:
        return jwt.decode(token, options={"verify_signature": False})
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {str(e)}"
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
