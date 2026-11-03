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


---

# AUTHORITATIVE HANDOVER — 2026-11-02 (supersedes older status entries above)

This section is the current source of truth. Older HEADs, CI results, and release instructions elsewhere in this file are historical unless repeated here.

## A. Current repository state

- Repository: `laminahmed12/school-mobile-app`.
- Project: **Lamīn School / Supabase only**. Never switch to Lamīn Management / Firebase.
- Work branch: `fix/lamin-portal-crud-offline-20261030`.
- Verified branch HEAD: `bcc8d411a3228be0daf8bce32ac53272c10dbc50`.
- Pull request: #22, **OPEN / UNMERGED**:
  https://github.com/laminahmed12/school-mobile-app/pull/22
- PR base is `feature/lamin-desktop-portal-2026-10-29`; do not retarget, merge, close, or update `main) unless explicitly instructed.
- `pubspec.yaml` version: `2.0.3+14`.
- No production Supabase changes were made as part of this handover.

## B. Existing signed APK — mandatory reference; do not rebuild it

A genuinely signed and verified release APK already exists from the earlier session:

- File: `lamin-school-2.0.3-13-v1-v2-v3-signed.apk`.
- Version: `2.0.3+13`.
- Application ID: `com.adreemk.school.lamin_school`.
- APK SHA-256:
  `f0d4dc99410bcd741386ecd69da040f72bbe16754ba82af00f0af744ac97f7da`.
- Android signing schemes V1, V2 and V3 were enabled and verified for their applicable API ranges.
- Existing release certificate SHA-256 fingerprint:
  `7B:9C:F1:1E:AF:AB:48:01:BE:68:21:D6:92:ED:AE:34:75:61:8F:CB:51:BE:21:86:B0:F5:86:6B:24:41:88:1A`.
- This APK is the signing-identity reference only. It is NOT the build containing the current 2.0.3+14 source changes.
- Keep this file and certificate identity unchanged. Never generate a new keystore, never change the package ID, and never sign with a different certificate.
- Do not assume the old APK is available as a GitHub Release asset. It was generated and delivered in the prior ChatGPT conversation; its exact filename, version and hashes above are the durable reference.

## C. STRICT RELEASE HOLD — do not produce a newly signed APK yet

**The user explicitly ordered the signed release to be deferred until the current offline-login and performance defects are fixed and verified. This order is mandatory.**

Until the user-reported defects are resolved and the required physical-device acceptance has passed:

- Do NOT start `Build signed Lamin release APK`.
- Do NOT run signing commands against a new candidate.
- Do NOT create a GitHub Release or publish a signed APK.
- Do NOT upload any keystore, key password, store password, or signing material to GitHub.
- Do NOT ask the user to upload the existing key files again.
- Do NOT replace the existing signed 2.0.3+13 reference APK.
- Do NOT treat a debug-signed testing candidate as a commercial release.

The existing 2.0.3+13 signed APK is retained as the known-good signing reference. Once the defects below are fixed, CI is green, and the user/device tests pass, prepare the next version (2.0.3+15 or higher if 2.0.3+14 has already been handed out) using the SAME existing signing certificate. Do not sign earlier.

## D. Latest verified CI state for current HEAD bcc8d411...

### Successful development validation

Workflow: `.github/workflows/lamin-development-validation.yml`

Run:
https://github.com/laminahmed12/school-mobile-app/actions/runs/41396439617

Run ID: `41396439617`
HEAD: `bcc8d411a3228be0daf8bce32ac53272c10dbc50`
Conclusion: **SUCCESS**.

Verified successful steps included:
- Flutter dependency resolution.
- Dart formatting and formatting verification.
- Flutter static analysis with fatal infos/warnings.
- Automated Flutter tests.
- Android candidate build.
- Candidate APK signature and package/version identity checks.
- Candidate SHA-256 generation.
- Upload of APK candidate and signing toolchain artifacts.

The same HEAD also passed:
- Lamin portal validation — run `41396439644`.
- Lamin RPC security ACL regression — run `41396439638`.
- Lamin schema baseline acceptance — run `41396439620`.

These schema and RPC tests use disposable CI PostgreSQL/Supabase test databases; they do NOT authorize a production migration.

### Latest signed-workflow failure

Workflow: `.github/workflows/release-signed-apk.yml`

Run:
https://github.com/laminahmed12/school-mobile-app/actions/runs/41397885679

Run ID: `41397885679`
HEAD: `bcc8d411a3228be0daf8bce32ac53272c10dbc50`
Conclusion: **FAILURE at the initial secret-presence gate, before checkout, dependency resolution, build, or signing**.

The exact log reports:
`Missing LAMIN_KEYSTORE_BASE64`.

The four secret environment variables were blank in that run:
- `LAMIN_KEYSTORE_BASE64`
- `LAMIN_KEYSTORE_PASSWORD`
- `LAMIN_KEY_ALIAS`
- `LAMIN_KEY_PASSWORD`

This is a missing GitHub Actions signing configuration, not a compile failure. Since signing is on hold, do not rerun this workflow now. When the release hold is lifted, use the existing signing identity and securely configured existing secret values; do not create or substitute a new key. Never print secret values into logs.

## E. How to build and obtain installable TEST APK artifacts (not release-signed)

This is the established, working development build path used in this repository. Use it for testing while the signed-release hold remains active.

### CI build method

On a commit pushed to the working branch / PR #22, GitHub Actions runs:
`.github/workflows/lamin-development-validation.yml`.

The workflow uses:
- Java 17.
- Flutter 3.35.4.
- `flutter pub get`.
- `dart format --output=none --set-exit-if-changed lib test`.
- `flutter analyze --fatal-infos --fatal-warnings`.
- `flutter test`.
- Android candidate build:
  `flutter build apk --release --no-tree-shake-icons --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID"`.
