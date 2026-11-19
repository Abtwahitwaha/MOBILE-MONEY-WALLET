# Mobile Money Wallet: Flutter app

Blue theme (colours from the XD design). Green and red are used only to tell income from expenses;
MTN cards are yellow and Airtel cards are red.

## Screens
| Area | Screens |
|---|---|
| Start | Splash, Onboarding (first launch), Login, Register, Forgot password |
| Tabs (bottom bar) | Home, Income, Expenses, Accounts, Profile |
| From Home | Add income, Add expense, History, Insights (tracking by day), Transaction details / edit |

Details and the endpoints each screen uses: `../docs/app_screens.md`.

## Features
- **Separate Income and Expenses** tabs and separate Add income / Add expense screens.
- **Swipe left** on a transaction to delete it (with confirmation; the balance is corrected by the server).
- **"Other" category** for anything not listed (a description is required when it is used).
- **Pop-up notification** after every transaction is recorded, edited or deleted, showing the new balance.
- **Security PIN (local):** every expense must be approved with a 4-digit PIN. The PIN is stored on the phone only
  (salted SHA-256 hash), is locked for 30 seconds after 3 wrong tries, and can be reset with the account password.
- **Profile photo:** kept on the phone only, never uploaded and not in the database.
- **Accounts:** MTN and Airtel branded cards. There is no initial deposit; accounts start at UGX 0 and money is added by recording income.
- **Forgot password:** the server prints a 6-digit code in its console (no SMS/email service in this project).

## First-time setup (once)
```powershell
cd app
flutter create --project-name mobile_money_wallet --org com.capstone .
del test\widget_test.dart
flutter pub get
```
Then edit `android\app\src\main\AndroidManifest.xml`:
1. Add `<uses-permission android:name="android.permission.INTERNET"/>` above `<application`.
2. Add `android:usesCleartextTraffic="true"` inside the `<application ...>` tag.

## Run (physical phone, USB, mirrored with scrcpy)
1. Backend (in `backend/`, venv active): `uvicorn main:app --reload`
2. `adb reverse tcp:8000 tcp:8000`
3. In `app/`: `flutter run`   (and `scrcpy` to mirror the phone)

The server address is at the top of `lib/services/api_service.dart` (`serverUrlOverride`).

## Official provider logos (optional)
Put `mtn.png` and `airtel.png` in `assets/images/providers/`. The app uses them automatically;
without them it draws yellow (MTN) and red (Airtel) badges.

## Folder layout
`lib/theme` (colours, spacing, text, theme), `lib/models`, `lib/services` (API, PIN, photo), `lib/utils`,
`lib/widgets` (reusable pieces), `lib/screens/<feature>`.
