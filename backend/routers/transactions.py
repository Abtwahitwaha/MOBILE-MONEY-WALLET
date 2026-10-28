"""Transactions CRUD with automatic balance updates (Task 4.4).

Balance rule:  Income adds to the account balance, Expense subtracts from it.
Create, edit and delete each change the transaction row AND the balance inside
ONE database transaction: a single db.commit() at the end saves both, and any
error before it (an HTTPException, a crash) leaves the database untouched.
Overdrafts are not allowed: a balance may never go below 0.
"""
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import joinedload

from auth import CurrentUser
from database import DB
from models import Account, Category, Transaction, TransactionType
from routers.categories import get_owned_category
from schemas import MessageOut, TransactionCreate, TransactionOut, TransactionUpdate

router = APIRouter(prefix="/transactions", tags=["Transactions"])


def _signed(tx_type: TransactionType, amount: Decimal) -> Decimal:
    """+amount for income, -amount for expense."""
    return amount if tx_type == TransactionType.Income else -amount


def _lock_accounts(db: DB, user_id: int, account_ids: set[int]) -> dict[int, Account]:
    """Fetch (and row-lock) the user's accounts. Ordered by id so two requests cannot deadlock."""
    query = (
        select(Account)
        .where(Account.user_id == user_id, Account.account_id.in_(account_ids))
        .order_by(Account.account_id)
        .with_for_update()
        .execution_options(populate_existing=True)  # re-read the balance after locking
    )
    return {a.account_id: a for a in db.scalars(query).all()}


def _get_owned_transaction(db: DB, transaction_id: int, user_id: int) -> Transaction:
    tx = db.scalar(
        select(Transaction)
        .where(Transaction.transaction_id == transaction_id, Transaction.user_id == user_id)
        .options(joinedload(Transaction.account), joinedload(Transaction.category))
    )
    if tx is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Transaction not found")
    return tx


def _check_balances(accounts: dict[int, Account]) -> None:
    for account in accounts.values():
        if account.balance < 0:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                f"Insufficient balance in '{account.account_name}' for this operation",
            )


@router.post("/", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
def create_transaction(payload: TransactionCreate, db: DB, user: CurrentUser):
    accounts = _lock_accounts(db, user.user_id, {payload.account_id})
    account = accounts.get(payload.account_id)
    if account is None:  # missing OR belongs to someone else: same answer
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")
    get_owned_category(db, payload.category_id, user.user_id)  # 404 if not the user's category

    account.balance += _signed(payload.type, payload.amount)
    _check_balances(accounts)

    tx = Transaction(
        user_id=user.user_id,
        account_id=payload.account_id,
        category_id=payload.category_id,
        type=payload.type,
        amount=payload.amount,
        description=payload.description,
    )
    if payload.transaction_date is not None:
        tx.transaction_date = payload.transaction_date
    db.add(tx)
    db.commit()  # transaction row and new balance are saved together
    db.refresh(tx)
    return tx


@router.get("/", response_model=list[TransactionOut])
def list_transactions(
    db: DB,
    user: CurrentUser,
    account_id: Optional[int] = None,
    category_id: Optional[int] = None,
    type: Optional[TransactionType] = None,
    search: Optional[str] = Query(default=None, max_length=100, description="Search in description"),
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=500),
):
    query = (
        select(Transaction)
        .where(Transaction.user_id == user.user_id)
        .options(joinedload(Transaction.account), joinedload(Transaction.category))
        .order_by(Transaction.transaction_date.desc(), Transaction.transaction_id.desc())
        .offset(skip)
        .limit(limit)
    )
    if account_id is not None:
        query = query.where(Transaction.account_id == account_id)
    if category_id is not None:
        query = query.where(Transaction.category_id == category_id)
    if type is not None:
        query = query.where(Transaction.type == type)
    if search:
        query = query.where(Transaction.description.ilike(f"%{search}%"))
    return db.scalars(query).all()


@router.get("/{transaction_id}", response_model=TransactionOut)
def get_transaction(transaction_id: int, db: DB, user: CurrentUser):
    return _get_owned_transaction(db, transaction_id, user.user_id)


@router.put("/{transaction_id}", response_model=TransactionOut)
def update_transaction(transaction_id: int, payload: TransactionUpdate, db: DB, user: CurrentUser):
    tx = _get_owned_transaction(db, transaction_id, user.user_id)

    # Only fields the client sent; null is ignored except for "description" (may be cleared).
    changes = {
        k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None or k == "description"
    }
    new_account_id = changes.get("account_id", tx.account_id)
    new_type = changes.get("type", tx.type)
    new_amount = changes.get("amount", tx.amount)

    accounts = _lock_accounts(db, user.user_id, {tx.account_id, new_account_id})
    if tx.account_id not in accounts or new_account_id not in accounts:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")
    if "category_id" in changes:
        get_owned_category(db, changes["category_id"], user.user_id)

    # 1) reverse the old effect, 2) apply the new effect, 3) make sure nothing went negative
    accounts[tx.account_id].balance -= _signed(tx.type, tx.amount)
    accounts[new_account_id].balance += _signed(new_type, new_amount)
    _check_balances(accounts)

    for field, value in changes.items():
        setattr(tx, field, value)
    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{transaction_id}", response_model=MessageOut)
def delete_transaction(transaction_id: int, db: DB, user: CurrentUser):
    tx = _get_owned_transaction(db, transaction_id, user.user_id)
    accounts = _lock_accounts(db, user.user_id, {tx.account_id})
    account = accounts.get(tx.account_id)
    if account is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")

    account.balance -= _signed(tx.type, tx.amount)  # reverse the effect of this transaction
    _check_balances(accounts)  # e.g. deleting income that was already spent would go negative
    db.delete(tx)
    db.commit()
    return MessageOut(message="Transaction deleted and balance updated")
