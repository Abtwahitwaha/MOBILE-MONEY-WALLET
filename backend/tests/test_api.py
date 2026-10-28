"""End-to-end API tests that mirror the Task 7.1 checklist. Run with:  pytest -v"""
from database import SessionLocal
from models import User


# ---------- helpers ----------
def make_user(client, n=1, password="Passw0rd!"):
    body = {
        "full_name": f"Test User {n}",
        "phone_number": f"07700000{n:02d}",
        "email": f"user{n}@example.com",
        "password": password,
    }
    assert client.post("/auth/register", json=body).status_code == 201
    r = client.post("/auth/login", json={"email": body["email"], "password": password})
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def make_account(client, headers, opening=100000, name="My MTN Wallet"):
    r = client.post(
        "/accounts/",
        headers=headers,
        json={"provider": "MTN", "phone_number": "0771234567", "account_name": name, "opening_balance": opening},
    )
    assert r.status_code == 201, r.text
    return r.json()


def category_id(client, headers, name="Transport"):
    cats = client.get("/categories/", headers=headers).json()
    return next(c["category_id"] for c in cats if c["name"] == name)


def add_tx(client, headers, account_id, cat_id, type_, amount, description=None):
    return client.post(
        "/transactions/",
        headers=headers,
        json={"account_id": account_id, "category_id": cat_id, "type": type_, "amount": amount, "description": description},
    )


def balance(client, headers, account_id):
    return client.get(f"/accounts/{account_id}", headers=headers).json()["balance"]


# ---------- auth ----------
def test_root_and_docs_open(client):
    assert client.get("/").status_code == 200
    assert client.get("/docs").status_code == 200


def test_register_valid_user_and_hide_hash(client):
    r = client.post(
        "/auth/register",
        json={"full_name": "Amina K", "phone_number": "0771234567", "email": "Amina@Example.com", "password": "Secret123"},
    )
    assert r.status_code == 201
    assert "password" not in r.text and "hash" not in r.text
    assert r.json()["email"] == "amina@example.com"  # stored lower-case


def test_password_is_stored_hashed(client):
    make_user(client)
    with SessionLocal() as db:
        user = db.query(User).first()
        assert user.password_hash != "Passw0rd!"
        assert user.password_hash.startswith("$2")  # bcrypt


def test_register_duplicate_email_and_phone_rejected(client):
    make_user(client, 1)
    body = {"full_name": "Other", "phone_number": "0788888888", "email": "user1@example.com", "password": "Passw0rd!"}
    assert client.post("/auth/register", json=body).status_code == 400
    body = {"full_name": "Other", "phone_number": "0770000001", "email": "new@example.com", "password": "Passw0rd!"}
    assert client.post("/auth/register", json=body).status_code == 400


def test_register_validation_errors_give_422(client):
    bad = {"full_name": "X", "phone_number": "abc", "email": "not-an-email", "password": "short"}
    assert client.post("/auth/register", json=bad).status_code == 422


def test_login_wrong_password_and_unknown_user(client):
    make_user(client)
    assert client.post("/auth/login", json={"email": "user1@example.com", "password": "Wrong123"}).status_code == 401
    assert client.post("/auth/login", json={"email": "nobody@example.com", "password": "Passw0rd!"}).status_code == 401


def test_swagger_form_login_works(client):
    make_user(client)
    r = client.post("/auth/token", data={"username": "user1@example.com", "password": "Passw0rd!"})
    assert r.status_code == 200 and r.json()["access_token"]


def test_me_returns_current_user(client):
    h = make_user(client)
    r = client.get("/auth/me", headers=h)
    assert r.status_code == 200 and r.json()["email"] == "user1@example.com"


def test_protected_endpoints_need_a_valid_token(client):
    for path in ["/auth/me", "/accounts/", "/categories/", "/transactions/"]:
        assert client.get(path).status_code == 401
        assert client.get(path, headers={"Authorization": "Bearer garbage"}).status_code == 401