- Package/version verification using `aapt dump badging`.
- APK verification using `apksigner verify --verbose`.
- SHA-256 checksum generation.
- Artifact upload.

APK path inside the GitHub runner:
`build/app/outputs/flutter-apk/app-release.apk`.

The candidate workflow deliberately labels this output **debug-signed for testing**. It is a test-install artifact, not the final certificate-signed commercial release.

### Latest successful candidate artifacts

From successful run `41396439617` (HEAD bcc8d411...):

1. Artifact `lamin-development-candidate`
   - Artifact ID: `13120055855`.
   - Contains the built APK and candidate SHA-256 checksum.
   - Retention: 7 days from 2026-11-02; recorded expiration: 2026-11-09 05:59 UTC.
   - This is the artifact to download for testing.

2. Artifact `lamin-apksigner-toolchain`
   - Artifact ID: `13119319803`.
   - Contains Android signing tools only; it is NOT the APK.
   - Retention: 1 day from 2026-11-02; recorded expiration: 2026-11-03 05:59 UTC.
   - Do not download or use it for the user's phone test. It was a supporting toolchain for a prior local-signing path; the new signed release remains deferred.

### User-facing GitHub UI steps to obtain the test APK

1. Open:
   https://github.com/laminahmed12/school-mobile-app/actions/runs/41396439617
2. Scroll to the **Artifacts** section at the bottom of that run.
3. Download **`lamin-development-candidate`** (not `lamin-apksigner-toolchain`).
4. Extract the downloaded ZIP.
5. Locate `app-release.apk` inside the extracted folders.
6. The archive also contains `lamin-candidate-sha256.txt`; verify the APK checksum against it before installation.

Important Android installation warning:
- This CI candidate is debug-signed. Its signature is different from the existing commercial release certificate.
- Android will not install it as an in-place update over the existing release-signed 2.0.3+13 app.
- Do NOT uninstall the existing app merely to install the debug candidate; uninstalling could remove local school data.
- Test on a separate Android device or isolated test installation. If only one device is available, preserve the existing installation/data and wait for the properly signed release after the hold is lifted.

## F. Remaining user-reported defects — current work priorities

The user's latest confirmed observations:
1. Adding a student while offline now works. Preserve this working behavior.
2. Cold-start / reopening the app in airplane mode still does not complete offline login.
3. If the app is already open when internet is disconnected, it continues working and queues operations for sync after reconnection.
4. Operations still sometimes load for more than 30 seconds.
5. The user also showed a local backup failure that called Supabase RPC `export_backup` and failed DNS resolution; cache-only local backup/restore code was added, but physical-device acceptance remains outstanding.

Prior code changes already present and included in the successful development run:
- `lib/offline_credentials.dart`: PBKDF2/HMAC-SHA256 verifier with random salt in platform secure storage; password itself is not stored.
- `lib/main.dart` / `lib/auth_service.dart`: network-error classification, shorter login timeout, offline form callback, local identity/password verification, license/trial and biometric checks.
- `lib/supabase_config.dart`: automatic token refresh disabled at initial app startup, with refresh deferred until cached UI is shown and internet is detected.
- `lib/repository.dart`: cache-first reads, background sync, short connectivity probe, idempotent offline student creation, and several bounded write/read operations.
- `lib/backup_service.dart`, `lib/backup_view.dart`: cache-only encrypted local snapshot creation and local restore path.
- Attendance and finance changes: missing attendance record shows `غير مسجّل`; late minutes are passed through; pending operation counter/retry; hide finance names until search.
- The user confirmed offline student creation works. Do not re-open or regress that behavior.

### Required diagnosis and fixes

