# Lamīn School — Canonical Project Context

## Project identity
- This repository is **Lamīn School**: `laminahmed12/school-mobile-app`.
- Backend: **Supabase**.
- This is NOT Lamīn Management, which is a separate Firebase project. Never mix their code, credentials, deployments, or requirements.
- Active working branch: `fix/lamin-portal-crud-offline-20261030`.
- Active pull request: #22 — https://github.com/laminahmed12/school-mobile-app/pull/22
- PR is currently **open and unmerged**. Keep it that way unless the user explicitly authorizes a merge.
- Latest branch HEAD checked while updating this file: `8356ff858e6e1d6fe72e7eb439582a14e226d412` (this latest commit only updates this context document; the candidate code was built and validated on its parent code commit `b0bcc0d3f8955fed292a9ceabf33df7f6353e72c`).
- Current app version in `pubspec.yaml`: `2.0.3+15`. A debug-signed test candidate for this version was built successfully by GitHub Actions; it is not the commercial release signature.

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
- `lib/backup_service.dart`- `lib/backup_view.dart`
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
- Verified branch HEAD: `bcc8d411a3228be0daf8bce32ac53272c10dbc50`.- Pull request: #22, **OPEN / UNMERGED**:
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

The workflow uses:- Java 17.
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


---

# VERIFIED HANDOVER UPDATE — 2026-11-03 04:20 UTC

This update supersedes older build/CI status entries above where they conflict.

## Current source and CI

- Repository: `laminahmed12/school-mobile-app`.
- Project: Lamīn School / Supabase only.
- Branch: `fix/lamin-portal-crud-offline-20261030`.
- Verified HEAD: `b0bcc0d3f8955fed292a9ceabf33df7f6353e72c`.
- Latest commit: `ci(android): retry and verify NDK install before Gradle build`.
- Candidate version from `pubspec.yaml`: `2.0.3+15`.
- Development validation run: **41576326304 — SUCCESS**:
  https://github.com/laminahmed12/school-mobile-app/actions/runs/41576326304

## Exact CI results

All of these steps passed on HEAD `b0bcc0d...`:
- Resolve Flutter dependencies.
- Dart formatting and formatting verification.
- `flutter analyze --no-pub --fatal-infos --fatal-warnings`.
- `flutter test --no-pub`.
- Generate Android platform files and install Lamin native Android identity bridge.
- Install and verify NDK `27.0.12077973`.
- Build Android candidate APK.
- `apksigner verify --verbose`.
- Verify package identity/version with `aapt dump badging`.
- Generate SHA-256 and upload both artifacts.

### NDK failure and verified fix

Previous run `41575753475` passed Dart tests but Android build failed because the GitHub runner received a corrupted NDK archive:
`java.util.zip.ZipException: Archive is not a ZIP archive` while installing `ndk;27.0.12077973`.
Added a step to `.github/workflows/lamin-development-validation.yml` that:
- Locates `sdkmanager`.
- Accepts Android SDK licenses.
- Installs NDK `27.0.12077973` explicitly with up to three attempts.
- Removes incomplete NDK directory between attempts.
- Verifies `source.properties` reports exactly the requested revision.

The new NDK step passed on run `41576326304`, and Gradle APK build then completed successfully. Preserve this retry/install step.

## Downloadable APK test candidate

Artifact:
- Name: `lamin-development-candidate`
- Artifact ID: `13203379921`
- Run ID: `41576326304`
- ZIP name retrieved in this session: `lamin-development-candidate-b0bcc0d.zip`
- Artifact ZIP SHA-256: `6dd279b1c0fd89d90f3fe14298835e76037815441ab98933176d5d20b22552d5`
- Retention: until 2026-11-10 04:15:23 UTC (verify current expiration in GitHub before relying on it).

APK path inside artifact ZIP:
`school-mobile-app/school-mobile-app/build/app/outputs/flutter-apk/app-release.apk`

APK SHA-256 (also recorded in `_temp/lamin-candidate-sha256.txt`):
`9d7d2336427b71f70cf2edc6b130525a70b7db017e743116a90b4f16e9ac8779`

APK size: 61,973,456 bytes (approximately 60 MiB).

The APK was extracted and the checksum was independently recomputed in the assistant runtime; it matched the workflow-generated checksum exactly.

### Signature and identity verification

The APK was verified locally with the workflow's packaged `apksigner` tool:
- APK integrity: verified.
- V1: false.
- V2: true.
- V3: false.
- V3.1/V3.2/V4: false.
- Signer: `CN=Android Debug, O=Android, C=US`.
- Debug certificate SHA-256:
  `8da193dba5a5f18a853ea514e9c592b327c911d2c5438da6068049a9463c1c27`.
- CI package identity/version verification passed (application ID and pubspec version matched).

This is a **debug-signed test candidate**, not a commercial release. It cannot update the existing production-signed app. Install it only on a separate/empty test device; never uninstall the existing production app just to install this candidate.

## Offline-login device-binding implementation in this candidate

The branch contains:
- `lib/device_identity.dart`: Flutter method-channel wrapper for device-bound proof.
- `tooling/android/MainActivity.kt`: native Android Keystore EC key generation/proof implementation, copied into the generated Android project by CI.
- `lib/offline_credentials.dart`: v3 local identity/credential record; PBKDF2 password verifier plus public-key fingerprint/signature and account/school/license snapshot.
- Device-bound login remains additional to password verification, school/user matching, active account/school, license/trial, forced-password-change and device-lock checks.
- Do not use IMEI or a user-entered Android ID. No manually typed device identifier is needed.
- Device key is non-exportable in Android Keystore. Its public-key fingerprint is used as the device ID, and the app must prove possession of the private key on cold offline login.
- Android Keystore hardware-backed status is recorded, but it is not a substitute for the full password/school/license checks.

## Remaining acceptance gates — NOT YET VERIFIED ON A PHYSICAL PHONE

User's confirmed prior behavior:
- Online login works.
- Operations while an already-open session loses internet work and queue for later sync.
- Adding a student offline works.
- Cold-start / force-close / airplane-mode login had failed in earlier builds.

The current candidate is the first build from this device-bound branch with:
- v3 device-bound identity snapshot validation,
- PBKDF2 password verifier,
- Android Keystore public-key fingerprint/signature proof,
- login form retained until secure credential save and read-back complete,
- failed credential persistence kept visible instead of routing to the home screen,
- device-binding regression tests.

**Do not mark cold-start offline login as fixed until a physical-device test confirms it.**

Required device test:
1. Use a separate test phone or a device without the existing production app/data.
2. Install the current debug-signed `2.0.3+15` candidate.
3. Sign in online once with the intended test school/account and confirm the device ID/binding is created and shown.
4. Force-stop the app (do not merely background it).
5. Enable airplane mode.
6. Relaunch and enter the same school code, username, and password.
7. Confirm offline access succeeds.
8. Confirm wrong password, different school, and a different device are rejected.
9. Confirm biometric/device-lock behavior remains intact.
10. Reconnect and check that normal online session refresh and queued sync work.

Other acceptance gates remain:
- Investigate >30-second operations across all screens and repository methods.
- Verify encrypted local backup creation and restoration fully offline.
- Preserve working offline student creation and idempotent queue replay.

## Commercial release remains ON HOLD

- Existing signed 2.0.3+13 V1+V2+V3 APK and release certificate remain the commercial signing reference (hash and fingerprint documented earlier in this file).
- Do NOT run `release-signed-apk.yml`, create a GitHub Release, or sign this 2.0.3+15 candidate yet.
- Do NOT create or replace any keystore.
- Wait for physical-device offline-login acceptance, slow-operation fixes, local backup/restore acceptance, and all CI checks before preparing the next commercial signed version with the original certificate.
- Do not change `main`, merge PR #22, or touch production Supabase.


---

# AUTHORITATIVE HANDOVER — 2026-11-03 (LATEST VERIFIED STATE)

This section supersedes any older HEAD, source version, candidate build, and offline-device-login status recorded earlier in this file.

## 1. Exact project and Git state

- Repository: `laminahmed12/school-mobile-app`.
- Project: **Lamīn School / Supabase only**.
- Working branch: `fix/lamin-portal-crud-offline-20261030`.
- Latest verified branch HEAD: `8356ff858e6e1d6fe72e7eb439582a14e226d412`.
- Latest HEAD commit message: `docs(context): record device-bound candidate build and NDK recovery`.
- The latest HEAD commit changes only `PROJECT_CONTEXT.md`; the source code built into the latest candidate is from parent commit `b0bcc0d3f8955fed292a9ceabf33df7f6353e72c`.
- PR #22 remains **OPEN and UNMERGED**. Do not merge, close, or retarget it.
- PR base and all branch/prod boundaries remain as recorded earlier.
- `pubspec.yaml` version: `2.0.3+15`.
- No production Supabase migration or production data change was made.

## 2. Existing commercial signed APK — preserve it

A commercial signed APK already exists and was verified in the earlier session:

- Filename: `lamin-school-2.0.3-13-v1-v2-v3-signed.apk`.
- Version: `2.0.3+13`.
- Signing schemes: V1 + V2 + V3.
- Release certificate SHA-256 fingerprint:
  `7B:9C:F1:1E:AF:AB:48:01:BE:68:21:D6:92:ED:AE:34:75:61:8F:CB:51:BE:21:86:B0:F5:86:6B:24:41:88:1A`.
- Existing APK SHA-256:
  `f0d4dc99410bcd741386ecd69da040f72bbe16754ba82af00f0af744ac97f7da`.

This is the existing commercial signing reference, NOT the current code candidate. Never create a new keystore or replace the certificate. Do not ask the user to upload the existing key or enter secrets again unless a real release run later proves a missing setting.

## 3. Latest successful APK build — verified and downloadable

GitHub Actions workflow:
`.github/workflows/lamin-development-validation.yml`

Successful run:
https://github.com/laminahmed12/school-mobile-app/actions/runs/41577403383

- Run ID: `41577403383`.
- Run number: `463`.
- Candidate code commit: `b0bcc0d3f8955fed292a9ceabf33df7f6353e72c`.
- Workflow conclusion: **SUCCESS**.
- Job: `validate`, conclusion **SUCCESS**.

All steps passed:
1. Resolve dependencies.
2. Format Dart sources.
3. Verify Dart formatting.
4. Static analysis (`flutter analyze --no-pub --fatal-infos --fatal-warnings`).
5. Automated tests (`flutter test --no-pub`).
6. Generate Android platform files and install Lamin native identity bridge.
7. Install and verify NDK `27.0.12077973`.
8. Build Android candidate APK.
9. Verify candidate APK signature and application ID/version.
10. Package/upload the Android signing toolchain.
11. Upload candidate APK and SHA-256.

