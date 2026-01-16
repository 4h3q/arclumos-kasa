ARCLUMOS Kasa (Flutter, Offline)

- App name: ARCLUMOS Kasa
- Default cash account: ARCLUMOS TL (TRY)
- Storage: SQLite (device local)
- Menus: Gider / Gelir / Kasa
- Filters: date range, type, account, category, search, sort
- Exports: PDF + Excel (.xlsx) + CSV (Downloads)

Build APK via GitHub Actions:
- Repo root must contain this project
- Workflow: .github/workflows/build_apk.yml
- Actions -> Run workflow -> Artifacts -> app-debug.apk.zip

Local run:
- flutter pub get
- flutter run