# ---------- accounts / categories ----------
def test_default_categories_created_on_register(client):
    h = make_user(client)
    names = {c["name"] for c in client.get("/categories/", headers=h).json()}
    assert {"Food", "Transport", "Salary"} <= names


def test_account_crud(client):
    h = make_user(client)
    acc = make_account(client, h, opening=50000)
    assert acc["balance"] == 50000 and acc["opening_balance"] == 50000
    assert len(client.get("/accounts/", headers=h).json()) == 1

    r = client.put(f"/accounts/{acc['account_id']}", headers=h, json={"account_name": "Renamed"})
    assert r.status_code == 200 and r.json()["account_name"] == "Renamed"

    assert client.delete(f"/accounts/{acc['account_id']}", headers=h).status_code == 200
    assert client.get(f"/accounts/{acc['account_id']}", headers=h).status_code == 404


def test_account_rejects_negative_opening_balance(client):
    h = make_user(client)
    r = client.post(
        "/accounts/", headers=h,
        json={"provider": "MTN", "phone_number": "0771234567", "account_name": "x", "opening_balance": -5},
    )
    assert r.status_code == 422


def test_category_crud_and_duplicate_name(client):
    h = make_user(client)
    r = client.post("/categories/", headers=h, json={"name": "Gifts", "icon": "card_giftcard"})
    assert r.status_code == 201
    cid = r.json()["category_id"]
    assert client.post("/categories/", headers=h, json={"name": "gifts"}).status_code == 400
    assert client.put(f"/categories/{cid}", headers=h, json={"name": "Presents"}).json()["name"] == "Presents"
    assert client.delete(f"/categories/{cid}", headers=h).status_code == 200


# ---------- transactions and balances ----------
def test_income_and_expense_change_balance(client):
    h = make_user(client)
    acc = make_account(client, h, opening=100000)
    r = add_tx(client, h, acc["account_id"], category_id(client, h, "Transport"), "Expense", 15000, "Taxi")
    assert r.status_code == 201
    assert r.json()["category_name"] == "Transport"
    assert balance(client, h, acc["account_id"]) == 85000

    add_tx(client, h, acc["account_id"], category_id(client, h, "Salary"), "Income", 50000)
    assert balance(client, h, acc["account_id"]) == 135000


def test_overdraft_is_rejected_and_balance_unchanged(client):
    h = make_user(client)
    acc = make_account(client, h, opening=1000)
    r = add_tx(client, h, acc["account_id"], category_id(client, h), "Expense", 5000)
    assert r.status_code == 400
    assert balance(client, h, acc["account_id"]) == 1000
    assert client.get("/transactions/", headers=h).json() == []


def test_invalid_amounts_and_types_give_422(client):
    h = make_user(client)
    acc = make_account(client, h)
    cid = category_id(client, h)
    assert add_tx(client, h, acc["account_id"], cid, "Expense", 0).status_code == 422
    assert add_tx(client, h, acc["account_id"], cid, "Expense", -10).status_code == 422
    assert add_tx(client, h, acc["account_id"], cid, "Gift", 10).status_code == 422


def test_edit_transaction_keeps_balance_consistent(client):
    h = make_user(client)
    acc = make_account(client, h, opening=100000)
    cid = category_id(client, h)
    tx = add_tx(client, h, acc["account_id"], cid, "Expense", 15000).json()
    assert balance(client, h, acc["account_id"]) == 85000

    r = client.put(f"/transactions/{tx['transaction_id']}", headers=h, json={"amount": 20000})
    assert r.status_code == 200 and r.json()["amount"] == 20000
    assert balance(client, h, acc["account_id"]) == 80000

    client.put(f"/transactions/{tx['transaction_id']}", headers=h, json={"type": "Income"})
    assert balance(client, h, acc["account_id"]) == 120000  # 100000 + 20000


def test_edit_can_move_transaction_to_another_account(client):
    h = make_user(client)
    a1 = make_account(client, h, opening=100000, name="A1")
    a2 = make_account(client, h, opening=50000, name="A2")
    tx = add_tx(client, h, a1["account_id"], category_id(client, h), "Expense", 30000).json()
    r = client.put(f"/transactions/{tx['transaction_id']}", headers=h, json={"account_id": a2["account_id"]})
    assert r.status_code == 200
    assert balance(client, h, a1["account_id"]) == 100000  # old account refunded
    assert balance(client, h, a2["account_id"]) == 20000   # new account charged