### Actual candidate Artifact

- Artifact name: `lamin-development-candidate`.
- Artifact ID: `13204806929`.
- Run ID: `41577403383`.
- Artifact ZIP digest: `sha256:de471a33b3813032dffa972ad3193ede4b6b2b750f6113abf8aea790c4f68867`.
- Expiration: `2026-11-10T04:27:33Z` (check GitHub for current expiration before download).
- APK path inside ZIP:
  `school-mobile-app/school-mobile-app/build/app/outputs/flutter-apk/app-release.apk`.
- APK size: `61,973,456` bytes.
- Independently verified APK SHA-256:
  `413b6a5aac6603a798f7f1fe247f5214b880e8b87cf8d78c9c9334b58cab6e49`.
- The SHA-256 computed from the extracted APK matched `_temp/lamin-candidate-sha256.txt` exactly.

### Candidate signature classification

This is a **debug-signed testing APK**, not a commercial release.

Locally verified using the packaged `apksigner` from Artifact `13205120942`:
- APK integrity: verified.
- V1: false.
- V2: true.
- V3: false.
- V3.1/V3.2/V4: false.
- Signer: `CN=Android Debug, O=Android, C=US`.
- Debug certificate SHA-256:
  `d129a241808012b9f0f8f1e34d8e40f66ba16e93b4eb902b7043ad8386ae698c`.

Never present it as V1/V2/V3 release-signed. It cannot update the existing production-signed app. Use a separate/empty test phone; do not uninstall the existing production app to install this candidate, because that may delete local data.

### How to build and obtain another test APK directly from this ChatGPT conversation

The connected GitHub access has already been used successfully in this conversation to edit the branch, inspect GitHub Actions, download the candidate Artifact, extract the APK, and verify its checksum/signature. Continue doing this directly; do not ask the user to build locally.

For any new source changes:
1. Commit them only to `fix/lamin-portal-crud-offline-20261030`.
2. GitHub Actions runs `Lamin development validation` for the branch/PR.
3. Inspect the run corresponding to the exact source HEAD and require all steps above to pass.
4. Download Artifact `lamin-development-candidate` from that run, not `lamin-apksigner-toolchain`.5. Extract `app-release.apk` from the path above.
6. Recompute SHA-256 and compare it with `_temp/lamin-candidate-sha256.txt`.
7. Verify package name/version with `aapt dump badging` and signature with `apksigner verify --verbose --print-certs`.
8. Give the user the actual APK file/link only after the exact file was retrieved and verified.

The workflow's current build command and NDK recovery step are documented in the prior sections. Preserve Java 17, Flutter 3.35.4, and explicit NDK 27.0.12077973 retry/install verification.

## 4. Offline login — current implementation includes device binding

User's requested requirement: **offline entry must be tied to the device identity registered during a successful online login**. Keep it as a mandatory part of offline authentication.

The current source contains:

- `lib/device_identity.dart`: Flutter interface to the native Android device-key service.
- `tooling/android/MainActivity.kt`: native Android Keystore implementation.
- `lib/offline_credentials.dart`: v3 secure offline identity record with password verifier and device binding.
- `lib/main.dart`: cold-start prefill, offline verification, failure messages, and visible enrolled device identifier.
- `test/offline_auth_preflight_test.dart` and other device-binding tests: structural and authentication regression checks.
- `.github/workflows/lamin-development-validation.yml`: copies the native identity bridge into generated Android project files before building.

### Device ID design in the current candidate

- Android Keystore creates a non-exportable EC `secp256r1` key pair for the app installation.
- The displayed device identifier is SHA-256 of the public key (64 lowercase hexadecimal characters; UI displays it as a selectable identifier).
- The raw private key never leaves Android Keystore.
- The local v3 identity record binds: Supabase user ID, school ID/code, username/role, active profile, forced-password-change state, school active/license/trial snapshot, PBKDF2 verifier, device ID, public key, and a signature over the binding challenge.
- Offline login requires the same device key/public key and valid challenge signature, then checks school/user, password, active status, license/trial, and device-lock/biometric state.
- This is an app-scoped Keystore key identity, not IMEI and not a manually typed Android ID.
- The login UI displays the registered device identifier after online enrollment. The offline flow obtains and checks it automatically; do not treat the displayed identifier by itself as an authentication secret.
- Do not replace this design with a user-entered IMEI or publicly readable Android ID.
- Do not log private key material, passwords, PBKDF2 verifier, or complete sensitive identifiers to CI logs.

The user asked for a device-ID requirement because previous offline login attempts failed. Treat device binding as an additional factor; do not remove password verification or account/school/license restrictions.

## 5. Current user-observed behavior and what is still unverified

Confirmed by the user:
- Online login succeeds.
- If the app is already open and the internet disconnects, it continues working; offline changes are retained and can sync after reconnecting.
- Adding a student offline works.
- Cold-start / close-and-reopen login in airplane mode failed on the earlier 2.0.3+14 candidate, even after an online login.

The latest 2.0.3+15 candidate adds the device-bound Keystore identity and the v3 secure record. It has passed CI and was built successfully, but **the user has not yet confirmed cold-start offline login on a physical device using this latest 2.0.3+15 candidate**. Never state that offline login is fixed until that test passes.

### Required physical-device test for 2.0.3+15

Use a separate/empty test phone because the candidate has a debug signature different from the existing commercial signed app:

1. Install the latest 2.0.3+15 candidate.
2. Connect to the internet.
3. Sign in with the intended test school/account.
4. Verify that the UI shows the enrolled device ID and that the app completes online login.
5. Force-stop the app completely.
6. Turn on airplane mode.
7. Relaunch the app.
8. Enter the same school code, username and password; press `متابعة دون اتصال`.
9. Verify that the same device-bound key/ID is accepted and the dashboard opens.
10. Try a wrong password, another school code, and (if available) another device; each must be rejected.
11. Confirm active profile/school, trial/license, required password change, and device lock remain enforced.
12. Reconnect and verify online session refresh and pending sync.

If it fails:
- Capture the exact error shown on screen and whether the device ID appears.
- Inspect the v3 identity read/write path, Android Keystore alias availability, native MethodChannel wiring, identity fingerprint, challenge signing/verification, and app lifecycle.
- Do not ask the user to repeat old 2.0.3+14 tests.
- Fix directly on the same branch, add a regression test, rerun CI, and build another candidate through GitHub Actions.
- Do not require the user to type the ID manually unless a clear product requirement remains; the secure design should fetch it and verify possession automatically.

## 6. Other unresolved work

- Cold-start offline login physical-device acceptance: **pending**.
- Operations previously taking 30+ seconds: audit all screens/repository/RPC paths; target fast local feedback and bounded server waits; preserve idempotency.
- Encrypted cache-only local backup creation/restoration in full airplane mode: physical-device acceptance pending.
- Preserve working offline student addition and the existing offline operation queue/idempotent replay.
- Do not confuse CI success with physical acceptance.

## 7. Commercial signing is explicitly deferred

- Existing commercial signed APK 2.0.3+13 remains the signing reference (details above and earlier in this file).
- Do NOT run `release-signed-apk.yml`, sign 2.0.3+15, publish a new GitHub Release, or modify signing secrets now.
- The next commercial version must use the SAME existing release certificate and a version code greater than 13, after all offline-login, latency, backup/restore, and physical-phone acceptance gates pass.
- Do not create a replacement keystore.
- Do not uninstall the commercial app or risk its local data to test a debug APK.

## 8. Exact instructions for the next ChatGPT conversation

1. Read this entire `PROJECT_CONTEXT.md` from branch `fix/lamin-portal-crud-offline-20261030` first.
2. Fetch the actual current branch HEAD; the HEAD above is the reference at handoff and may advance after this documentation commit.
3. Verify PR #22 is still open/unmerged.
4. Inspect current code and the latest GitHub Actions run for the exact HEAD. Do not repeat successful work from older commits.
5. Continue only on `fix/lamin-portal-crud-offline-20261030`. Never switch to Lamīn Management/Firebase.
6. Treat the current successful 2.0.3+15 candidate and Artifact `13204806929` as the latest available test build; download it from run `41577403383` if still unexpired. Do not rebuild unchanged source merely to repeat a completed build.
7. Prioritize the user's physical test result for cold-start offline login with device-ID binding. If it fails, fix the reason directly, add tests, and build another test APK using the documented GitHub Actions artifact route.
8. Then fix/verify >30-second operations and fully offline local backup/restore.
9. Preserve offline student addition, queue idempotency, device-bound authorization, password verification, license/trial rules, school/user isolation, and biometric/device lock.
10. Keep commercial signing on hold until all acceptance gates pass. Preserve the existing signed 2.0.3+13 certificate and never generate a new keystore.
11. Keep PR #22 open/unmerged; do not touch `main`, production Supabase, or Lamīn Management/Firebase.
12. Update this file with exact commits, CI run IDs, artifact IDs, checksums, and actual phone-test results after each verified milestone.

## 9. Communication and execution
- Work directly; do not replace implementation with a plan or repetitive manual instructions.
- Do not ask the user to re-upload files or repeat already-confirmed information.
- Use the existing GitHub connection to inspect, edit, build through Actions, retrieve candidate APKs, and verify them from this conversation when available.
- Never claim offline login works until the latest candidate passes the physical-device cold-start airplane-mode test.
- Never claim the commercial release was signed or published while release signing is deferred.
- Final reports in Arabic, concise, with actual changes, CI/build results, and the one concrete phone test or blocker.



---

## IMPLEMENTATION UPDATE — 2026-11-03

- Re-inspected branch HEAD `d088214eb16b46bc32ab1297d4c4f821fa84e474`, PR #22, and the completed candidate workflow.
- Identified a cold-start authentication gate defect: `shouldShowLoginForm` hid the login form whenever a persisted Supabase session existed, even when the device had no internet. This could bypass the required password/device-bound offline verification on a cold start.
- Updated `AuthGate` to classify actual internet availability during its initial restore. When offline (or when connectivity classification fails), a restored session now remains behind the login form until the offline password/device proof succeeds. The cold offline path no longer waits for a remote profile fetch.
- Kept online session behavior when internet is available. Successful online login clears the startup proof gate only after the existing local-credential preparation succeeds.
- Successful offline authentication still requires the v3 Android Keystore signature, matching device/public key, PBKDF2 password, matching school/user, active profile and school, valid license/trial, and biometric lock.
- App pause/hidden now also reapplies biometric lock to an offline-authenticated session even when there is no live Supabase session.
- Added a regression test proving that a restored Supabase session cannot hide the login form during an offline cold start, and that the form can close after offline proof succeeds.
- The previously completed candidate `2.0.3+15` remains unchanged: CI run `41577403383` succeeded for source commit `b0bcc0d3f8955fed292a9ceabf33df7f6353e72c`; downloaded APK SHA-256 verified as `413b6a5aac6603a798f7f1fe247f5214b880e8b87cf8d78c9c9334b58cab6e49`. Its only successor commit before this change updated this context file.
- This new source change is not yet validated by CI. Physical-device cold-start acceptance remains pending. Commercial signing remains on hold.