A. Cold-start offline login:
- Reproduce using a physical Android device after one successful online login with the current candidate build.
- Force-close the app, enable airplane mode, launch again, and verify account unlock.
- Check that `lamin.offline.user.id`, cached profile, school cache, and PBKDF2 verifier are all persisted and available after process restart.
- Ensure login form passes school code, username, and password to the offline verifier.
- Verify exact school/user binding, active profile, active school, paid license or unexpired trial, forced-password-change requirement, and biometric lock.
- Ensure `Supabase.initialize` does not block cold startup on token refresh/network access.
- Reject wrong password and wrong school/user. Never solve this by bypassing authentication, school license/trial, or device lock.
- The verifier is created only after successful online authentication with code that includes this feature. “Remember me” by itself is not sufficient.
- Do not claim offline login fixed until device test passes.

B. 30-second operations:
- Audit every screen action and every repository method, not only `addStudent`.
- Find Supabase calls using default timeouts, serial network requests, repeated connectivity probes, nested retries, or remote reads before local writes.
- Trace the full UI loading state from button press through repository/RPC and back.
- For offline mode, write to encrypted local storage/queue immediately and return promptly. Do not wait for an unreachable Supabase host to fail.
- For online writes, use a bounded request deadline. If the timeout is ambiguous after server commit, rely on stable idempotency keys/operation IDs before queuing/retrying; prevent duplicate students, fees, payments, attendance, and payroll entries.
- Preserve local IDs and remote-ID reconciliation.
- Target local feedback within a few seconds, not 30–35 seconds.
- Add or update automated tests for offline queueing, timeout fallback, idempotent replay, and no duplicate writes.

C. Offline backup:
- Local backup must not call `export_backup`, any Supabase RPC, or Google Drive.
- Read only the current device's encrypted cache and pending queue.
- Validate user ID and school ID on restore; do not cross-restore between schools.
- Clearly state that a cache-only backup contains only data already cached on the device, not a fresh complete export of server data.
- Test create/restore entirely in airplane mode on Android.

## G. Exact mandatory next-session instructions

When continuing in a new ChatGPT conversation:

1. Read this `PROJECT_CONTEXT.md` from the working branch before making changes.
2. Re-fetch actual branch HEAD and PR #22 state. Do not rely on the recorded HEAD if newer commits exist.
3. Re-check CI runs for the exact current HEAD. Current baseline at this handover is bcc8d411... and the successful run IDs listed above.
4. Work ONLY on `fix/lamin-portal-crud-offline-20261030`.
5. Preserve the successful offline student-add path.
6. Prioritize cold-start offline authentication and >30-second operation latency.
7. Add regression tests for each fix.
8. Run the full validation set:
   ```bash
   flutter pub get
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze --fatal-infos --fatal-warnings
   flutter test
   flutter build apk --release --no-tree-shake-icons --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID"
   ```
   The Android build above is for the development/testing candidate only; the GitHub Actions workflow is the authoritative build-and-artifact route.
9. Confirm the matching GitHub Actions run passes dependency resolution, formatting, analysis, tests, Android candidate build, package/version verification, signature verification, checksum, and artifact upload.
10. To obtain the candidate, use the GitHub Actions run's Artifacts section and download `lamin-development-candidate`; extract and locate `app-release.apk`. Never mistake the toolchain artifact for the APK.
11. Do not uninstall the existing signed app to install a differently signed debug candidate.
12. **HARD RELEASE HOLD:** do not run `release-signed-apk.yml`, do not sign any new APK, and do not publish a GitHub Release until cold-start offline login, fast operations, and cache-only backup have been fixed and accepted on a physical device.
13. Once the user/device acceptance gate is satisfied, and only then, use the existing signed-release workflow `.github/workflows/release-signed-apk.yml` with `workflow_dispatch` and `source_ref=fix/lamin-portal-crud-offline-20261030`. First verify configured GitHub Actions signing secrets are available without exposing their contents. The latest attempt failed because `LAMIN_KEYSTORE_BASE64` was empty. If the established signing identity cannot be used, stop; never generate a new keystore.
14. For the eventual commercial APK, use version code greater than 13, preserve application ID and certificate fingerprint, verify V1/V2/V3 individually with `apksigner`, verify the certificate fingerprint, APK ZIP integrity/alignment and SHA-256, and compare the result with the existing signed 2.0.3+13 reference.
15. Keep PR #22 open/unmerged and leave `main`, production Supabase, and the separate Firebase project untouched.
16. Update this file after every meaningful verified milestone. Record the exact HEAD, run IDs, CI conclusions, test results, APK filename/hash, and physical-device results. Do not write anticipated results as completed.

## H. User communication contract

