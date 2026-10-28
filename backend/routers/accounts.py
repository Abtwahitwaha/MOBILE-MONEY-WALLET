"""Accounts CRUD (Task 4.2). Every query filters by the logged-in user's id."""
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from auth import CurrentUser
from database import DB
from models import Account, Transaction
from schemas import AccountCreate, AccountOut, AccountUpdate, MessageOut

router = APIRouter(prefix="/accounts", tags=["Accounts"])


def get_owned_account(db: DB, account_id: int, user_id: int, lock: bool = False) -> Account:
    """Return the account only if it belongs to this user; otherwise 404 (never reveals it exists)."""
    query = select(Account).where(Account.account_id == account_id, Account.user_id == user_id)
    if lock:
        query = query.with_for_update().execution_options(populate_existing=True)  # row lock so two requests cannot change the balance together
    account = db.scalar(query)
    if account is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")
    return account


@router.post("/", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
def create_account(payload: AccountCreate, db: DB, user: CurrentUser):
    account = Account(
        user_id=user.user_id,  # owner comes from the token, not from the request body
        provider=payload.provider,
        phone_number=payload.phone_number,
        account_name=payload.account_name,
        opening_balance=payload.opening_balance,
        balance=payload.opening_balance,  # a new account starts at its opening balance
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


@router.get("/", response_model=list[AccountOut])
def list_accounts(db: DB, user: CurrentUser):
    query = select(Account).where(Account.user_id == user.user_id).order_by(Account.account_id)
    return db.scalars(query).all()


@router.get("/{account_id}", response_model=AccountOut)
def get_account(account_id: int, db: DB, user: CurrentUser):
    return get_owned_account(db, account_id, user.user_id)


@router.put("/{account_id}", response_model=AccountOut)
def update_account(account_id: int, payload: AccountUpdate, db: DB, user: CurrentUser):
    account = get_owned_account(db, account_id, user.user_id, lock=True)
    changes = {k: v for k, v in payload.model_dump(exclude_unset=True).items() if v is not None}

    if "opening_balance" in changes:
        # Changing the opening balance shifts the current balance by the same difference.
        account.balance += changes["opening_balance"] - account.opening_balance
        if account.balance < 0:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "That opening balance would make the current balance negative",
            )
    for field, value in changes.items():
        setattr(account, field, value)
    db.commit()
    db.refresh(account)
    return account


@router.delete("/{account_id}", response_model=MessageOut)
def delete_account(account_id: int, db: DB, user: CurrentUser):
    account = get_owned_account(db, account_id, user.user_id)
    used = db.scalar(select(func.count()).select_from(Transaction).where(Transaction.account_id == account_id))
    if used:  # policy: an account with history cannot be deleted
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "This account has transactions and cannot be deleted. Delete its transactions first.",
        )
    db.delete(account)
    db.commit()
    return MessageOut(message="Account deleted")