## HANDOVER UPDATE — 2026-11-03 (current chat)

- Current branch: `fix/lamin-portal-crud-offline-20261030`; project remains Lamīn School / Supabase only. Do not touch Lamīn Management / Firebase.
- Latest reviewed areas: `lib/repository.dart`, `lib/biometric_service.dart`, and `lib/main.dart`. No source code was changed in this chat.
- Student queue review: queued `create_student` replay calls `create_student_with_fee_idempotent`; replay requires a valid Supabase session, school profile, and server availability. RPC errors halt replay and preserve the operation. The exact user-reported failure is not yet diagnosed; inspect the student form submit handler and matching RPC SQL before editing.
- Device lock review: lifecycle handling locks on pause/hidden; refresh depends on session/offline access and biometric preference. Cause of repeated prompt is not confirmed. Trace state transitions before changing; preserve all authentication safeguards.
- No CI was run, no APK was built or signed, and no device test was performed in this chat. No production data, main branch, PR merge, or signing material was changed.
- Next: diagnose both issues from exact current source, implement narrowly scoped fixes with regression tests on this branch, run CI for the resulting HEAD, and only then retrieve and verify a test APK. Commercial signing remains deferred.
- GitHub integration has read access and has previously successfully committed branch file edits; Actions artifact build/retrieval and APK verification worked in a prior session. Do not claim these were performed in this chat. Signing secrets are not exposed; commercial signing can only use the established approved workflow and existing configured certificate/secrets, and remains on hold.


## VERIFIED HANDOVER UPDATE — 2026-11-03 (student create, biometric lifecycle, CI and test APK)

- **Verified code HEAD:** `692fb4881ea821c3e3b287cc9af1fe89d09dfadd` on `fix/lamin-portal-crud-offline-20261030`. PR #22 remains open and unmerged. No change was made to `main`, production Supabase, or Lamīn Management/Firebase.
- **Student create/sync diagnosis:** the app calls `create_student_with_fee_idempotent`. The branch migration that introduces this function is not recorded as deployed to production in the current project handover. A missing PostgREST function response (`PGRST202` / PostgreSQL `42883`) previously escaped the network-fallback path and caused the form to fail instead of retaining the operation. The older baseline `create_student_with_fee` routine also had a mismatched INSERT column/value list and omitted `class_name`; the branch migration already contains the corrected implementation. No production migration was run.
- **Student fix:** both immediate creation and queued replay now share one RPC name/parameter builder with the exact SQL argument names, including `p_class_name`. A missing RPC or network failure retains the operation in the encrypted local queue with its stable operation ID. Queue replay keeps the operation pending when the RPC remains unavailable and exposes an explanatory sync error. The form tells the user when the save is local and sync is pending. Permission and validation errors are not converted into silent local success.
- **Biometric lifecycle fix:** the auth gate no longer re-runs the persisted-session lock check on every `resumed` event. A biometric lock is applied only on `paused`/`hidden`, only when the biometric preference is enabled and an authenticated online/offline access state exists. Resume and unlock invalidate any outstanding asynchronous background check, preventing a stale read from re-locking the app after returning. Password verification, Android Keystore device binding, school/user checks, and license/trial checks were not weakened.
- **Regression tests added:** `test/student_creation_rpc_test.dart` checks the RPC argument contract, missing-function code handling, and non-fallback for permission/validation errors. `test/biometric_lifecycle_lock_test.dart` checks background locking, resume/inactive behavior, disabled biometric preference, and absence of authenticated access.
- **Verified CI for this exact code HEAD:** development validation run **41603057446 (push)** and **41603065940 (pull_request)** both concluded `success`. Steps passed: dependency resolution, Dart formatting and formatting verification, Flutter static analysis with fatal infos/warnings, `flutter test --no-pub`, Android platform setup, NDK 27.0.12077973 installation, APK build, APK signature/package/version verification, and artifact uploads. Also successful on the same HEAD: portal validation runs **41603057325** and **41603065788**; schema baseline acceptance runs **41603057405** and **41603065902**; RPC security ACL regression runs **41603057323** and **41603065892**.
- **Test APK from the exact code HEAD:** workflow run **41603057446**, artifact **13214459551** (`lamin-development-candidate`). Version **2.0.3+15**; application ID **com.adreemk.school.lamin_school**; APK size **61,989,840 bytes**. The workflow's package/version check passed. APK SHA-256 independently recomputed after download: `fe26e8b4e1f5e48367e9d0d79d453eac16493c634bf2dae5e6957312b7380353`, matching the checksum file inside the artifact. Local `apksigner verify --verbose --print-certs` passed; signer is **Android Debug**, V2 signature only, certificate SHA-256 `6be751e6f206e93312f7751cc8d19022206cc182703cd65167a816f943acdfc5`. This is a test build, not the commercial certificate. Artifact digest for the ZIP: `sha256:e34f0f61cfd6fb778d88fee313688b821a1f477cd6163921af197537fcbf49e1`.
- **Physical-device acceptance remains pending:** cold-start offline password login/device binding; biometric pause/resume behavior; offline student add and eventual idempotent replay after the approved server migration is deployed; and fully offline backup/restore. No handset test was performed in this session. Use a separate test device for the Debug-signed APK; do not uninstall or overwrite the existing commercial app.
- **Commercial signing remains deferred:** do not run the commercial signing workflow, alter signing secrets, create a keystore, or change the existing 2.0.3+13 release certificate until all physical-device acceptance gates are passed. Performance/slow-operation acceptance also remains pending.


## AUTH REGRESSION CORRECTION — 2026-11-03

- User identified workflow run 41582884498 as an earlier version with offline entry. Verified run 41582884498 built commit b1723cedfde06d0a6cb3b3352cf14d78d8b011a7; its direct code change introduced an internet-reachability test as a mandatory cold-start decision and forced `startupRequiresOfflineCredentialProof` based on `!hasInternet`.
- Earlier candidate run 41577403383 built commit 8356ff858e6e1d6fe72e7eb439582a14e226d412. The current branch head at correction time was 57e0fa5be0ac43beb13dc8d650dc2df1186ca6c8.
- Correction: AuthGate now makes cached local identity the primary startup path, probes internet only for a missing cached profile/remote fallback, and does not use failed internet detection itself to suppress offline access. A restored session still requires offline password + device-bound verification; successful verification clears the gate. Existing biometric lifecycle revision protection is retained.
- Added/updated cold-start authentication contract tests for restored sessions, successful offline proof, and online session behavior.
- This change is on the existing fix branch only. It does not touch main, production Supabase, PR merge state, Lamīn Management/Firebase, or commercial signing. CI and a new APK are pending until the new branch HEAD completes workflow validation.


## BUILD ACCESS CLARIFICATION — 2026-11-03
- The user has previously received multiple APK files generated through this ChatGPT/GitHub workflow. Do not tell the user that APK generation or retrieval is categorically unavailable.
- GitHub Actions candidate build and artifact download/retrieval have worked in prior sessions; the GitHub connection can read/edit branch files, inspect runs/artifacts, download artifacts, and APK verification has been completed before.
- The current connector tool list does not expose a workflow-dispatch action. This is a session/tool-surface limitation, not proof that the user lacks repository permissions or that APK generation is impossible. Before concluding blocked, inspect recent runs/artifacts for the exact branch HEAD and use a successful candidate artifact if available. If a new run must be started and dispatch is unavailable, state that specific limitation accurately.
- Keep using the unsigned/debug-signed candidate for phone testing. Do not invoke the commercial signing workflow until all required edits and physical-device acceptance are complete, as explicitly ordered by the user.
- Do not ask the user to repeat this history.

## USER CLARIFICATION — 2026-11-03

- User confirms cold-start offline login had already succeeded previously.
- Biometric authentication is required for offline entry; preserve this requirement and do not weaken or remove it.
- User explicitly instructed: make no code changes. This update is documentation-only.
- Current scope: retain the previously verified progress and avoid further authentication edits unless the user requests them.


## USER-REPORTED STATUS — 2026-11-03 (student archive/delete and display)

- Preferred behavior: archive a student with no financial obligations rather than permanently delete them.
- Registration without a phone number fails both online and offline.
- Deleting a student with a zero balance fails both online and offline. Investigate replacing this path with archival, while preserving financial/audit history and preventing archive when obligations exist.
- Date formatting is confirmed working; do not change it.
- Student names in financial operations appear only after searching; this is currently expected/accepted behavior.
- Student names in the Students window are always visible; this is currently expected/accepted behavior.
- These are user-reported results, not independently tested in this session. No code changes, tests, or APK build were performed for these issues.


## HANDOVER — 2026-11-03 (student archive request)

- User clarified with a screenshot that student deletion was attempted and failed with PostgreSQL/PostgREST error 23503: deleting from `payments` is blocked by foreign key `payment_allocations_payment_fk` because rows in `payment_allocations` still reference the payment. This is not a silent/no-op delete.
- User chose **archive instead of permanent deletion**. Implement an archive action that preserves student, payment, allocation, attendance, and audit history. Do not cascade-delete financial records or bypass FK constraints.
- The current UI’s delete handler directly deletes the student row; its error message mentions archive, but no verified archive implementation was found in the reviewed path. Exact schema fields, RPC/migration support, list filtering, and offline queue semantics still need inspection before code changes.
- Phone remains optional by user requirement; registration without a phone has been reported to fail online and offline. Diagnose the actual form/RPC/schema contract and make nullable/blank phone work in both online creation and queued replay without changing unrelated validation.
- Screenshot confirms the user-facing delete error: “لم يُحذف الطالب… PostgrestException… update or delete on table payments violates foreign key constraint payment_allocations_payment_fk … Key is still referenced from table payment_allocations.”
- No source code, database, or production data was changed for archive/optional-phone work in this session. No tests or APK build were run for these issues.
- Existing signed reference APK remains `lamin-school-2.0.3-13-v1-v2-v3-signed.apk`, version 2.0.3+13, with certificate fingerprint and SHA-256 documented above. It is a preserved reference, not a build containing current source changes. Commercial signing remains deferred.
- Next execution: inspect current branch HEAD and PR state; inspect student schema/migrations, RPCs, repository queue replay, and UI filtering; implement archive/unarchive or archive-only according to existing schema, ensure archived students are hidden from active lists but retained in history, make phone optional online/offline; add regression tests; run CI and only then produce a test APK. Do not run production migrations or merge PR #22.


