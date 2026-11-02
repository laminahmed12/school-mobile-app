# Lamīn School — Canonical Project Context

## Project identity
- This repository is **Lamīn School**: `laminahmed12/school-mobile-app`.
- Backend: **Supabase**.
- This is NOT Lamīn Management, which is a separate Firebase project. Never mix their code, credentials, deployments, or requirements.
- Active working branch: `fix/lamin-portal-crud-offline-20261030`.
- Active pull request: #22 — https://github.com/laminahmed12/school-mobile-app/pull/22
- PR is currently **open and unmerged**. Keep it that way unless the user explicitly authorizes a merge.
- Latest branch HEAD checked while updating this file: `d52e0c3b19b2be0eaed02e9f410d6f785569abc1`.
- Current app version in `pubspec.yaml`: `2.0.3+14`. This is a source/build target, NOT evidence that a 2.0.3+14 APK has passed CI or has been signed.

## Critical existing signed release — preserve this signing identity
A real signed APK already exists and was verified previously. Do not restart signing setup or create a replacement keystore.
- Existing signed reference APK: `lamin-school-2.0.3-13-v1-v2-v3-signed.apk`.
- Version: `2.0.3+13`.
- Package: `com.adreemk.school.lamin_school`.
- APK SHA-256: `f0d4dc99410bcd741386ecd69da040f72bbe16754ba82af00f0af744ac97f7da`.
- Android signing schemes V1, V2, and V3 were enabled and independently checked for their applicable API ranges.
- Signing certificate SHA-256 fingerprint:
  `7B:9C:F1:1E:AF:AB:48:01:BE:68:21:D6:92:ED:AE:34:75:61:8F:CB:51:BE:21:86:B0:F5:86:6B:24:41:88:1A`.
- The certificate was verified to match the previous Lamin release certificate.
- The app minimum SDK is API 24; a V1 compatibility check at API 21–23 does not mean the app supports installation on those Android versions.
- V1 verification reported limited pre-existing META-INF metadata warnings; V2 and V3 whole-APK verification passed.
- For every new build, use the same release signing certificate and verify its fingerprint against the value above. Never change application ID or signing identity; a different certificate would prevent updating existing installations.
- Do not expose or request keystore bytes or passwords. Use configured GitHub Secrets / existing approved signing workflow.

## Current user-reported behavior (latest report)
The user confirmed:
1. Adding a student while offline now works.
2. Cold-start / reopening the app in airplane mode still does NOT reach the app successfully.
3. While the app is already open and connectivity is lost, operations can be queued and applied after connectivity returns.
4. Multiple operations can still show loading for more than 30 seconds.
5. Local backup behavior and offline storage had previously failed; cache-only local backup changes were added, but actual device restore/export acceptance is still outstanding.

Treat these as observed device reports. Do not claim offline login or overall performance is fixed until verified on a physical Android device.

## Changes currently present in the branch

### Authentication and cold startup
Files changed/added:
- `lib/main.dart`
- `lib/auth_service.dart`
- `lib/supabase_config.dart`
- `lib/offline_credentials.dart`

Current implementation includes:
- A secure offline credential verifier using PBKDF2/HMAC-SHA256 with random salt, stored in platform secure storage. The password itself is not saved as plaintext.
- Offline credential is scoped to user ID, school code, and username, and password input is verified before granting local access.
- Online successful login warms the cached profile/school and saves the offline verifier.
- Forced password change updates the offline verifier for the new password.
- Local verifier is deleted on logout.
- Supabase automatic access-token refresh is disabled during app initialization; session refresh is deferred until after cached UI is displayed and internet is detected.
- Remote login timeout was reduced from 20 seconds to 6 seconds, and network errors are classified.
- The offline credential is not available on a device until a successful online login with this newer code has stored it. A prior “Remember me” username value alone does not provide offline authentication.

Important unresolved point:
- The current source implementation has not yet been proven to permit a successful cold-start offline login on a physical device. Inspect the complete `AuthGate`, login form callback wiring, SecureStorage persistence, session restore behavior, biometric lock, license/trial checks, and local cache identity. Do not bypass password verification, licensing, school activation, or biometric protections.

### Offline-first dashboard and network latency
Files changed:
- `lib/main.dart`
- `lib/repository.dart`

Current implementation includes:
- Home screen reads the local encrypted cache first and makes remote refresh/background sync asynchronous.
- Dashboard reads were changed to run concurrently after resolving the school identity.
- Cached read paths exist for students, teachers, and finance totals.
- Server availability check has a short connectivity probe and memoized/in-flight check.
- A number of direct remote create/update operations have explicit 4–8 second timeouts.
- Student creation uses an idempotent RPC and queues local writes after network failure; the user confirmed this specific offline student-add behavior now works.

