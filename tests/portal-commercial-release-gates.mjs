import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const app = await readFile(new URL("../web/app.js", import.meta.url), "utf8");
const html = await readFile(new URL("../web/index.html", import.meta.url), "utf8");
const sw = await readFile(new URL("../web/sw.js", import.meta.url), "utf8");
const mobileRepository = await readFile(new URL("../lib/repository.dart", import.meta.url), "utf8");

function section(source, start, end) {
  const a = source.indexOf(start);
  assert.notEqual(a, -1, `missing section: ${start}`);
  const b = source.indexOf(end, a + start.length);
  assert.notEqual(b, -1, `missing section end: ${end}`);
  return source.slice(a, b);
}

// Large school datasets must be paginated; payment read failures must never become zero balances.
assert.match(app, /async function fetchAllRows\(table,columns/);
assert.match(app, /fetchAllRows\("payments","id,fee_assessment_id,amount,student_id,term,created_at"/);
assert.match(app, /if\(paymentsResult\.error\)throw paymentsResult\.error/);
assert.doesNotMatch(app, /from\("payments"\)\.select\("fee_assessment_id,amount"\)\.limit\(5000\)/);

// Every payment, online or offline, must use the atomic, idempotent ledger RPC.
const paymentForm = section(app, '$("payment-form").addEventListener("submit"', '$("export-fees").addEventListener');
assert.match(paymentForm, /db\.rpc\("record_student_payment",\s*params\)/);
assert.match(paymentForm, /action:"rpc_payment"/);
assert.match(paymentForm, /p_idempotency_key:idempotencyKey/);
assert.doesNotMatch(paymentForm, /from\(["']payments["']\)\.insert/);
assert.match(app, /op\.action==="rpc_payment"\) result=await db\.rpc\("record_student_payment",op\.params\)/);
assert.match(app, /if\(result\.error\).*?writeOfflineQueue\(remaining\)/s);

// Queue restore must render pending local payments without generating a second operation.
assert.match(app, /if \(op\.action === "rpc_payment"\)/);
assert.match(app, /allowedActions=new Set\(\["insert","update","archive","rpc_student","rpc_payment","upsert"\]\)/);
assert.match(app, /!state\.payments\.some\(p=>p\.id===op\.local_id\)/);

// Mobile and portal payments must use the ledger RPC; direct table inserts bypass allocations.
assert.match(mobileRepository, /db\.rpc\(\x27record_student_payment\x27/);
assert.doesNotMatch(mobileRepository, /from\(\x27payments\x27\)\.insert/);
assert.match(mobileRepository, /p_idempotency_key/);

// Offline login stores a PBKDF2 verifier, not the raw password.
assert.match(app, /PBKDF2/);
assert.match(app, /deriveOfflineVerifier\(password,saltText\)/);
assert.doesNotMatch(app, /localStorage\.setItem\([^\n]*password\s*[,)]/i);

// Offline backup is school-scoped and local restore does not call the server restore RPC.
assert.match(app, /envelope\.school_id\)!==String\(state\.school\.id\)/);
assert.match(app, /__localOfflineBackup/);
assert.match(app, /localStorage\.setItem\(OFFLINE_SNAPSHOT_PREFIX\+state\.school\.id/);

// Search is available near the start of the student panel and date controls use the explicit format.
const studentsPanel = section(html, 'id="panel-students"', 'id="panel-');
assert.ok(studentsPanel.indexOf('id="student-search"') < studentsPanel.indexOf('id="students-table"'));
assert.match((await readFile(new URL("../web/reminders.js", import.meta.url), "utf8")), /DD\/MM\/YYYY HH:MM|DD\\\/MM/);
assert.match(sw, new RegExp("lamin-portal-shell-v[0-9]+"));

console.log("Commercial release static gates passed.");
