"""Database connection (Phase 3, Task 3.1).

Reads the settings from the .env file, creates the SQLAlchemy engine and gives
every request its own database session through the `get_db` dependency.
"""
import os
from typing import Annotated, Iterator
from urllib.parse import quote_plus

from dotenv import load_dotenv
from fastapi import Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

load_dotenv()  # loads backend/.env into environment variables


def build_database_url() -> str:
    """Build the connection string from .env (DATABASE_URL overrides it; the tests use that)."""
    explicit = os.getenv("DATABASE_URL")
    if explicit:
        return explicit
    user = quote_plus(os.getenv("DB_USER", "root"))
    password = quote_plus(os.getenv("DB_PASSWORD", ""))  # quote_plus handles characters like @ or #
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "3306")
    name = os.getenv("DB_NAME", "mobile_money_wallet")
    return f"mysql+pymysql://{user}:{password}@{host}:{port}/{name}?charset=utf8mb4"


DATABASE_URL = build_database_url()
_connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

# pool_pre_ping checks a connection is alive before using it (avoids "MySQL has gone away").
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=_connect_args)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    """Parent class of all models in models.py."""


def get_db() -> Iterator[Session]:
    """One session per request; always closed afterwards.

    If a request fails before db.commit(), closing the session discards the
    half-finished changes, which is what keeps balances consistent.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


DB = Annotated[Session, Depends(get_db)]
