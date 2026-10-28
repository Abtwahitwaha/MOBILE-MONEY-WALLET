"""Test setup: runs the API against a throw-away SQLite file, never your MySQL data."""
import os

# These must be set BEFORE the app is imported.
os.environ["DATABASE_URL"] = "sqlite:///./test_wallet.db"
os.environ["SECRET_KEY"] = "test-secret-key-test-secret-key-1234567890"

import pytest
from fastapi.testclient import TestClient

from database import Base, engine
from main import app


@pytest.fixture(autouse=True)
def fresh_database():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