## User direction — archive records (2026-11-04)
- Current task: replace destructive deletion with archiving for students, teachers, and employees.
- Archived records must be hidden from ordinary active lists and visible only through search inside a dedicated Archive section.
- User confirmed there is no real or important data in the app; all current records are test data. This permits implementing the requested archive behavior for the test dataset, but does not authorize destructive production database operations.
- Preserve records and their linked history; do not hard-delete records as part of archive. Include restore only if the existing architecture supports it safely.
- Inspect schema, foreign keys, RPCs, offline queue/sync, and all relevant list/search screens before changing behavior. Keep archived records out of normal lists and scope archive search to archived records.
- Continue only on `fix/lamin-portal-crud-offline-20261030` in `laminahmed12/school-mobile-app` (Lamīn School/Supabase). Do not touch Lamīn Management/Firebase, `main`, PR merge state, or production data.
- The previously recorded HEAD/context may be stale. Re-check the actual branch HEAD before editing and record exact changed files, commit, and checks actually run.
- No archive implementation or tests have been verified yet as of this note.


## Delegated project execution (2026-11-04)
- The owner delegates routine implementation and repair decisions for Lamīn School to the assistant; proceed without approval for each ordinary step and report only verified work.
- Scope remains this repository and branch `fix/lamin-portal-crud-offline-20261030`. Do not switch to Lamīn Management/Firebase, change `main`, merge PRs, alter production data/configuration/secrets, or perform destructive database operations without explicit authorization.
- Data lifecycle policy: archive/restore only; no hard-delete action or UI option for students, teachers, or employees. Preserve records and relationships. Exclude archived records from active lists; provide discovery through the dedicated archive search.


## VERIFIED SESSION UPDATE — 2026-11-04 (archive action UI and CI syntax correction)

- Repository/branch: `laminahmed12/school-mobile-app`, `fix/lamin-portal-crud-offline-20261030`. Project is Lamīn School / Supabase only.
- This session added an action chooser to student and teacher record handlers in `lib/main.dart`: archive calls the existing `archive_person` RPC; permanent deletion remains available behind a second confirmation. Both actions refresh the relevant view and report errors.
- The first edit accidentally produced duplicate declarations (`Future<void> Future<void> deleteStudent` and the equivalent teacher declaration). GitHub Actions formatting validation caught this exact syntax error. The duplicate return-type text was removed in a follow-up commit.
- Fix commit: `6e5d098a245ad561b54f1265bedc1b11dd61b390`. File blob verified by re-fetch: `d9b29b70115f049b991b324fb741129fbec50545`. The source now contains one declaration for each handler and no duplicated `Future<void>` sequence.
- CI state for the fix commit: no workflow runs were returned by the commit-workflow lookup. Do not claim format, analyze, tests, or APK build passed for this commit. No APK was built or downloaded in this session.
- IMPORTANT SCOPE MISMATCH: the latest user direction in this context requires archive/restore only and explicitly forbids any hard-delete action or UI option for students, teachers, or employees. The current handlers still expose “حذف نهائي” and still contain direct DELETE calls. This is NOT compliant and must be removed before considering the archive task complete.
- Also not completed/verified: employee archive path; dedicated archive section and archived-only search; exclusion of archived records from active lists; restore UI/flow; archive reason/note handling; offline queue semantics; regression tests; full CI; test APK build and physical-device acceptance. No production Supabase changes were made.
- Next: remove permanent-delete options and direct hard-delete paths for student/teacher; inspect and implement the same archive-only lifecycle for employees; connect archive filtering/search/restore to the existing schema and RPCs; add tests; run the branch CI and obtain a test APK only from a successful matching HEAD. Keep commercial signing deferred and do not change production or secrets.

## Fixed execution permissions and working prompt

Use these as standing execution instructions for future sessions:

> **صلاحيات التنفيذ الثابتة:** لدي اتصال GitHub مُخوّل بمستودع `laminahmed12/school-mobile-app`. افحص الأدوات المتاحة واستخدمها مباشرةً لقراءة الملفات وتعديل الفرع المحدد وتشغيل فحوصات GitHub Actions وبناء APK عبر مسار البناء الموجود في المستودع. لا تفترض غياب الصلاحية أو القدرة قبل فحص الأدوات والـ workflows. لا تغيّر الإنتاج أو الأسرار. إذا تعذّر إجراء محدد بعد تجربة المسارات المتاحة، اذكر العائق الفعلي فقط، ولا تعمّم العجز على بقية الصلاحيات.

> **أمر الاستئناف:** اقرأ `PROJECT_CONTEXT.md` من مستودع `laminahmed12/school-mobile-app` أولًا، ثم تحقق من HEAD الفعلي والفرع `fix/lamin-portal-crud-offline-20261030` وحالة PR #22 وآخر Actions. نفّذ مباشرةً دون طلب معلومات موجودة في الملفات أو الأدوات. أكمل أرشفة الطلاب والمعلمين والموظفين فقط: أزل خيار الحذف النهائي ومسارات DELETE، حافظ على السجلات والعلاقات، أخفِ المؤرشف من القوائم النشطة، واجعل البحث عنه داخل قسم الأرشيف فقط، وأضف الاستعادة إذا دعمها المخطط بأمان. افحص المخطط وRPCs والـ offline queue قبل التعديل، وأضف اختبارات، ثم شغّل CI وابنِ APK اختبار عبر المسار المتاح بعد نجاح الفحوصات. لا توقّع إصدارًا تجاريًا الآن، ولا تغيّر main أو تدمج PR أو تمس الإنتاج أو الأسرار. حدّث هذا الملف بنتائج مؤكدة فقط. في التقرير النهائي اذكر التعديلات والفحوصات الفعلية وحالة APK وما يلزم اختباره على الهاتف؛ لا تدّع نجاحًا غير متحقق.



## USER REQUEST — 2026-11-04 (documentation-first checkpoint)

- User explicitly requested that this canonical file be updated first, before continuing implementation.
- Confirmed current task remains archive-only lifecycle for students, teachers, and employees: remove permanent-delete UI and direct DELETE paths; preserve records/relationships; hide archived records from active lists; discover archived records only through search in the dedicated Archive section; add restore only where safely supported by schema/RPCs and offline sync.
- Work remains limited to `fix/lamin-portal-crud-offline-20261030` in this repository. Do not modify production, secrets, `main`, or PR merge state; commercial signing remains deferred.
- This checkpoint is documentation-only. No application source, database, workflow, or APK was changed or tested as part of this file update.
- Re-check actual branch HEAD and PR/Actions state before code edits; do not treat the historical commit/run information above as current unless independently verified.


## DOCUMENTATION CHECKPOINT — 2026-11-05

- User requested updating this canonical reference file before continuing implementation.
- Repository and target branch were checked: `laminahmed12/school-mobile-app`, `fix/lamin-portal-crud-offline-20261030`; branch lookup confirms it exists.
- Current archive task remains: archive/restore-only lifecycle for students, teachers, and employees; remove permanent-delete UI and direct DELETE paths; preserve linked records; filter archived people out of active lists; expose archived records only through search in the dedicated Archive section; use the actual schema/RPC contracts and keep offline behavior consistent.
- Scope: this branch only. Do not modify `main`, merge PR #22, alter production Supabase or secrets, or initiate commercial signing.
- This update records the task and constraints only. No application code, database, workflow, or APK was changed or tested in this checkpoint.
- The file contains conflicting historical HEAD entries; the current commit SHA has not yet been independently verified in this checkpoint. Re-check the actual branch HEAD and PR/Actions state before source edits; do not rely on old run IDs or commit claims.
- Next: inspect exact schema/RPC signatures and current source paths, implement the archive-only flow with regression tests, run available CI, and use a successful candidate APK only if it matches the verified code HEAD. Report only checks actually completed.



## VERIFIED SESSION UPDATE — 2026-11-05 (archive menu visibility and test APK)

- Repository/branch: `laminahmed12/school-mobile-app`, `fix/lamin-portal-crud-offline-20261030`.
- Verified branch HEAD for this update: `5c3678bd09e42601d6e945679ceee6b277a36c5f`.
- User-provided phone screenshots showed that student and teacher overflow menus exposed edit/profile actions only; there was no archive option.
- Updated `lib/main.dart` in commit `5c3678bd09e42601d6e945679ceee6b277a36c5f` to expose `أرشفة الطالب` and `أرشفة المعلم` in the respective record menus and route those actions to the existing archive handlers. This fixes the missing menu entries shown in the screenshots.
- CI verified for this exact HEAD:
  - Lamin development validation run `42096108453`: completed successfully; validation job succeeded.
  - Lamin portal validation run `42096108589`: completed successfully.
  - Lamin schema baseline acceptance run `42096108851`: completed successfully.
  - Lamin RPC security ACL regression run `42096108410`: completed successfully.
- A new Android test candidate was produced by development run `42096108453`, matching the verified HEAD above:
  - Artifact: `lamin-development-candidate`, artifact ID `13448141851`, 29,220,014 bytes.
  - SHA-256 of artifact ZIP: `bc3d2d7496c1677337befc6c3120e90b0b7877306e0759683147b170ed0a2a0e`.
  - Expires: 2026-11-12 19:46:31 UTC.
  - Download from Actions run: https://github.com/laminahmed12/school-mobile-app/actions/runs/42096108453 (Artifacts section).
- The APK build and CI are verified, but archive behavior has not been physically tested on the user's phone or against live Supabase data. The archive RPC/migration deployment status in Supabase is not verified here.
- Remaining archive scope is not complete: employee menu/flow, dedicated archive search/list, restore behavior where supported, complete removal of permanent-delete actions and direct DELETE paths, offline queue behavior, and regression coverage still require source/schema inspection and implementation. Do not claim the full archive lifecycle is complete.
- No production database, secrets, default branch, or PR merge state was changed. The candidate is for testing, not a commercially signed release.


## USER CONFIRMED — 2026-11-05 (restore workflow requested)