Remaining performance work:
- Audit all screen actions and repository methods, not only `addStudent`.
- Find requests still using Supabase defaults, sequential network calls, retry loops, or a connectivity probe before every action.
- Ensure each mutation either completes remotely within a bounded deadline or commits to the encrypted local queue immediately; never lose an operation and never duplicate it after retry.
- Avoid changing unrelated workflows. Preserve local IDs, idempotency keys, and reconciliation logic.
- Aim for local feedback within a few seconds, not 30–35 seconds.

### Offline queue UX / attendance / finance
Files changed:
- `lib/repository.dart`
- `lib/main.dart`

Current code includes:
- Structured offline sync result with synced count, pending count, failed operation type, and error detail.
- Home-screen pending count and retry action.
- Operation-specific failure message while retaining failed queue entries.
- Attendance reload after successful sync.
- Students without an attendance record show `غير مسجّل`, not `حاضر`.
- Late attendance passes `minutesLate` through to local/remote persistence.
- Finance student names are hidden until name search.
- Fee management also uses name search before selecting a student.

Preserve these behaviors and verify them in the build/tests and on device.

### Local backup and restore
Files changed:
- `lib/repository.dart`
- `lib/backup_service.dart`
- `lib/backup_view.dart`
- `test/backup_envelope_test.dart`

Current implementation includes:
- `exportCachedBackup()` builds a snapshot from encrypted device cache and pending offline operations without a Supabase export RPC.
- `restoreCachedSnapshot()` restores a local snapshot only after matching current user and school; it does not write to Supabase.
- `createLocalBackup()` uses the cache-only snapshot and writes an encrypted local backup.
- Local restore UI distinguishes cache-only restore from server-side merge/restore.

Scope warning:
- A cache-only backup contains what is actually present on that device at backup time; it is not a fresh full export of all server records.
- Verify cache-key filtering, inclusion of all required data types, school isolation, pending operations, encrypted-file read/write, and restore behavior on Android. Do not state the backup/restore flow is fully accepted before testing on the device.

## Last verified GitHub Actions state at branch HEAD
For HEAD `d52e0c3b19b2be0eaed02e9f410d6f785569abc1`:
- Lamin portal validation: SUCCESS — run 41362723136.
- Lamin RPC security ACL regression: SUCCESS — run 41362723208.
- Lamin schema baseline acceptance: SUCCESS — run 41362723127.
- Lamin development validation: FAILURE — run 41362723131.
- Exact blocking failure: `flutter analyze --no-pub --fatal-infos --fatal-warnings` reported:
  `warning • The value of the local variable 'cachedSchool' isn't used • lib/main.dart:270:29 • unused_local_variable`.
- `dart format lib test` ran successfully, and the subsequent format verification reported 0 changed files.
- Because static analysis failed, automated tests and all Android candidate build/package/upload steps were SKIPPED in that run.
- Run link: https://github.com/laminahmed12/school-mobile-app/actions/runs/41362723131

This is the last verified CI state recorded here. Re-check GitHub Actions for newer runs before using this status. Do not assume a later code change was tested unless the matching HEAD has completed CI.

## Build and signing workflow
- Release signing workflow: `.github/workflows/release-signed-apk.yml`.
- It is triggered manually via `workflow_dispatch`.
- Expected GitHub Secrets: `LAMIN_KEYSTORE_BASE64`, `LAMIN_KEYSTORE_PASSWORD`, `LAMIN_KEY_ALIAS`, `LAMIN_KEY_PASSWORD`.
- Repository variable: `GOOGLE_SERVER_CLIENT_ID`.
- Existing workflow uploads a signed APK artifact (currently named `lamin-signed-release-apk`); artifact upload is not the same as publishing a GitHub Release.
- Preserve the existing signing identity from the 2.0.3+13 verified signed APK. Do not create a new keystore.
- New candidate target is 2.0.3+14 or higher, according to the current branch `pubspec.yaml`. Confirm actual package name/version code from the built APK before signing.
- Verify V1/V2/V3 individually with `apksigner`, print/compare certificate SHA-256, verify ZIP integrity/alignment, and record APK SHA-256.
- Do not claim a 2.0.3+14 APK exists, is signed, or is releasable until its artifact was downloaded and inspected and all checks passed.

