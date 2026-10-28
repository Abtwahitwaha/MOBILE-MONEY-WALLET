# Mobile Money Wallet: Backend (FastAPI + MySQL)

REST API for the Mobile Money Wallet app: users, mobile money accounts, categories and transactions, with JWT login.

## 1. Required software
Python 3.10+, MySQL Server 8 + MySQL Workbench, Git, VS Code. Postman is optional (Swagger works too).

## 2. Create the virtual environment
Open a terminal in the `backend/` folder.
```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1        # PowerShell
# venv\Scripts\activate            # Command Prompt
```
macOS/Linux: `source venv/bin/activate`

## 3. Install dependencies
```
pip install -r requirements.txt
```

## 4. Create the database
In MySQL Workbench open `schema.sql`, run the whole file (lightning-bolt button). This creates the database `mobile_money_wallet` and its 4 tables.

## 5. Configure `.env`
Copy `.env.example` to `.env` and fill in your MySQL username/password. Generate the secret key:
```
python -c "import secrets; print(secrets.token_hex(32))"
```
Paste the output as `SECRET_KEY`. Never commit `.env`.

## 6. Start the server
```
uvicorn main:app --reload
```
For a physical phone on the same Wi-Fi: `uvicorn main:app --host 0.0.0.0 --port 8000`

## 7. Open the API documentation
- Health: http://127.0.0.1:8000/health
- Swagger: http://127.0.0.1:8000/docs (use **Authorize**, put your email in *username*)

Full endpoint table: `../docs/api_documentation.md`

## 8. Run the tests
```
pytest -v
```
The tests use a temporary SQLite file (`test_wallet.db`), so your MySQL data is never touched.

## Project layout
| File | Job |
|---|---|
| `main.py` | creates the app, CORS, error handlers, includes the routers |
| `database.py` | reads `.env`, engine, one session per request |
| `models.py` | the 4 tables as Python classes |
| `schemas.py` | validation of what comes in and goes out |
| `auth.py` | bcrypt hashing, JWT creation/checking, `CurrentUser` |
| `routers/users.py` | `/auth/register`, `/auth/login`, `/auth/me` |
| `routers/accounts.py`, `categories.py`, `transactions.py` | CRUD endpoints |

## Demo cheat sheet (Task 7.3)
- **Why a backend?** The phone must not talk to the database directly. The server holds the data, enforces rules and keeps users apart.
- **FastAPI <-> MySQL:** SQLAlchemy models map classes to tables; each request gets a session (`get_db`), queries run through it, `commit()` saves.
- **Tables:** `users` 1:N `accounts`, `categories`, `transactions`; each transaction points to one account and one category.
- **Register/login:** register validates, hashes the password with bcrypt and saves; login checks the hash and returns a signed JWT.
- **Why hash?** If the database leaks, passwords can't be read. bcrypt is salted and slow on purpose.
- **JWT protection:** the app sends `Authorization: Bearer <token>`; `get_current_user` verifies signature + expiry or answers 401.
- **Balance:** income adds, expense subtracts; edit reverses old then applies new; delete reverses; all in one commit.
- **Isolation:** the owner comes from the token and every query filters `user_id`; other users' records give 404.
- **Testing:** `pytest` suite + manual Swagger/Postman checks.
