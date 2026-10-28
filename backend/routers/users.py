"""Authentication endpoints: register, login, me (Task 4.1)."""
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from auth import CurrentUser, create_access_token, hash_password, verify_password
from database import DB
from models import Category, User
from schemas import LoginRequest, TokenOut, UserCreate, UserOut

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Every new user starts with these categories (stored in the database, not in Flutter).
DEFAULT_CATEGORIES = [
    ("Food", "restaurant"),
    ("Transport", "directions_bus"),
    ("Rent", "home"),
    ("Airtime", "phone_android"),
    ("Shopping", "shopping_bag"),
    ("Salary", "payments"),
    ("Business income", "store"),
]


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: DB):
    if db.scalar(select(User).where(User.email == payload.email)):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email is already registered")
    if db.scalar(select(User).where(User.phone_number == payload.phone_number)):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Phone number is already registered")

    user = User(
        full_name=payload.full_name,
        phone_number=payload.phone_number,
        email=payload.email,
        password_hash=hash_password(payload.password),
    )
    db.add(user)
    db.flush()  # sends the INSERT so user.user_id exists, but nothing is committed yet
    db.add_all(Category(user_id=user.user_id, name=n, icon=i) for n, i in DEFAULT_CATEGORIES)
    try:
        db.commit()  # user + default categories are saved together or not at all
    except IntegrityError:  # two people registering the same email at the same moment
        db.rollback()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Email or phone number is already registered")
    db.refresh(user)
    return user


def _authenticate(db: DB, email: str, password: str) -> TokenOut:
    user = db.scalar(select(User).where(User.email == email.lower()))
    # Same message for "no such user" and "wrong password" so attackers learn nothing.
    if user is None or not verify_password(password, user.password_hash):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenOut(access_token=create_access_token(user.user_id), user=UserOut.model_validate(user))


@router.post("/login", response_model=TokenOut)
def login(payload: LoginRequest, db: DB):
    """JSON login used by the Flutter app."""
    return _authenticate(db, payload.email, payload.password)


@router.post("/token", response_model=TokenOut, include_in_schema=True)
def login_form(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB):
    """Form login used by Swagger's green 'Authorize' button (put your email in 'username')."""
    return _authenticate(db, form.username, form.password)


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser):
    return user
