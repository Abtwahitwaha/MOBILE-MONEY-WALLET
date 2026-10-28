"""SQLAlchemy models = the four tables of the ERD (Phase 3, Task 3.2)."""
import enum
from datetime import datetime
from decimal import Decimal
from typing import List, Optional

from sqlalchemy import DECIMAL, CheckConstraint, Enum, ForeignKey, String, TIMESTAMP, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database import Base


class TransactionType(str, enum.Enum):
    Income = "Income"
    Expense = "Expense"


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    full_name: Mapped[str] = mapped_column(String(100))
    phone_number: Mapped[str] = mapped_column(String(15), unique=True)
    email: Mapped[str] = mapped_column(String(100), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))  # bcrypt hash, never the password
    created_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP, server_default=func.now())

    accounts: Mapped[List["Account"]] = relationship(back_populates="user")
    categories: Mapped[List["Category"]] = relationship(back_populates="user")
    transactions: Mapped[List["Transaction"]] = relationship(back_populates="user")


class Account(Base):
    __tablename__ = "accounts"

    account_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"))  # 1 user : N accounts
    provider: Mapped[str] = mapped_column(String(20))
    phone_number: Mapped[str] = mapped_column(String(15))
    account_name: Mapped[str] = mapped_column(String(50))
    balance: Mapped[Decimal] = mapped_column(DECIMAL(12, 2), server_default=text("0.00"))
    opening_balance: Mapped[Decimal] = mapped_column(DECIMAL(12, 2), server_default=text("0.00"))
    created_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="accounts")
    transactions: Mapped[List["Transaction"]] = relationship(back_populates="account")


class Category(Base):
    __tablename__ = "categories"

    category_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"))  # 1 user : N categories
    name: Mapped[str] = mapped_column(String(50))
    icon: Mapped[Optional[str]] = mapped_column(String(50))
    created_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="categories")
    transactions: Mapped[List["Transaction"]] = relationship(back_populates="category")


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (CheckConstraint("amount > 0", name="ck_transactions_amount_positive"),)

    transaction_id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id"))
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.account_id"))
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.category_id"))
    type: Mapped[TransactionType] = mapped_column(Enum(TransactionType))
    amount: Mapped[Decimal] = mapped_column(DECIMAL(12, 2))
    description: Mapped[Optional[str]] = mapped_column(String(255))
    transaction_date: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP, server_default=func.now())
    created_at: Mapped[Optional[datetime]] = mapped_column(TIMESTAMP, server_default=func.now())

    user: Mapped["User"] = relationship(back_populates="transactions")
    account: Mapped["Account"] = relationship(back_populates="transactions")
    category: Mapped["Category"] = relationship(back_populates="transactions")

    # Convenience fields so the Flutter list screen does not need extra requests.
    @property
    def account_name(self) -> str:
        return self.account.account_name

    @property
    def category_name(self) -> str:
        return self.category.name
