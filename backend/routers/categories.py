"""Categories CRUD (Task 4.3)."""
from typing import Optional

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from auth import CurrentUser
from database import DB
from models import Category, Transaction
from schemas import CategoryCreate, CategoryOut, CategoryUpdate, MessageOut

router = APIRouter(prefix="/categories", tags=["Categories"])


def get_owned_category(db: DB, category_id: int, user_id: int) -> Category:
    category = db.scalar(
        select(Category).where(Category.category_id == category_id, Category.user_id == user_id)
    )
    if category is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Category not found")
    return category


def _name_taken(db: DB, user_id: int, name: str, ignore_id: Optional[int] = None) -> bool:
    query = select(Category.category_id).where(
        Category.user_id == user_id, func.lower(Category.name) == name.lower()
    )
    if ignore_id is not None:
        query = query.where(Category.category_id != ignore_id)
    return db.scalar(query) is not None


@router.post("/", response_model=CategoryOut, status_code=status.HTTP_201_CREATED)
def create_category(payload: CategoryCreate, db: DB, user: CurrentUser):
    if _name_taken(db, user.user_id, payload.name):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You already have a category with that name")
    category = Category(user_id=user.user_id, name=payload.name, icon=payload.icon)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.get("/", response_model=list[CategoryOut])
def list_categories(db: DB, user: CurrentUser):
    query = select(Category).where(Category.user_id == user.user_id).order_by(Category.name)
    return db.scalars(query).all()


@router.get("/{category_id}", response_model=CategoryOut)
def get_category(category_id: int, db: DB, user: CurrentUser):
    return get_owned_category(db, category_id, user.user_id)


@router.put("/{category_id}", response_model=CategoryOut)
def update_category(category_id: int, payload: CategoryUpdate, db: DB, user: CurrentUser):
    category = get_owned_category(db, category_id, user.user_id)
    changes = payload.model_dump(exclude_unset=True)
    if changes.get("name") is not None:
        if _name_taken(db, user.user_id, changes["name"], ignore_id=category_id):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "You already have a category with that name")
        category.name = changes["name"]
    if "icon" in changes:  # icon may be set to null on purpose
        category.icon = changes["icon"]
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", response_model=MessageOut)
def delete_category(category_id: int, db: DB, user: CurrentUser):
    category = get_owned_category(db, category_id, user.user_id)
    used = db.scalar(select(func.count()).select_from(Transaction).where(Transaction.category_id == category_id))
    if used:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "This category is used by transactions and cannot be deleted.",
        )
    db.delete(category)
    db.commit()
    return MessageOut(message="Category deleted")