## Required next actions
1. Read this file again at the start of the next work session and re-check branch HEAD, PR #22, and current workflow runs.
2. Fix the unused `cachedSchool` analyzer warning in `lib/main.dart`; inspect why it remains in the current HEAD rather than applying a blind deletion that could remove needed license/trial checks.
3. Re-run dependency resolution, `dart format`, `flutter analyze --fatal-infos --fatal-warnings`, and `flutter test`. Continue until all pass.
4. Rebuild Android only from the resulting verified HEAD.
5. Investigate cold-start offline sign-in on physical Android: online warm-up, app force-close, airplane-mode start, correct password, wrong password, wrong school/user, expired/active licensing, biometric lock, and cached profile/school consistency.
6. Audit and shorten all remaining 30+ second remote operations without losing or duplicating local writes.
7. Verify cache-only backup creation and restore entirely offline and check school/user isolation.
8. Run a new Android release build with version code greater than 13.
9. Sign with the existing release certificate matching the reference fingerprint, verify V1/V2/V3 separately, and produce checksums/reports.
10. Keep PR #22 open and do not merge or touch `main`/production unless the user explicitly instructs otherwise.
11. Update this `PROJECT_CONTEXT.md` again with the exact verified HEAD, CI run IDs/results, APK filename/version/hash/certificate, and remaining device acceptance results.

## Working boundaries and safety
- Work only on Lamīn School in this repository and the specified task branch.
- Do not modify `main` or production unless explicitly instructed.
- Do not run migrations or destructive database operations against production Supabase.
- Never request, print, commit, or expose secrets, keystore passwords, or tokens.
- Do not change the release signing identity.
- Do not overwrite or delete existing customer data or backups.
- Preserve completed code and successful tests; avoid repeating successful work.
- Distinguish source changes, CI checks, APK signature verification, and real-device acceptance.

## User communication
- نفّذ مباشرة دون مقدمات وخطط مطولة.
- لا تطلب إعادة شرح معلومات موجودة في هذا الملف أو المحادثة.
- لا تذكر المشكلة وحدها؛ اربطها بالإجراء التنفيذي والحل.
- لا تدّع نجاح تعديل أو اختبار أو بناء دون تحقق فعلي.
- التقرير النهائي لا يتجاوز خمسة أسطر: ما عُدّل، الفحوصات الفعلية، حالة APK الموقع، وما بقي لتجربته على الهاتف.


---

## Session update — 2026-11-02

- Verified branch: `fix/lamin-portal-crud-offline-20261030`.
- Latest verified HEAD after this session's source update: `9030519fecb144f68b6a8d40aca3fef6ac293061`.
- PR #22 remains OPEN and UNMERGED; no change to `main`, production Supabase, or Firebase project.
- `pubspec.yaml` remains `2.0.3+14`.
- Removed only the unused local `cachedSchool` initialization/read from `AuthGate._refreshLock` in `lib/main.dart`; retained cached profile lookup, session fallback, password verification flow, school/license/trial checks in `_tryOfflineAccess`, and biometric lock logic.
- Commit: `9030519fecb144f68b6a8d40aca3fef6ac293061` — `fix(auth): remove unused startup school cache variable`.
- The previous failure is confirmed from logs: `flutter analyze --no-pub --fatal-infos --fatal-warnings` failed solely on unused `cachedSchool` at `lib/main.dart:270:29`; all later test and candidate-build steps were skipped.
- New CI runs were queued/started for HEAD `9030519...`: development validation `41396408072` (push) and `41396413815` (PR), portal validation `41396408033` / `41396413817`, RPC ACL `41396408268` / `41396413825`, schema `41396407992` / `41396413830`. At handover update time these were still running; no result is claimed here.
- Offline login code review: login form does call `onOfflineAccess` when network is absent; the local verifier is PBKDF2/HMAC-SHA256 and scoped to user ID, school code, and username. `_tryOfflineAccess` validates cached active profile, school active flag, license/trial end, password verifier, and then respects biometric lock. On cold-start with no Supabase session, identity comes from `lamin.offline.user.id`. This is code-path inspection only, not physical-device proof.
- Performance audit found a remaining 20-second timeout in offline payment replay, 15-second timeouts in student/attendance queue replay, and sequential payment/fee detail reads with 5–7 second timeouts. These were not modified during this session because the RPC replay/idempotency and financial workflow need targeted changes/tests; don't treat performance as fully resolved.
- Release workflow exists and consumes the four established GitHub Secrets without printing them. It does not expose a workflow_dispatch action through the current GitHub connector, so no signed release run was initiated in this session.
- No new signed APK or release ZIP was generated; no new certificate verification was performed. Preserve the established certificate SHA-256 fingerprint from this file's earlier section.
- Physical device validation remains required for cold-start airplane mode, incorrect password rejection, biometric lock, active/expired license behavior, offline queue replay, and backup restoration.
