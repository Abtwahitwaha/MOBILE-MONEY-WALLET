"""Password hashing and JWT authentication (Phase 4 Task 4.1, Phase 5 Task 5.1)."""
import os
from datetime import datetime, timedelta, timezone
from typing import Annotated

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select

from database import DB
from models import User

load_dotenv()

# The secret key signs every token. It lives in .env, never in the code or on GitHub.
SECRET_KEY = os.getenv("SECRET_KEY", "")
if len(SECRET_KEY) < 32:
    raise RuntimeError(
        "SECRET_KEY is missing or too short. Add a random value of at least 32 characters to .env "
        '(python -c "import secrets; print(secrets.token_hex(32))").'
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

# Tells Swagger where to log in; also reads "Authorization: Bearer <token>" from requests.
# A missing header makes FastAPI answer 401 by itself.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")


def hash_password(password: str) -> str:
    """bcrypt adds a random salt, so the same password gives a different hash each time."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:  # malformed hash or over-long password
        return False


def create_access_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),  # "subject" = who this token belongs to
        "iat": now,
        "exp": now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),  # token expires automatically
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(db: DB, token: Annotated[str, Depends(oauth2_scheme)]) -> User:
    """Dependency used by every protected endpoint: token -> User, or 401."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])  # checks signature + expiry
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise unauthorized
    user = db.scalar(select(User).where(User.user_id == user_id))
    if user is None:
        raise unauthorized
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
