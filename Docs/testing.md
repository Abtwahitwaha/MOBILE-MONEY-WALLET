BY NALWANGA SHADIA

# Testing

## Environment
| Item | Value |
|---|---|
| Backend | FastAPI on the backend lead's PC, MySQL 8, port 8000 |
| Phones | Android phones with the release APK, on the same Wi-Fi or hotspot as the PC |
| Date tested | ____ November 2026 |

## 1. Automated API tests (backend)
Run in `backend/` with the virtual environment active: `pytest -v` (uses a temporary SQLite file, never the MySQL data).

| Area | What is checked | Tests |
|---|---|---|
| Authentication | register, duplicate email/phone, validation (422), wrong password, token on every protected endpoint, password stored as bcrypt hash, hash never returned | 8 |
| Accounts and categories | CRUD, negative values rejected, duplicate category names, defaults created on register | 4 |
| Transactions and balances | income adds, expense subtracts, overdraft rejected, edit and delete keep the balance correct, moving a transaction between accounts, filters | 8 |
| Data isolation | another user gets 404 for read, edit and delete and cannot use another user's account or category | 1 |
| Password reset | same answer for unknown email, full flow, code works once, lock after 5 wrong tries, expiry, validation | 6 |
| Other | root and `/docs` open, delete blocked when an account or category is in use | 2 |

**Result:** ____ passed, ____ failed (total 29).

## 2. Manual integration tests (app + backend)
Tick the box when the expected result happens on the phone.

| # | Test | Expected result | Pass |
|---|---|---|---|
| 1 | Register with valid details | Account created, Home opens | &#9744; |
| 2 | Register with an existing email | Error message, no account | &#9744; |
| 3 | Log in with a wrong password | "Incorrect email or password" | &#9744; |
| 4 | Log in with the right details | Home opens | &#9744; |
| 5 | Add an MTN and an Airtel account | Yellow and red cards, balance UGX 0 | &#9744; |
| 6 | Add income of UGX 100,000 | Balance 100,000, pop-up message shown | &#9744; |
| 7 | Add an expense | PIN asked, wrong PIN refused, right PIN saves, balance drops | &#9744; |
| 8 | Add an expense bigger than the balance | Refused with a clear message | &#9744; |
| 9 | Edit a transaction amount | Balance changes by the difference | &#9744; |
| 10 | Swipe a transaction left and confirm | Removed, balance corrected | &#9744; |
| 11 | Delete an account that has transactions | Refused | &#9744; |
| 12 | Choose "Other" without a description | Asked to describe it | &#9744; |
| 13 | Check Income and Expenses tabs | Each shows only its own type, different colours | &#9744; |
| 14 | History filters, search, Insights | Totals match the transactions | &#9744; |
| 15 | Log in on a second phone with another user | Sees none of the first user's data | &#9744; |
| 16 | Two phones use the same PC backend | Both work at the same time | &#9744; |
| 17 | Switch the server off, open a screen | Error message with Try again, no crash | &#9744; |
| 18 | Switch the server on, tap Try again | Data loads | &#9744; |
| 19 | Forgot password with the code from `backend/server.log` | New password works, old one fails | &#9744; |
| 20 | Log out, close and reopen the app | Login screen (token cleared) | &#9744; |

## 3. Known limitations
No OTP, transfers between users or bill payments; reset codes appear in the server log because there is no SMS or email service; traffic is plain HTTP on the local network; the server works only while the host PC is on.
