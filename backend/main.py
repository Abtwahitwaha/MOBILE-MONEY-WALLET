"""Mobile Money Wallet API: entry point (Phase 1, Task 1.4, plus all routers)."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import OperationalError, SQLAlchemyError

from database import Base, SessionLocal, engine
import models  # noqa: F401  (makes sure all models are registered before create_all)
from routers import accounts, categories, transactions, users

logger = logging.getLogger("wallet")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Creates any table that does not exist yet. If you already ran schema.sql, this does nothing.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Mobile Money Wallet API",
    description="Backend API for the Mobile Money Wallet application",
    version="1.0.0",
    lifespan=lifespan,
)

# Lets a Flutter *web* build call the API. Mobile apps do not need CORS.
# For a real deployment, replace "*" with your app's address.
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.exception_handler(OperationalError)
async def database_unavailable(request: Request, exc: OperationalError):
    logger.exception("Database unavailable")
    return JSONResponse(status_code=503, content={"detail": "Database is unavailable. Please try again later."})


@app.exception_handler(SQLAlchemyError)
async def database_error(request: Request, exc: SQLAlchemyError):
    # Details go to the server log only, never to the client (Task 5.1).
    logger.exception("Database error")
    return JSONResponse(status_code=500, content={"detail": "A database error occurred."})


app.include_router(users.router)
app.include_router(accounts.router)
app.include_router(categories.router)
app.include_router(transactions.router)


@app.get("/", tags=["Health"])
def home():
    return {"message": "Mobile Money Wallet API is running"}


@app.get("/health", tags=["Health"])
def health():
    """Checks the database connection too."""
    with SessionLocal() as db:
        db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}