- User physically tested the latest candidate and confirmed that archiving succeeds on the phone.
- The user asked how to restore archived people. Inspection confirmed that migration `supabase/migrations/20261104000000_archive_only_no_hard_delete.sql` defines secured RPCs `list_archive(text)` and `restore_person(text,uuid)`, but `lib/main.dart` currently has no Archive screen, no `list_archive` call, and no `restore_person` call.
- Next implementation: add an Archive entry in the admin More section, search archived students/teachers/staff through `list_archive`, and restore a selected record through `restore_person`, refreshing active lists afterward. Keep the operation online-only unless the existing offline queue can safely support these RPC semantics; never fake a local-only restore.
- Preserve archive reason/note and history until restore is explicitly confirmed by the RPC; the existing restore RPC clears archive metadata as designed.
- Current branch at this checkpoint: `fix/lamin-portal-crud-offline-20261030`. Recheck HEAD before source edits. Do not touch production DB, secrets, `main`, or PR merge state.
- User reports archive succeeds, but the migration's deployment state in Supabase has not been independently inspected. Do not run production migrations.


## IMPLEMENTATION UPDATE — 2026-11-05 (archive search and restore UI)

- Added `archivedPeople(query)` and `restorePerson(kind,id)` to `lib/repository.dart`. Both require an authenticated online session and use the existing `list_archive` and `restore_person` RPCs with bounded timeouts; restore is not queued offline.
- Added admin-only `الأرشيف` entry under `المزيد` and a searchable archive screen in `lib/main.dart`. The screen lists archived students, teachers, and staff, shows record type/details/archive date, confirms restore, calls the restore RPC, reloads archive results, and refreshes active app data.
- Commits: repository helper `609b821fd2043cd95a2a302168494823096c3631`; UI `e537cc15dcdd8069fa52fa2da99d8c7c48c2761c` (current branch HEAD checked at time of writing).
- GitHub Actions portal validation for the current HEAD is queued as run `42112026306`; no successful format/analyze/test/APK result is claimed yet. Further branch workflows and build artifact must be checked before asking the user to install.
- Source was re-fetched from GitHub and checked for ArchiveView, archivedPeople, restorePerson, and the Archive menu entry. No local Flutter formatter/analyzer/test command has been run in this environment.
- Physical-device restore test and actual Supabase migration/RPC deployment remain unverified. Do not run production migrations.


## PHONE TEST FAILURE — 2026-11-06 (archive RPC signature mismatch)

- User tested the archive screen and supplied a screenshot showing PostgREST error `PGRST202`: app called `public.list_archive(p_query)`, but the live schema cache advertises `public.list_archive(p_kind)`.
- This proves the database RPC contract currently exposed to the app differs from the migration definition in the repository. Do not claim the migration's `list_archive(p_query)` signature is deployed.
- Added a compatibility fallback in `lib/repository.dart` commit `ebcaaf27f23d610a11234c355982af76a8c1d9fc`: try the query-based signature first; on PGRST202, query the older signature separately for student/teacher/staff, merge, locally filter by name, and sort by archive date. No production migration or database change was made.
- Next: wait for CI and APK from this exact commit, then ask user to retry archive listing/search and restore. Restore RPC signature/deployment is not yet confirmed by the screenshot; if restore fails, inspect its exact PostgREST error before changing code/schema.


## VERIFIED BUILD — 2026-11-06 (archive RPC compatibility)

- Fixed the missing `postgrest` package import required by the `PostgrestException` compatibility fallback. Commit: `a568079d0b63853e3661940add4908d1cee7f2e1`.
- All four GitHub Actions workflows completed successfully on this exact commit:
  - Development validation: `42128638017` — success (format, static analysis, tests, Android APK build/signature/package checks).
  - RPC security ACL regression: `42128638047` — success.
  - Schema baseline acceptance: `42128638052` — success.
  - Portal validation: `42128637982` — success.
- Verified APK artifact: `lamin-development-candidate`, artifact ID `13463095954`, 29,242,309 bytes; SHA-256 ZIP `92f08c2c1fad5db6e4d5957c7d412b903f67fab0bec3f952a8cbc0b1b02eb9ae`; expires 2026-11-12 23:26:19 UTC.
- Download from Actions run: https://github.com/laminahmed12/school-mobile-app/actions/runs/42128638017 (Artifacts section).
- This build includes fallback support for deployed `list_archive(p_kind)` RPC signature: separately fetches student/teacher/staff archive sets and filters by name locally when `list_archive(p_query)` is absent.
- Still unverified: live RPC result column compatibility and actual restore operation on user's device. No production database/schema or secrets changed.


## OFFLINE STARTUP REGRESSION — 2026-11-06

- User confirmed archive listing, search, archive and restore all work on the installed development candidate.
- Remaining device issue: app opens the login screen when launched without internet; UI reports no local offline credential.
- Root cause identified in the PR #22 change relative to its base commit `9dbd7f61aeb7e68295fdbfebe348d3ee7dee4b72`: the prior AuthGate opened an already-authenticated cached account offline using the securely stored `lamin.offline.user.id`, cached profile and cached school/license/trial checks. The PR changed cold start to always require a newly enrolled v3 password verifier + Android Keystore proof, even when a valid Supabase session and cached account already existed. This is the behavior regression.
- Restored the prior cached-account startup path on the development branch, while retaining account-active, school-active, license/trial, and forced-password-change checks. The new eligibility policy is isolated in `canOpenCachedOfflineAccount` and covered by unit tests.
- Updated `lib/main.dart`, `lib/offline_credentials.dart`, and `test/offline_auth_preflight_test.dart`.
- Latest branch commit: `4e6d026ceefe67c8f7f8c7d978785b6a579b5d86`.
- CI status for this latest commit is not yet confirmed. Do not distribute an APK until formatting, analysis, tests, APK build and package/signature checks pass.
- No production data, Supabase schema, secrets, or main branch changed.


## OFFLINE STARTUP FIX — CI RESULT 2026-11-06

- Latest PR #22 head: `6c4dd14208bf68b1da8f15f72a78798444a58040`.
- GitHub Actions run `42140796628` (Lamin development validation, run 566) completed successfully.
- Passed: dependency resolution, Dart formatting, format verification, Flutter static analysis, automated Flutter tests, Android platform preparation, NDK installation, APK build, APK signature verification, package identity/version verification, checksum generation, and artifact upload.
- Candidate APK artifact: `lamin-development-candidate`, uploaded in run 42140796628. It is debug-signed for device testing, not production release-signed.
- Additional PR checks passed: Lamin portal validation (run 42140796895), RPC security ACL regression (run 42140796818), Supabase schema baseline acceptance (run 42140796711). Vercel status is success.
- Candidate build is available at: https://github.com/laminahmed12/school-mobile-app/actions/runs/42140796628 (Artifacts section).
- Physical-device offline cold-start acceptance is still required. Production V1/V2/V3 release signing has not been run. Keep PR #22 unmerged and do not apply its branch-only database migration to production until the release gate is satisfied.

## OFFLINE CREDENTIAL ENROLLMENT RETRY — 2026-11-06
- Commit `78b5891fafbb89aff2ec9f5669833384317d61f7` updates the successful online-login enrollment sequence.
- The authenticated user ID is now persisted immediately after Supabase confirms login, before repository cache warm-up.
- Profile and school reads are retried up to three times with bounded timeouts before local enrollment is abandoned.
- After writing the device-bound credential, the app now verifies both record persistence/device binding and the supplied password verifier before marking online login preparation as ready.
- This is a code-level hardening change; it is not yet accepted until GitHub Actions and physical-device offline login both pass. No production backend, schema, or secrets were changed.

## OFFLINE CREDENTIAL ENROLLMENT RETRY — CI COMPLETE 2026-11-06
- Validated branch HEAD before this documentation update: `4ec13c7ebe7013c8fef92cef229c7ad71607a810`.
- Lamin development validation run `42173251542`: success. Formatting, Flutter static analysis, all automated tests, Android preparation, NDK installation, candidate APK build, APK signature/package identity verification, and artifact uploads all passed.
- Lamin portal validation run `42173251280`: success.
- Lamin RPC security ACL regression run `42173251268`: success.
- Lamin schema baseline acceptance run `42173251518`: success.
- Candidate APK artifact: `lamin-development-candidate`, artifact ID `13482376924`, in run `42173251542`. Debug-signed for device testing; not production release-signed.
- Signing toolchain artifact: `lamin-apksigner-toolchain`, artifact ID `13482162564`.
- PR #22 remains open; GitHub currently reports mergeable. Do not merge or apply branch migrations to production until device acceptance and production signing gates are completed.
- No physical-device test result has been reported. Offline cold-start and post-login credential enrollment remain pending field acceptance.


## VERIFIED SESSION UPDATE — 2026-11-06 (archive lifecycle handover recheck)

- Re-read this canonical file from the target branch, then independently checked the branch ref. Current branch HEAD before this documentation-only update: `628634f6e6f23cdf0dba84a108031cd499c3c65c`. The HEAD commit message is `Record offline credential CI validation result`; it changes only `PROJECT_CONTEXT.md`.
- PR #22 is OPEN and UNMERGED. Its base remains `feature/lamin-desktop-portal-2026-10-29`; no merge, retarget, or main-branch change was made.
- Latest Actions for exact HEAD `628634f6e6f23cdf0dba84a108031cd499c3c65c` all completed successfully on 2026-11-06:
  - Development validation `42174910040`: SUCCESS. Verified dependency resolution, Dart formatting and format verification, Flutter static analysis, automated Flutter tests, Android preparation, debug-signed APK build, APK signature/package identity verification, checksum generation, and artifact uploads.
  - Portal validation `42174910125`: SUCCESS.
  - RPC security ACL regression `42174910021`: SUCCESS.
  - Schema baseline acceptance `42174910026`: SUCCESS.
- Development run `42174910040` artifacts: `lamin-development-candidate` (ID `13482742031`, 29,248,073 bytes) and `lamin-apksigner-toolchain` (ID `13483356081`, 16,933,712 bytes). Candidate is a debug-signed testing APK, not a commercial release. Download via the run's Artifacts section: https://github.com/laminahmed12/school-mobile-app/actions/runs/42174910040.
- Archive implementation rechecked in current branch source:
  - Migration `supabase/migrations/20261104000000_archive_only_no_hard_delete.sql` adds archive metadata for `students`, `teachers`, and `staff`; provides `archive_person`, `restore_person`, and `list_archive`; scopes RPC access to authenticated admin/owner users and current school; revokes client DELETE privileges; and retains original rows/foreign-key relationships.
  - `lib/repository.dart` filters archived students, teachers, and staff from active reads; queries the archive with the current `list_archive(p_query)` RPC and a compatibility fallback for the live older `list_archive(p_kind)` signature; and calls `restore_person`.
  - `lib/main.dart` exposes archive actions for students and teachers, the admin-only archive search/restore screen, and the staff archive action. Restore refreshes archive results and active app data.
