# Mobile Money Wallet API: Endpoint Documentation

Interactive docs (Swagger) are served by the running server at `http://127.0.0.1:8000/docs`.

**Base URL:** `http://127.0.0.1:8000` (computer / browser), `http://10.0.2.2:8000` (Android emulator), `http://<your-LAN-IP>:8000` (physical phone).

**Always include the trailing slash** on collection URLs (`/accounts/`, `/categories/`, `/transactions/`). Without it FastAPI answers with a redirect that Dart's `http` package does not follow for POST requests.

**Authentication:** every endpoint except `/`, `/health`, `/auth/register`, `/auth/login` and `/auth/token` needs the header
`Authorization: Bearer <access_token>`. Tokens expire after `ACCESS_TOKEN_EXPIRE_MINUTES` (default 60). Logging out = the app deletes its stored token.

**Format:** JSON in, JSON out. Money values are JSON numbers (UGX, 2 decimals). Dates are ISO 8601 (`2026-11-05T14:30:00`) in server time.

## Endpoint table

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/` | no | Server is running |
| GET | `/health` | no | Server + database check |
| POST | `/auth/register` | no | Register a new user |
| POST | `/auth/login` | no | Log in (JSON), returns token |
| POST | `/auth/token` | no | Log in (form data, used by Swagger "Authorize") |
| GET | `/auth/me` | yes | Current user's details |
| POST | `/accounts/` | yes | Create an account |
| GET | `/accounts/` | yes | List my accounts |
| GET | `/accounts/{account_id}` | yes | Get one account |
| PUT | `/accounts/{account_id}` | yes | Update an account |
| DELETE | `/accounts/{account_id}` | yes | Delete an account (only if it has no transactions) |
| POST | `/categories/` | yes | Create a category |
| GET | `/categories/` | yes | List my categories |
| GET | `/categories/{category_id}` | yes | Get one category |
| PUT | `/categories/{category_id}` | yes | Update a category |
| DELETE | `/categories/{category_id}` | yes | Delete a category (only if unused) |
| POST | `/transactions/` | yes | Record income or an expense, updates balance |
| GET | `/transactions/` | yes | List my transactions (filters below) |
| GET | `/transactions/{transaction_id}` | yes | Get one transaction |
| PUT | `/transactions/{transaction_id}` | yes | Edit a transaction, balance adjusted |
| DELETE | `/transactions/{transaction_id}` | yes | Delete a transaction, balance reversed |

## Authentication

### POST /auth/register
Request:
```json
{ "full_name": "Amina Kato", "phone_number": "0771234567", "email": "amina@example.com", "password": "Secret123" }
```
Rules: name 2-100 chars; phone 9-14 digits (optional leading `+`); valid email; password 8-72 chars with at least one letter and one digit.
Success **201**:
```json
{ "user_id": 1, "full_name": "Amina Kato", "phone_number": "0771234567", "email": "amina@example.com", "created_at": "2026-11-05T10:00:00" }
```
Errors: **400** email or phone already registered; **422** invalid data.
Seven default categories (Food, Transport, Rent, Airtime, Shopping, Salary, Business income) are created for every new user.

### POST /auth/login
Request: `{ "email": "amina@example.com", "password": "Secret123" }`
Success **200**:
```json
{ "access_token": "eyJhbGciOi...", "token_type": "bearer", "user": { "user_id": 1, "full_name": "Amina Kato", "phone_number": "0771234567", "email": "amina@example.com", "created_at": "..." } }
```
Errors: **401** incorrect email or password; **422** invalid data.

### GET /auth/me
Success **200**: the user object above. Errors: **401** missing/invalid/expired token.

## Accounts

Account object:
```json
{ "account_id": 1, "provider": "MTN", "phone_number": "0771234567", "account_name": "My MTN Wallet",
  "balance": 85000.0, "opening_balance": 100000.0, "created_at": "2026-11-05T10:05:00" }
```
`balance` is maintained by the server; it can only change through transactions (or by editing `opening_balance`).

| Endpoint | Request body | Success | Errors |
|---|---|---|---|
| POST `/accounts/` | `{ "provider": "MTN", "phone_number": "0771234567", "account_name": "My MTN Wallet", "opening_balance": 100000 }` (`opening_balance` optional, >= 0) | 201 account | 401, 422 |
| GET `/accounts/` | none | 200 list of accounts | 401 |
| GET `/accounts/{id}` | none | 200 account | 401, 404 |
| PUT `/accounts/{id}` | any of `provider`, `phone_number`, `account_name`, `opening_balance` | 200 account | 400 (balance would go negative), 401, 404, 422 |
| DELETE `/accounts/{id}` | none | 200 `{ "message": "Account deleted" }` | 400 (account has transactions), 401, 404 |

## Categories

Category object: `{ "category_id": 2, "name": "Transport", "icon": "directions_bus", "created_at": "..." }`

| Endpoint | Request body | Success | Errors |
|---|---|---|---|
| POST `/categories/` | `{ "name": "Gifts", "icon": "card_giftcard" }` (`icon` optional) | 201 category | 400 (duplicate name), 401, 422 |
| GET `/categories/` | none | 200 list (sorted by name) | 401 |
| GET `/categories/{id}` | none | 200 category | 401, 404 |
| PUT `/categories/{id}` | `name` and/or `icon` | 200 category | 400 (duplicate name), 401, 404, 422 |
| DELETE `/categories/{id}` | none | 200 `{ "message": "Category deleted" }` | 400 (used by transactions), 401, 404 |

## Transactions

Transaction object:
```json
{ "transaction_id": 5, "account_id": 1, "category_id": 2, "type": "Expense", "amount": 15000.0,
  "description": "Taxi to town", "transaction_date": "2026-11-05T14:30:00", "created_at": "2026-11-05T14:30:01",
  "account_name": "My MTN Wallet", "category_name": "Transport" }
```

| Endpoint | Request body | Success | Errors |
|---|---|---|---|
| POST `/transactions/` | `{ "account_id": 1, "category_id": 2, "type": "Expense", "amount": 15000, "description": "Taxi", "transaction_date": "2026-11-05T14:30:00" }` (`description` and `transaction_date` optional; `type` is `Income` or `Expense`; `amount` > 0) | 201 transaction | 400 (insufficient balance), 401, 404 (account/category not yours), 422 |
| GET `/transactions/` | none | 200 list, newest first | 401 |
| GET `/transactions/{id}` | none | 200 transaction | 401, 404 |
| PUT `/transactions/{id}` | any of `account_id`, `category_id`, `type`, `amount`, `description`, `transaction_date` | 200 transaction | 400, 401, 404, 422 |
| DELETE `/transactions/{id}` | none | 200 `{ "message": "Transaction deleted and balance updated" }` | 400 (reversal would make a balance negative), 401, 404 |

**List filters** (query string, all optional): `account_id`, `category_id`, `type=Income|Expense`, `search=text` (in description), `skip` (default 0), `limit` (default 100, max 500).

**Balance rules:** Income adds to the account balance, Expense subtracts. Editing reverses the old effect then applies the new one (also when the account changes). Deleting reverses the effect. Each operation is atomic. A balance can never go below 0.

## Status codes used

| Code | Meaning in this API |
|---|---|
| 200 | Request succeeded (read, update, delete) |
| 201 | Record created |
| 400 | Business rule broken (duplicate email, insufficient balance, deleting something in use) |
| 401 | Missing, invalid or expired token; wrong login |
| 404 | Record does not exist **or belongs to another user** |
| 422 | Request data failed validation (FastAPI/Pydantic) |
| 500 / 503 | Unexpected database error / database unreachable (generic message only) |
