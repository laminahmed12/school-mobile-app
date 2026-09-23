# School Management Flutter App

Offline-first Flutter mobile/PWA starter for the localized school-management system.

## 1. Create the native Android/web folders

This repository intentionally keeps generated Flutter platform boilerplate out of the source package.

Run:

```bash
flutter create .
```

Then:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## 2. API URL

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-NESTJS-DOMAIN/api
```

For production:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-NESTJS-DOMAIN/api
```

## 3. GitHub Actions

Workflow:

`.github/workflows/build-apk.yml`

Add a repository secret:

`API_BASE_URL`

Every push to `main`, or manual workflow execution, builds and uploads the APK as a GitHub Actions artifact.

## Important production tasks

Before real deployment:

- Replace the demo authentication fallback in `SchoolRepository`.
- Add secure token storage and refresh-token rotation.
- Add certificate/transport security according to the deployment threat model.
- Add NestJS DTO validation and role-based authorization.
- Add a proper sync outbox with idempotency keys and server conflict resolution.
- Add encrypted local storage for sensitive records.
- Add PDF file saving/sharing implementation.
- Add FCM, WhatsApp notification worker, attendance/grades endpoints.
- Configure Android release signing; never commit a keystore or passwords.