def test_edit_that_would_overdraw_is_rejected(client):
    h = make_user(client)
    a1 = make_account(client, h, opening=100000, name="A1")
    a2 = make_account(client, h, opening=10000, name="A2")
    tx = add_tx(client, h, a1["account_id"], category_id(client, h), "Expense", 30000).json()
    r = client.put(f"/transactions/{tx['transaction_id']}", headers=h, json={"account_id": a2["account_id"]})
    assert r.status_code == 400
    assert balance(client, h, a1["account_id"]) == 70000  # nothing changed
    assert balance(client, h, a2["account_id"]) == 10000


def test_delete_transaction_reverses_balance(client):
    h = make_user(client)
    acc = make_account(client, h, opening=100000)
    tx = add_tx(client, h, acc["account_id"], category_id(client, h), "Expense", 15000).json()
    assert client.delete(f"/transactions/{tx['transaction_id']}", headers=h).status_code == 200
    assert balance(client, h, acc["account_id"]) == 100000
    assert client.get(f"/transactions/{tx['transaction_id']}", headers=h).status_code == 404


def test_cannot_delete_account_or_category_in_use(client):
    h = make_user(client)
    acc = make_account(client, h)
    cid = category_id(client, h)
    add_tx(client, h, acc["account_id"], cid, "Expense", 100)
    assert client.delete(f"/accounts/{acc['account_id']}", headers=h).status_code == 400
    assert client.delete(f"/categories/{cid}", headers=h).status_code == 400


def test_transaction_filters(client):
    h = make_user(client)
    acc = make_account(client, h)
    add_tx(client, h, acc["account_id"], category_id(client, h, "Food"), "Expense", 500, "Lunch rolex")
    add_tx(client, h, acc["account_id"], category_id(client, h, "Salary"), "Income", 9000, "Pay day")
    assert len(client.get("/transactions/?type=Income", headers=h).json()) == 1
    assert len(client.get("/transactions/?search=rolex", headers=h).json()) == 1
    assert len(client.get("/transactions/", headers=h).json()) == 2


# ---------- one user must never touch another user's data ----------
def test_users_cannot_access_each_others_data(client):
    h1 = make_user(client, 1)
    h2 = make_user(client, 2)
    acc1 = make_account(client, h1)
    cat1 = category_id(client, h1)
    tx1 = add_tx(client, h1, acc1["account_id"], cat1, "Expense", 100).json()

    # reading / editing / deleting -> 404 (does not even reveal the record exists)
    assert client.get(f"/accounts/{acc1['account_id']}", headers=h2).status_code == 404
    assert client.put(f"/accounts/{acc1['account_id']}", headers=h2, json={"account_name": "hack"}).status_code == 404
    assert client.delete(f"/accounts/{acc1['account_id']}", headers=h2).status_code == 404
    assert client.get(f"/categories/{cat1}", headers=h2).status_code == 404
    assert client.get(f"/transactions/{tx1['transaction_id']}", headers=h2).status_code == 404
    assert client.put(f"/transactions/{tx1['transaction_id']}", headers=h2, json={"amount": 1}).status_code == 404
    assert client.delete(f"/transactions/{tx1['transaction_id']}", headers=h2).status_code == 404

    # lists are empty for the other user
    assert client.get("/accounts/", headers=h2).json() == []
    assert client.get("/transactions/", headers=h2).json() == []

    # user 2 cannot attach a transaction to user 1's account or category
    acc2 = make_account(client, h2)
    cat2 = category_id(client, h2)
    assert add_tx(client, h2, acc1["account_id"], cat2, "Income", 100).status_code == 404
    assert add_tx(client, h2, acc2["account_id"], cat1, "Income", 100).status_code == 404

    # user 1's balance was never touched
    assert balance(client, h1, acc1["account_id"]) == 99900