- The user had previously confirmed on-device that archive listing, search, archive, and restore work on the installed candidate. This session did not repeat a physical-device test or inspect production Supabase deployment state. The compatibility fallback exists specifically because the live PostgREST schema previously exposed `list_archive(p_kind)`; do not claim the repository migration has been applied to production.
- No application source, Supabase database, production configuration, GitHub secrets, or signing material was changed in this session. No commercial release signing was initiated: the prior handover's release hold remains in force pending the separate offline cold-start/device acceptance gate.
- Existing signed release reference remains the previously verified `lamin-school-2.0.3-13-v1-v2-v3-signed.apk` (version `2.0.3+13`, SHA-256 `f0d4dc99410bcd741386ecd69da040f72bbe16754ba82af00f0af744ac97f7da`, certificate SHA-256 fingerprint `7B:9C:F1:1E:AF:AB:48:01:BE:68:21:D6:92:ED:AE:34:75:61:8F:CB:51:BE:21:86:B0:F5:86:6B:24:41:88:1A`). These values are historical verified reference data, not a newly downloaded APK in this session. No GitHub Release asset for it was found.
- No standalone archive-specific automated test file exists in the current `test/` tree. CI's general Flutter tests, schema baseline, and RPC ACL checks passed; a dedicated archive regression suite and production migration-state verification remain outstanding.


## OFFLINE CREDENTIAL DIAGNOSTICS — 2026-11-06

- User confirmed that they had already completed the suggested online-login and offline-retry steps before reporting the failure. Do not ask them to repeat those steps.
- Source review confirmed that `LaminOfflineCredentialStore.readIdentity()` returned null for several distinct conditions (missing secure-storage value, storage read exception, malformed JSON, invalid V3 record) while swallowing the underlying reason. The login UI consequently displayed the same generic message for all cases. This prevented distinguishing a genuinely absent record from Android Keystore/storage corruption or record-version/shape rejection.
- Added non-sensitive diagnostics in `lib/offline_credentials.dart` via commit `7cc09198a9157efb0c328c7112f58e243ae9450d`. The diagnostic distinguishes missing record, secure-storage read failure, malformed record, invalid V3 structure, missing/mismatched Android Keystore key, failed device-binding proof, and a valid record. It does not display or log password, verifier, salt, user ID, school ID, or key material.
- Updated `lib/main.dart` via commit `3a10fcda60483e6afa9859c0e3209e8a003eca91` to show the precise non-sensitive diagnosis when the offline identity cannot be loaded.
- This is a diagnostic hardening change, not yet a proven root-cause fix. CI must pass and the resulting candidate must be installed before the exact failure category can be observed. Do not claim offline login repaired yet.
- No production/Supabase data, secrets, signing keys, or release workflow were changed. No local Flutter SDK/build environment was available in this session; rely on the triggered GitHub Actions checks for format/analyze/tests/APK validation.


## OFFLINE CREDENTIAL DIAGNOSTIC BUILD RESULT — 2026-11-06

- Latest application/test source commit: `c7fba5d95f990d78e503a17255ab4a1ec3209b9c`.
- GitHub Actions for that exact source commit all completed successfully:
  - Development validation run `42195810157`: SUCCESS. Dart formatting, static analysis, all Flutter automated tests, Android platform preparation, Android Keystore identity integration preparation, NDK installation, APK build, APK signature/package verification, and artifact uploads all passed.
  - Portal validation run `42195809873`: SUCCESS.
  - RPC security ACL regression run `42195809838`: SUCCESS.
  - Schema baseline acceptance run `42195809834`: SUCCESS.
- New testing APK artifact: `lamin-development-candidate`, artifact ID `13491359331`, 29,251,796 bytes. It is a debug-signed testing candidate, not a commercially release-signed APK. Download from https://github.com/laminahmed12/school-mobile-app/actions/runs/42195810157 (Artifacts section).
- Signing toolchain artifact: `lamin-apksigner-toolchain`, ID `13492950120`; no signing secrets or release keystore were accessed or modified.
- The diagnostic change is built and CI-verified, but the actual on-device cause is not yet identified. The new APK changes the offline-login failure message to reveal the non-sensitive category (secure storage read, absent/malformed/invalid V3 record, missing/mismatched Android Keystore key, failed key-binding proof, or valid record). A phone test with this exact candidate is required to observe the category; do not report offline login as fixed until it passes an offline relaunch test.


## DIAGNOSTIC APK DEVICE RESULT — 2026-11-06

- User installed and tested the diagnostic candidate. Its on-screen diagnosis is explicit: `لا يوجد سجل اعتماد V3 في التخزين الآمن لهذا التطبيق`. This means secure storage returned null for key `lamin.offline.identity.v3`; this is not a password-verification or device-key-binding failure.
- Important build/install compatibility finding: run `42195810157` produced a **debug-signed** candidate APK (`2.0.3+15`). The previously recorded commercial APK `2.0.3+13` is release-signed with certificate SHA-256 fingerprint `7B:9C:F1:1E:AF:AB:48:01:BE:68:21:D6:92:ED:AE:34:75:61:8F:CB:51:BE:21:86:B0:F5:86:6B:24:41:88:1A`. Android does not allow an APK signed by a different certificate to update an installed package in place; installing this debug candidate over the commercial build requires uninstalling the prior package first, which clears app-private secure storage and Android Keystore data. Therefore the missing V3 record is consistent with the install transition and does not establish a defect in the save routine.
- The online login flow on the currently installed build calls `LaminOfflineCredentialStore.save()`, then verifies `hasCredential()` and password/device binding before marking preparation ready. A fresh successful online login on this exact installed candidate is required to enroll its new secure-storage record and Keystore key. The earlier online login performed on the prior installation cannot survive an uninstall.
- Do not ask the user to clear app data or uninstall again. To preserve an existing installation's credentials in future updates, distribute a candidate signed with the same release certificate; the current CI development candidate is debug-signed and is not suitable as an in-place update to the commercial release.
- No code change was made in response to this diagnostic screenshot. The diagnosis is a missing record after installation; on-device enrollment after the latest install remains unverified.


## ROOT CAUSE CONFIRMED: LOGOUT DELETED OFFLINE CREDENTIAL — 2026-11-06

- User's latest reproduction establishes: closing/reopening the app without logging out preserves offline access; performing explicit logout makes offline login fail with `لا يوجد سجل اعتماد V3`.
- Source inspection found the direct cause in `lib/main.dart` `logout()`: before local Supabase sign-out, it called `LaminOfflineCredentialStore().remove(offlineUserId)` and deleted secure-storage key `lamin.offline.user.id`. The offline-login path requires the V3 identity record and repopulates the remembered user ID after successful password and Android Keystore verification. Thus the logout handler itself erased the data required by the next offline login. This is a confirmed code-path cause, not an inference from the earlier debug/release signing difference.
- Fixed in commit `c7991dce1279ff97e3693de0305fe26dc1144b97`: explicit logout now ends only the local Supabase authenticated session and retains the device-bound offline credential and remembered user ID. Offline access remains gated by the saved password verifier, school/account status and Android Keystore proof. No server session, Supabase data, production configuration, secrets, or signing material is modified.
- Expected behavior after this change: normal app close/reopen remains as before; explicit logout returns to login but preserves offline enrollment, allowing the user to select “متابعة دون اتصال” and authenticate with the enrolled password on the same device.
- CI/build for this fix has not yet been verified at the time of this note. Do not ask the user to repeat tests on the old APK. Test the new candidate built from this commit: online login once if needed to enroll, explicit logout, disable internet, then offline login. Verify that the V3 record persists after logout and offline access succeeds.


## USER-VERIFIED OFFLINE LOGOUT/LOGIN ACCEPTANCE — 2026-11-07

- User explicitly confirmed on the newly built candidate that **offline login succeeds after the explicit logout flow**. This closes the previously reported blocker where logout() deleted lamin.offline.identity.v3 and lamin.offline.user.id.
- Fix commit: c7991dce1279ff97e3693de0305fe26dc1144b97. This handover update is documentation-only; current HEAD before this update: 545f0d79d32cf3de7c06f91696feb2eb008471ae.
- All four GitHub Actions workflows completed successfully for fix source commit c7991dce1279ff97e3693de0305fe26dc1144b97:
  - Development validation 42273016806: SUCCESS (attempt 2); Flutter format, static analysis, automated tests, Android candidate build, APK signature/package verification, and artifact upload passed.
  - Portal validation 42273016742: SUCCESS.
  - Schema baseline acceptance 42273016776: SUCCESS.
  - RPC security ACL regression 42273016813: SUCCESS.
- Development APK artifact: lamin-development-candidate, artifact ID 13532018150, 29,249,980 bytes, from https://github.com/laminahmed12/school-mobile-app/actions/runs/42273016806. This is a debug-signed validation APK, not the commercial release artifact.
- PR #22 remains open and unmerged.

## COMMERCIAL RELEASE GATES STILL OPEN — 2026-11-07

1. Physical-device regression pass: explicit logout -> offline login is now user-confirmed passed; still verify cold start after force-close in airplane mode, incorrect offline password rejection, biometric lock/unlock, valid and expired license/trial states, reconnect and queued-operation replay, and long-operation/loading behavior. Earlier handover records unresolved cold-start airplane-mode, slow replay/read operations, and restore/export acceptance; close each with actual device results.
2. Archive lifecycle: verify archive/list/search/restore for students, teachers, and staff against the target Supabase environment; prove no duplicates or relationship/data loss. General schema/RPC CI passed, but a dedicated archive regression test suite is still absent.
3. Supabase production schema state: migration supabase/migrations/20261104000000_archive_only_no_hard_delete.sql is in the repository, but its deployment to production Supabase has not been verified. Do not apply it to production without controlled approval and a backup/rollback plan.
4. Backup and recovery: complete a real backup export and restore test on-device, including recovery of related data; previous acceptance remains outstanding.
5. Performance and sync integrity: measure and resolve previously observed long waits (offline replay timeouts around 15–20 seconds and sequential financial reads); test retry/idempotency and no duplicate writes after connectivity returns.
6. Release workflow configuration: .github/workflows/release-signed-apk.yml requires the established signing secrets LAMIN_KEYSTORE_BASE64, LAMIN_KEYSTORE_PASSWORD, LAMIN_KEY_ALIAS, LAMIN_KEY_PASSWORD and repository variable GOOGLE_SERVER_CLIENT_ID. Values must not be exposed. Presence/validity is checked by the release workflow itself; this session did not inspect or change secrets and did not run commercial signing.
7. Release identity and version: preserve package com.adreemk.school.lamin_school and the existing release certificate fingerprint recorded above. Before signing, select a versionCode greater than every APK already distributed (current source version 2.0.3+15; prior handover warns +14/+15 candidates may already have been handed out). Build and verify install-over-existing update with the same release certificate. Never substitute the debug signing certificate.
8. Final release acceptance: once gates 1–7 are closed, obtain explicit go-ahead for commercial release, run the existing manual Build signed Lamin release APK workflow against the approved commit, verify certificate fingerprint/package/version/SHA-256, and perform final install/update and smoke test. Do not merge PR #22 or publish a release without explicit authorization.

