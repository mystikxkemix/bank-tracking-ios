# Comptes (Bank tracking iOS)

Read-only iPhone app for [Bank tracking](https://github.com/mystikxkemix/bank-tracking): dashboard,
transactions, budgets and goals, household split. Editing (imports, categories, budgets) stays on the website.

## Requirements
- Xcode 26+, iOS 17+.
- The Bank tracking server reachable over **HTTPS** (reverse proxy with a real certificate).
  Plain HTTP only works for local dev addresses (`localhost`, `.local` names).

## Build
```sh
xcodegen generate            # the .xcodeproj is generated from project.yml
open BankTracking.xcodeproj
```

Signing for a device: create `Config/Signing.local.xcconfig` (git-ignored) with
`DEVELOPMENT_TEAM = <team id>`. Find the id in the `OU=` of your Apple Development certificate
or in Xcode > Settings > Accounts.

Tests:
```sh
xcodebuild -project BankTracking.xcodeproj -scheme BankTracking \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Widget
"Épargne du mois" (home screen small, lock screen rectangular): savings of the current month and what is
left of the budgets. It calls the API itself every hour with the session shared by the app, and shows the
last known figures (clock icon) when the server is unreachable. Amounts are hidden while the phone is locked.

## How it talks to the server
- Same API as the web app (`/api/...`), JSON shapes copied from `packages/shared/src/schemas` into `BankTracking/API/Models.swift`.
- Login with email + password; the session is the `bt_session` cookie, kept by `HTTPCookieStorage` across launches.
- Money is integer cents everywhere, formatted with `Money.format` (Decimal, never Double).

## Debug launch (simulator screenshots)
Debug builds read these environment variables, release builds ignore them:

| Variable | Effect |
|---|---|
| `BT_SERVER`, `BT_EMAIL`, `BT_PASSWORD` | log in automatically (also disables the Face ID lock) |
| `BT_TAB` | `dashboard`, `transactions`, `budgets`, `split`, `settings` |
| `BT_SEGMENT` | `goals` to open the goals list |
| `BT_SPACE` | space name to open, e.g. `Foyer` |
| `BT_MONTH` | month to open, `YYYY-MM` |
| `BT_WIDGET` | `1` shows a screen that runs the widget loader and draws the widget |

```sh
SIMCTL_CHILD_BT_SERVER=http://localhost:8095 SIMCTL_CHILD_BT_EMAIL=alex@demo.local \
SIMCTL_CHILD_BT_PASSWORD=demo-password SIMCTL_CHILD_BT_SPACE=Foyer \
xcrun simctl launch booted io.github.mystikxkemix.banktracking
```
