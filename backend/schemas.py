"""Pydantic schemas = what the API accepts and returns (Phase 3, Task 3.3).

FastAPI validates every request body against these classes and answers
422 automatically when the data is wrong. Notice that no schema accepts a
`user_id`: the owner always comes from the token, never from the client.
"""
import re
from datetime import datetime
from decimal import Decimal
from typing import Annotated, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, PlainSerializer, field_validator

from models import TransactionType

# Money comes in as an exact Decimal (max 12 digits, 2 decimals, like DECIMAL(12,2))
# and goes out as a JSON number, which is easier for Flutter than a string.
MoneyOut = Annotated[Decimal, PlainSerializer(lambda v: float(v), return_type=float, when_used="json")]
Amount = Annotated[Decimal, Field(gt=0, max_digits=12, decimal_places=2)]
Balance = Annotated[Decimal, Field(ge=0, max_digits=12, decimal_places=2)]

_PHONE_RE = re.compile(r"^\+?[0-9]{9,14}$")


def _clean_phone(value: Optional[str]) -> Optional[str]:
    if value is None:
        return value
    value = re.sub(r"[\s-]", "", value)
    if not _PHONE_RE.match(value):
        raise ValueError("Phone number must have 9-14 digits, optionally starting with +")
    return value


class _Input(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)


class _Output(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class MessageOut(BaseModel):
    message: str


# ---------- Users / auth ----------
class UserCreate(_Input):
    full_name: str = Field(min_length=2, max_length=100)
    phone_number: str
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)

    @field_validator("phone_number")
    @classmethod
    def _check_phone(cls, v):
        return _clean_phone(v)

    @field_validator("email")
    @classmethod
    def _lower_email(cls, v: str) -> str:
        return v.lower()

    @field_validator("password")
    @classmethod
    def _password_rules(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:  # bcrypt only reads the first 72 bytes
            raise ValueError("Password is too long (maximum 72 bytes)")
        if not (any(c.isalpha() for c in v) and any(c.isdigit() for c in v)):
            raise ValueError("Password must contain at least one letter and one digit")
        return v


class LoginRequest(_Input):
    email: EmailStr
    password: str = Field(min_length=1, max_length=72)

    @field_validator("email")
    @classmethod
    def _lower_email(cls, v: str) -> str:
        return v.lower()


class UserOut(_Output):  # note: no password_hash here, ever
    user_id: int
    full_name: str
    phone_number: str
    email: str
    created_at: Optional[datetime] = None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- Accounts ----------
class AccountCreate(_Input):
    provider: str = Field(min_length=2, max_length=20, examples=["MTN"])
    phone_number: str = Field(examples=["0771234567"])
    account_name: str = Field(min_length=1, max_length=50, examples=["My MTN Wallet"])
    opening_balance: Balance = Decimal("0.00")

    @field_validator("phone_number")
    @classmethod
    def _check_phone(cls, v):
        return _clean_phone(v)


class AccountUpdate(_Input):
    provider: Optional[str] = Field(default=None, min_length=2, max_length=20)
    phone_number: Optional[str] = None
    account_name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    opening_balance: Optional[Balance] = None

    @field_validator("phone_number")
    @classmethod
    def _check_phone(cls, v):
        return _clean_phone(v)


class AccountOut(_Output):
    account_id: int
    provider: str
    phone_number: str
    account_name: str
    balance: MoneyOut
    opening_balance: MoneyOut
    created_at: Optional[datetime] = None


# ---------- Categories ----------
class CategoryCreate(_Input):
    name: str = Field(min_length=1, max_length=50, examples=["Food"])
    icon: Optional[str] = Field(default=None, max_length=50, examples=["restaurant"])


class CategoryUpdate(_Input):
    name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    icon: Optional[str] = Field(default=None, max_length=50)


class CategoryOut(_Output):
    category_id: int
    name: str
    icon: Optional[str] = None
    created_at: Optional[datetime] = None


# ---------- Transactions ----------
class TransactionCreate(_Input):
    account_id: int
    category_id: int
    type: TransactionType
    amount: Amount
    description: Optional[str] = Field(default=None, max_length=255)
    transaction_date: Optional[datetime] = None  # defaults to "now" in the database


class TransactionUpdate(_Input):
    account_id: Optional[int] = None
    category_id: Optional[int] = None
    type: Optional[TransactionType] = None
    amount: Optional[Amount] = None
    description: Optional[str] = Field(default=None, max_length=255)
    transaction_date: Optional[datetime] = None


class TransactionOut(_Output):
    transaction_id: int
    account_id: int
    category_id: int
    type: TransactionType
    amount: MoneyOut
    description: Optional[str] = None
    transaction_date: Optional[datetime] = None
    created_at: Optional[datetime] = None
    account_name: str
    category_name: str