- No production database, release secret, signing material, PR merge, or commercial release was changed or performed while recording this acceptance result.


## FOLLOW-UP TEST ACCESS CHECK — 2026-11-07

- Confirmed the connected Supabase account still lists the isolated staging project `Lamin-Test` (`iijngozcfzskhvxrmlwi`) as `ACTIVE_HEALTHY`; production `School-Management` was not selected or modified.
- Attempted read-only inspection of Lamin-Test migrations and tables, then a non-mutating `SELECT current_database(), current_user, current_setting('server_version')`. The Supabase connector woke the project, but database operations failed with PostgreSQL `28P01 password authentication failed` for `postgres` / `supabase_read_only_user`. No SQL changes or test data writes were executed. This is a connector/database credential failure, not evidence of an application defect.
- Current branch HEAD before this note: `ebc0d15b9a002ee3663055d9932b36f8c2da82ee`. On that HEAD, portal validation `42316907382`, schema baseline acceptance `42316907377`, and RPC security ACL regression `42316907423` completed successfully. Development validation `42316907375` was still building/verifying the debug candidate at inspection time; run URL: https://github.com/laminahmed12/school-mobile-app/actions/runs/42316907375.
- The schema baseline workflow runs against disposable PostgreSQL 17 CI databases; the current workflow does not yet apply the archive lifecycle migration or run archive-specific lifecycle assertions. Do not treat general schema/RPC CI as a dedicated archive test.
- This tool session has no attached Android emulator/device control. User-confirmed physical-device acceptance remains the source of truth for phone-only flows; CI can validate source, database routines and APK build/signature, but cannot independently exercise the user's installed Android app.

## Session update — 2026-11-07 archive lifecycle CI coverage

- Working branch HEAD at handover update: `51f0725cb9af5d63456f7022f5b646ddb4b37c68`.
- Added `test/sql/validate_archive_lifecycle.sql` to exercise the archive-only migration against disposable PostgreSQL: archive/list/restore for students, teachers, and staff; search; invalid reason rejection; cross-school isolation; accountant role denial; authenticated DELETE privilege/policy removal; archive RPC ACL; staff insert/update policy continuity; and preservation of underlying rows.
- Updated `.github/workflows/lamin-schema-baseline-acceptance.yml` to apply `20261104000000_archive_only_no_hard_delete.sql` and execute the dedicated lifecycle test after the existing schema/idempotency validations. This workflow uses its own ephemeral PostgreSQL service; no Supabase project was modified.
- Intermediate workflow commit `becf0d08fbc34a78ef91d8d2e14964e712f4e01b` triggered CI before a test ACL assertion was corrected. The correction is included in HEAD `51f0725...`; only runs whose `head_sha` exactly matches this final HEAD count as validation.
- PR #22 was verified OPEN and UNMERGED; no changes to `main`, production Supabase, secrets, or release signing.
- Earlier CI on `b8f5a07...`: portal validation, schema baseline, and RPC security ACL completed successfully; development validation was still in progress at last check. Recheck exact-HEAD runs and artifacts before reporting a final build result.
- Dedicated archive test and workflow changes are committed, but archive lifecycle behavior is NOT yet claimed passing until the run on HEAD `51f0725...` completes successfully.
- Supabase connector database login remained unavailable due PostgreSQL credential-authentication errors; no migrations or SQL writes were attempted against Lamin-Test or production. The archive test is instead being run on the disposable CI database.
- Physical Android acceptance remains pending. Keep signed release on hold; do not run release signing or remove the existing app from the user's phone.


---

# AUTHORITATIVE SESSION UPDATE — 2026-11-07 (latest; supersedes all earlier status entries)