- Execute directly; do not provide a long plan instead of work.
- Do not ask the user to repeat context already in this file.
- Do not ask for keystore files, passwords, tokens, or manual uploads.
- Do not describe a problem without its implemented fix or the exact blocker.
- Never claim a build, test, offline login, or signature passed unless the corresponding result was checked.
- Final report: maximum five lines, Arabic, only actual changes, checks run, signed-build hold status, and the one physical-device test needed next.


---

# EXECUTION UPDATE — 2026-11-02 (latest code; CI pending)

- Project remains Lamīn School (Supabase) only. Working branch `fix/lamin-portal-crud-offline-20261030`; PR #22 remains open and unmerged. No changes to `main`, production Supabase, or the separate Firebase app.
- Cold-start login now sequences restoration of saved school code, remembered username, cached user/profile/school, and PBKDF2 verifier metadata. It only pre-fills school and username; password remains blank and the existing PBKDF2 verify path, exact user/school match, active profile/school, valid license/trial, forced-password-change restriction, and biometric lock remain mandatory. Airplane mode is detected before any remote health probe.
- The credential store has a metadata-only `hasCredential` check bound to user ID, normalized school code, username, format version, and PBKDF2 parameters. It does not authenticate; `verify` remains the authority.
- Queue replay deadlines are bounded to six seconds for student create/update, fee lookup/update/insert, payment RPC, and attendance replay. Payment idempotency keys and operation IDs/local IDs/reconciliation are retained. Local writes skip the Supabase availability probe when no authenticated Supabase session exists.
- Financial summary fetches fee assessments, payments, and active academic year concurrently. Daily report and aggregate page reads are bounded to five seconds; academic-year rollover RPC to six seconds. Owner/admin function endpoints are capped at six seconds.
- Local cache backup creation remains cache-only and AES-GCM encrypted. Local restore and backup-file restore use `cachedSchool()`, not `school()`; restore still verifies current user and school IDs before writing local cache/queue.
- Added `test/offline_auth_preflight_test.dart` for password gating, school/license eligibility, and wrong-password denial.
- CI run `41411751548` on HEAD `5475db4de639a19333350466aa88da047d852f65` failed static analysis because an unused connectivity helper remained and a nullable profile access was still present. Formatting passed; downstream test and build steps were skipped. Both analyzer findings were corrected in later commits.
- Subsequent changes: `75d80f784c19b289286a89b8109c261063b1a059` removes the unused helper and caps PBKDF2 credential persistence at six seconds; `cce4b64d595a2334482dbe3b566977e74bb55e2c` makes the profile null guard explicit. Refresh actual HEAD and CI before reporting validation.
- Keep signed-release hold. Existing commercial signed 2.0.3+13 reference, certificate, and SHA256 remain unchanged. Do not run `release-signed-apk.yml`, generate a keystore, or publish a release until CI is green and cold-start offline login, slow operations, local backup/restore, and biometric lock have passed on a physical Android device.


---

# HANDOVER UPDATE — 2026-11-03

- Continue only from the current actual HEAD on `fix/lamin-portal-crud-offline-20261030`; refresh branch HEAD, PR #22, and CI before edits. Keep PR open/unmerged; do not touch `main`, production Supabase, or Lamīn Management/Firebase.
- User requests continuation from this exact repository branch and this reference file, not a restart. An earlier signed APK exists: `lamin-school-2.0.3-13-v1-v2-v3-signed.apk`; its signing identity and hashes are recorded above. It is a signing reference, not the current candidate.
- User asks for an offline-login device-ID gate: when entering offline, require the device identifier to match the device previously registered/authorized for that user/school. Implement this as an additional device-binding check alongside—not instead of—the password verifier, school/user match, active school/profile, license/trial, forced-password-change, and biometric checks. Do not use a publicly guessable Android ID as a secret; use a stable app-scoped installation/device key stored securely, persist its binding only after authenticated online enrollment, and fail closed if missing/mismatched. Define a safe online re-enrollment/recovery path; do not lock out existing customers without an explicit migration plan. Never log or expose the identifier. Add tests for matching ID, mismatch, missing binding, wrong password, and school/user mismatch.
- User asks whether APK building can start from this chat, branch, and reference file. Use the repository's existing CI candidate build workflow for a test APK after code changes and CI pass; retrieve the actual artifact and verify its SHA. Do not claim the artifact is available until checked. Commercial signing remains on hold until the documented offline login, latency, and backup/restore acceptance gates pass. Preserve the old signed APK and certificate; do not generate a new keystore.
- Current unresolved work remains cold-start airplane-mode login, >30-second operations, and fully offline cache backup/restore acceptance. Preserve working offline student creation and idempotent queue reconciliation.
- Before handoff, update this file with actual HEAD, CI run conclusions, candidate artifact location/hash, and tests truly run. No unverified status may be written as complete.