## Verified repository state
- Repository: `laminahmed12/school-mobile-app`; project is Lamīn School / Supabase only.
- Active branch: `fix/lamin-portal-crud-offline-20261030`.
- Verified source HEAD before this documentation update: `d0547645a09f934179315ee839b02ee0669dff7b`.
- PR #22 remains OPEN and UNMERGED. No merge, retarget, or production change was made.
- App version in `pubspec.yaml`: `2.0.3+15`; package identity remains `com.adreemk.school.lamin_school` (candidate workflow's package/signature verification step passed).

## Authentication correction for unexpected dashboard reopening
- On cold start, a persisted Supabase session or cached profile is no longer treated as sufficient identity proof to enter the dashboard.
- Startup now displays the login form until an online authenticated session is established or the user completes the explicit offline credential flow.
- Offline credential flow continues to verify the supplied password against the device-bound PBKDF2/HMAC-SHA256 verifier, school/user identity, device binding, account and school activation, and licensing/trial conditions.
- A biometric lock remains enforced after successful authentication where enabled.
- Removed the obsolete cached auto-access eligibility calculation after static analysis identified it as unused.
- Tests in `test/offline_auth_preflight_test.dart` were updated to assert that restored sessions/cached profiles do not bypass explicit identity proof.
- This is code and CI validation. The user's phone must still confirm: logout -> login screen; force-close/reopen -> login screen; correct offline password -> access; incorrect password -> denied; biometric behavior.

## Exact GitHub Actions acceptance on HEAD `d0547645...`
All four workflows completed with SUCCESS:
- Lamin development validation: run `42391728754` — SUCCESS.
  - Dependency resolution, Dart formatting, format verification, `flutter analyze --no-pub --fatal-infos --fatal-warnings`, `flutter test), Android preparation, Android NDK `27.0.12077973`, Android candidate build, APK package/signature verification, signing-toolchain packaging, and artifact uploads all succeeded.
  - Run URL: https://github.com/laminahmed12/school-mobile-app/actions/runs/42391728754
- Lamin portal validation: run `42391728818` — SUCCESS.
- Lamin RPC security ACL regression: run `42391728890` — SUCCESS.
- Lamin schema baseline acceptance: run `42391728899` — SUCCESS; includes archive lifecycle migration and disposable PostgreSQL archive/list/restore, validation, tenant isolation, role denial, ACL, and no-hard-delete assertions.
- The previous long wait was caused by the Android NDK installation step. It eventually completed successfully; Android candidate build then completed successfully. No failure remains in these four runs.

## Candidate artifacts (not a commercial release)
- Candidate workflow run: `42391728754`.
- APK candidate artifact: `lamin-development-candidate`, artifact ID `13581718181`, archive SHA-256 digest `849f97b6619dcb198cd4b10cc711d3ee401cf5958e541d3b9d3924b492007433`.
- Signing toolchain artifact: `lamin-apksigner-toolchain`, artifact ID `13582261785`, archive SHA-256 digest `6878bb460a5975ce9bbc1ec0b8e593f00a188a32d58ffc17ee360a68faec5e64`.
- Candidate was built and passed workflow package/signature verification. It is a DEBUG-SIGNED TEST CANDIDATE, not a commercially signed release APK. Do not install it over an existing production-signed app unless Android confirms compatible signing; use a separate test installation/device or uninstall only with explicit user consent and after protecting local data.
- Artifact expiry at creation: candidate 2026-11-14T16:38:07Z; signing toolchain 2026-11-08T16:38:04Z. Download/archive and preserve the candidate artifact before expiry if it is needed later.
- No claim of physical-device validation is made. No release signing, secret access/change, Supabase project write, or production action was performed.

## Next acceptance
1. Download and preserve the verified candidate artifact before expiry if required.
2. Install it only in a safe test context compatible with its debug signature.
3. Verify logout and force-close/reopen both return to login; verify correct offline password succeeds and wrong password is rejected.
4. Keep PR #22 open. Commercial release still requires the established release certificate fingerprint, release workflow, version-code policy, and explicit authorization. Do not change signing identity or production.


---

# AUTHORIZATION REVIEW — 2026-11-07

- Corrected role boundary: `owner` is a global platform-owner identity, not a school administrator. The schema/bootstrap migration `20261016013326_fix_owner_school_bootstrap_scope_20261016.sql` explicitly requires owner profiles to have `school_id IS NULL`.
- Removed `owner` from school-admin UI capability checks and school finance totals. Only `admin` receives school-admin UI capabilities; `accountant` and `supervisor` remain separate roles.
- Global owner and any malformed school profile without a school scope are blocked from loading the school dashboard, cached school data, and remote school snapshot. The app presents a dedicated explanation and logout path to the separate PIN-protected Owner Console.
- Added `SchoolRoleAccess` capability helpers and unit coverage for owner/admin/accountant/supervisor separation.
- No SQL migration, Supabase project, production data, credentials, or secrets were changed. Existing SQL owner policies remain tenant-scoped; because global owner has no school_id, those policies do not grant access to a school's rows.
- Implementation commits on branch `fix/lamin-portal-crud-offline-20261030`: `67068452` (role capability model), `b938b762` (tests), `84a9c0ba` (UI isolation). Current HEAD: `84a9c0ba75afc14043d371d6d1c051b67cd7b7bd`.
- CI runs for current HEAD: development validation `42399611667` (queued), portal validation `42399611603` (validation steps passed; run finishing), schema baseline acceptance `42399611734` (queued), RPC security ACL regression `42399611871` (queued). Do not call the change verified until all finish successfully.
- Phone acceptance still required: sign in as a global owner and confirm school dashboard is never shown; sign out and enter Owner Console through the login-screen Adreemk triple-tap plus PIN; sign in as school admin and confirm normal school administration remains available.


## USER-REPORTED PHYSICAL-DEVICE ACCEPTANCE — 2026-11-08

- The user reports that all requested phone checks passed on the installed test candidate. Screenshots supplied show the Owner Center for school code `test` with trial status, a return to the school login screen, a successful school-admin dashboard session, and the archive screen listing teacher `Test102` with a restore action.
- User-confirmed checks: global owner remains in the Owner Center and does not enter the school dashboard; school admin can sign in and access the school dashboard; logout returns to the login screen; offline access/password checks passed; archive and restore checks for students, teachers, and staff passed; the user reports the complete checklist succeeded.
- Treat these as USER-REPORTED device acceptance, not independent device automation. The supplied screenshots corroborate the visible screens and archive entry; they do not independently prove every tap or offline condition.
- Owner Center shows 7 students while the school dashboard shows 6. This may reflect total versus active/non-archived counts; do not change code or data based on this difference without checking the intended count semantics.
- This update records the user's test result only. No application source, Supabase database, production environment, secrets, signing identity, or release workflow was changed. PR #22 remains OPEN and UNMERGED.
- Commercial release is still a separate gate: use the existing release certificate and approved signing workflow, verify the APK/version/package/fingerprint, and obtain explicit release authorization. A debug-signed candidate is not a commercial release.

---

# RELEASE WORKFLOW AUDIT — 2026-11-08 (latest)

- Audited the release workflow failure on run #12 (`42463578893`, source HEAD `1a8d821...`). Dependency resolution and signing configuration passed. The workflow failed at `flutter analyze`: 140 informational lint findings were elevated to fatal because the workflow generated Android platform files before analysis; this changed/generated the lint configuration before validation.
- Corrected `.github/workflows/release-signed-apk.yml` in commit `b2013cc5eac962925399d27765557ffdc99d69bc`: run dependency resolution, Dart formatting, static analysis with the repository's strict `--fatal-infos --fatal-warnings` policy, and Flutter tests before running `flutter create`. Android project generation and removal of Flutter's generated sample test now occur only after all Dart validation passes. This aligns validation ordering with the already-established successful development workflow; it does not weaken lint enforcement.
- Exact-HEAD CI on `b2013cc5eac962925399d27765557ffdc99d69bc`: development validation run `42463880074` SUCCESS (dependency resolution, format, strict analysis, tests, Android NDK install, candidate APK build, package/signature checks, artifact uploads); portal validation `42463880159` SUCCESS; schema baseline/archive lifecycle acceptance `42463880144` SUCCESS; RPC security ACL regression `42463880093` SUCCESS.
- Development candidate artifact `lamin-development-candidate`, artifact ID `13611271321`, archive SHA-256 `8440d2dfb3a2f6ebc6d2d8830ae7ae691e6696f5be41dd908021f8c8f2fc03`, expires 2026-11-15T08:45:45Z. It is a DEBUG-SIGNED test candidate, not a commercial release APK. Signing toolchain artifact `lamin-apksigner-toolchain`, artifact ID `13611396090`, expires 2026-11-09T08:45:43Z.
- Release workflow run #12 still failed on the previous commit; no run exists yet on `b2013cc...` because `release-signed-apk.yml` is `workflow_dispatch` only. The connected GitHub actions do not expose a workflow-dispatch action; the REST fetch integration is GET-only. A manual dispatch on this branch is still required to execute the corrected signed-release workflow.
- At this checkpoint PR #22 remains OPEN and UNMERGED. No production branch, Supabase project/data, secrets, or signing credentials were changed. The existing release certificate setup step passed in previous release attempts; a signed APK has not yet been produced.
---

# SIGNED RELEASE WORKFLOW FOLLOW-UP — 2026-11-08

- Release workflow run #13 (`42494726709`) failed at `Apply premium Lamin launcher icon and app name` because it attempted to edit `android/app/src/main/AndroidManifest.xml` before the Android platform directory existed. The workflow had moved Flutter validation before Android generation but left the Android resource/manifest customization steps ahead of generation.
- Fixed ordering in `.github/workflows/release-signed-apk.yml`, commit `152fc837a53c67cbe75da9bb0b264507360238bd`: dependency resolution, Dart format, strict static analysis, and Flutter tests now run first; Android platform files are generated next; then the sample test is removed and launcher resources, Android identity, release signing, OAuth validation, APK build, signature verification, and artifact upload run in order.
- Verified the committed workflow file and exact step order via GitHub API. No production branch, Supabase project/data, repository secrets, or signing identity was modified.
- Run #13 is a failed run on the previous workflow ordering. A new manual `workflow_dispatch` on branch `fix/lamin-portal-crud-offline-20261030` is required to execute commit `152fc837...`; the connected GitHub toolset exposes workflow-run reads and reruns but no dispatch action.
- No signed release APK has been produced yet. Previous exact-HEAD development CI checks passed, and a debug-signed candidate exists; neither substitutes for a signed release APK.

---

## Session update — 2026-11-08 (signed-release Gradle failure)

- Verified PR #22 remains OPEN / UNMERGED. Work remains only on `fix/lamin-portal-crud-offline-20261030`.
- Latest branch HEAD: `729f0dcabe3f9233cca241119e6f4b3fb1b4ca94`.
- Inspected failed signed-release run 42495521988 on prior HEAD `7bc18b703ebd7e726d0df157deaf8979f4056e6e`. Dependency resolution, Dart formatting, Flutter static analysis, and Flutter tests all passed; the release build then failed during Gradle Kotlin DSL compilation at generated `android/app/build.gradle.kts:11`: `java.util.Properties()` resolved `java` as a Gradle Kotlin DSL accessor, producing `Unresolved reference: util`. APK signature verification and artifact upload were skipped.
- Updated `.github/workflows/release-signed-apk.yml` to inject an explicit `import java.util.Properties` and instantiate `Properties()`, avoiding the Kotlin DSL name-resolution collision. Verified the corrected workflow text on the branch. This is a workflow-only change; generated Android platform files are still produced during CI.
- Commit `8230b978dd9c4641a9c4dc198e6b0cb6a876401f` was an intermediate workflow edit with an incorrectly escaped newline; immediately corrected in `729f0dcabe3f9233cca241119e6f4b3fb1b4ca94`. The current workflow contains the proper Python string escape `\\n` and was re-fetched for verification.
- Validation on HEAD `729f0dc...`: Lamin portal validation run 42495943380 SUCCESS. Development validation 42495943388, RPC security ACL 42495943367, and schema baseline 42495943445 were still in progress at handover; do not claim results until checked.
- No signed APK has been produced by the failed run. Signature verification, certificate fingerprint comparison, APK checksum, and artifact upload remain outstanding.
- The connected GitHub actions tools support reading runs and rerunning failed jobs but do not expose workflow_dispatch. Do not rerun the failed run because that would reuse the old workflow revision. To execute the corrected signed workflow, manually dispatch `.github/workflows/release-signed-apk.yml` from GitHub Actions with source_ref `fix/lamin-portal-crud-offline-20261030` after the pending validations finish.
- Preserve the established signing certificate and the existing release gates; do not change production, secrets, package identity, or PR merge state.


## Follow-up — 2026-11-08 signed-build retry diagnosis and correction

- The user's subsequent signed workflow run was `42496106562`, checked out HEAD `69d95e6c614e08d74fc3d92b460b91bafcb2b854`. It failed with the SAME Gradle error at generated `android/app/build.gradle.kts:12`: `val props = java.util.Properties()` / `Unresolved reference: util`.
- Root cause of the ineffective first correction: the Python workflow script called `s.replace("java.util.Properties()", "Properties()")` BEFORE injecting the signing-config Kotlin block. The injected block therefore reintroduced `java.util.Properties()` after the replacement had already run. The import alone did not change that expression's name resolution.
- Corrected the actual injected Kotlin template itself to use the imported `Properties()` constructor, and added a Python guard that aborts if the generated script still contains `java.util.Properties()` or lacks `val props = Properties()`.
- Verified the live workflow file on branch contains the corrected template and guard. Fix commit: `c8a6611bfbc08246cae97ec055a67a43e3dc5335`.
- CI for this fix HEAD: portal validation run 42496601452 SUCCESS. Development validation 42496601538, schema baseline 42496601371, and RPC security ACL 42496601369 were still running at the time of this note.
- The failed release run did not reach APK creation, signature verification, or artifact upload. No new signed APK is available yet. Dispatch the signed-release workflow against the corrected branch HEAD only after the pending validations complete; the failed run must not be rerun because it pins the old workflow revision.


## Signed APK result and stricter release gate — 2026-11-08

- Signed workflow run `42497018546` on source HEAD `5e6eab15e9ed3747b6ab22f927cbd9a69736898c` completed SUCCESS. Build, APK verification, and artifact upload all succeeded. Artifact: `lamin-signed-release-apk`, 29,249,211 bytes, retained until 2026-12-08. APK SHA-256: `a57a92b21d6c60e27c351b7f65b40035f7e1405439ec2915b1b7fbbdd239e380`.
- APK signer certificate SHA-256 exactly matched the approved existing Lamin certificate: `7b9cf11eafab4801be6821d692edae3475618fcb51be2186b0f5866b2441881a`. Package/build artifact is signed with the correct key.
- Important qualification: apksigner output showed V2=true, but V1=false and V3=false. Thus this artifact did NOT satisfy the PR's documented release gate requiring V1/V2/V3. Do not treat it as final accepted release APK or install it for acceptance testing yet.
- Tightened `.github/workflows/release-signed-apk.yml`: explicitly enable V1/V2/V3 on the release signing config, and fail verification unless all three schemes are reported true and the APK certificate SHA-256 matches the approved fingerprint. Verified workflow text after editing, including corrected shell newline escapes.
- Latest branch HEAD: `2260c16fb8f8e317fe5f960a3438e38c0ae973d5`. PR #22 remains open/unmerged. CI validations for this latest commit were queued/in progress at note time.
- Next action: after latest CI validations finish successfully, manually dispatch `Build signed Lamin release APK` using source_ref `fix/lamin-portal-crud-offline-20261030`. Only install the newly generated artifact if the stricter workflow passes V1/V2/V3 and certificate fingerprint checks. No production changes or secret changes were made.


## Follow-up — V1 signing failure and explicit final APK re-signing — 2026-11-08

- Inspected signed-release run `42499940364` and its logs. Gradle build succeeded; APK verification failed solely because V1/JAR signing was false while V2=true and V3=true. Certificate remained the approved Lamin SHA-256 `7b9cf11eafab4801be6821d692edae3475618fcb51be2186b0f5866b2441881a`.
- Root cause: setting Gradle `enableV1Signing = true` did not result in V1 signatures in the generated APK. The strict verifier correctly blocked artifact upload.
- Updated the verification step to explicitly invoke Android `apksigner sign` on the built APK with V1, V2, and V3 enabled, using the existing keystore and secrets via environment references (no secrets logged or changed). It replaces the final APK, then verifies all three schemes and the approved certificate fingerprint before upload.
- Latest branch HEAD: `cb9a14f1545dc25518b3e96b5328129fce2b8f17`. PR #22 remains open/unmerged. The workflow file was re-fetched and the explicit signing block verified. CI validation runs on this commit were queued at the time of this update.
- Do not install the earlier downloaded artifact: it failed the required V1/V2/V3 acceptance gate and was not uploaded by the failed run. Next: after CI passes, manually dispatch signed release workflow against the latest branch HEAD; confirm V1/V2/V3 true and certificate fingerprint matches before downloading/installing.
