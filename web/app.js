import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

// The publishable key is intended for browser clients. Database access remains
// protected by Supabase Auth, RLS, and the server-side RPC permission checks.
const SUPABASE_URL = "https://stbrhcgzfxvpayfnnqfl.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR";
const db = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});
const $ = (id) => document.getElementById(id);
const state = { profile: null, school: null, students: [], teachers: [], attendance: [], results: [], assessments: [], audit: [], expenses: [], payroll: [], backup: null, backupFileName: "" };
const money = (value) => new Intl.NumberFormat("ar-LY", { style: "currency", currency: "LYD", maximumFractionDigits: 2 }).format(Number(value || 0));
const showMessage = (id, message, error = false) => { const el = $(id); el.textContent = message || ""; el.classList.toggle("error", error); };
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const safeRows = (rows) => Array.isArray(rows) ? rows : [];
function switchView(authed) {
  $("login-view").classList.toggle("hidden", authed);
  $("app-view").classList.toggle("hidden", !authed);
  $("logout").classList.toggle("hidden", !authed);
}
function switchPanel(name) {
  document.querySelectorAll(".tab").forEach((b) => b.classList.toggle("active", b.dataset.panel === name));
  document.querySelectorAll(".tab-panel").forEach((p) => p.classList.toggle("hidden", p.id !== `panel-${name}`));
}
function csvDownload(filename, rows) {
  const text = "\uFEFF" + rows.map((row) => row.map((v) => '"' + String(v ?? "").replace(/"/g, '""') + '"').join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a"); a.href = url; a.download = filename; a.click(); URL.revokeObjectURL(url);
}
const REMEMBER_LOGIN_KEY = "lamin-portal-remember-login-v1";
function restoreRememberedLogin() {
  try {
    const saved = JSON.parse(localStorage.getItem(REMEMBER_LOGIN_KEY) || "null");
    if (!saved || typeof saved !== "object") return;
    $("school-code").value = typeof saved.school === "string" ? saved.school : "";
    $("username").value = typeof saved.username === "string" ? saved.username : "";
    $("remember-login").checked = Boolean(saved.school || saved.username);
  } catch { /* Browser storage may be disabled. */ }
}
function saveRememberedLogin() {
  try {
    if ($("remember-login").checked) {
      localStorage.setItem(REMEMBER_LOGIN_KEY, JSON.stringify({ school: $("school-code").value.trim(), username: $("username").value.trim() }));
    } else localStorage.removeItem(REMEMBER_LOGIN_KEY);
  } catch { showMessage("login-message", "تم تسجيل الدخول، لكن المتصفح لم يسمح بحفظ بيانات التذكّر.", true); }
}
$("remember-login")?.addEventListener("change", () => {
  if (!$("remember-login").checked) { try { localStorage.removeItem(REMEMBER_LOGIN_KEY); } catch {} }
});
restoreRememberedLogin();

function restoreOfflinePortal() {
  try {
    const candidates = Object.keys(localStorage).filter(key => key.startsWith(OFFLINE_SNAPSHOT_PREFIX));
    if (!candidates.length) return false;
    const snapshots = candidates.map(key => ({ key, value: JSON.parse(localStorage.getItem(key) || "null") })).filter(x => x.value?.profile && x.value?.school && x.value?.data);
    const cached = snapshots.sort((a,b) => new Date(b.value.savedAt)-new Date(a.value.savedAt))[0]?.value;
    if (!cached) return false;
    state.profile = cached.profile; state.school = cached.school;
    Object.assign(state, cached.data); state.offline = true;
    $("school-name").textContent = state.school.name || "مدرستك";
    $("setting-school-name").textContent = state.school.name || "—";
    $("setting-school-code").textContent = state.school.code || "—";
    $("setting-school-currency").textContent = state.school.currency || "LYD";
    $("setting-role").textContent = state.profile.role || "—";
    $("session-label").textContent = (state.profile.username || "مستخدم") + " · " + (state.profile.role || "مستخدم");
    $("today-label").textContent = "وضع عدم الاتصال";
    switchView(true); switchPanel("overview"); setOfflineMode(true);
    const metrics = cached.metrics || {};
    for (const [id,value] of Object.entries(metrics)) if ($(id)) $(id).textContent = value;
    const studentNames = new Map(state.students.map(s => [s.id,s.name]));
    $("students-table").innerHTML = state.students.map(s => `<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone)}</td></tr>`).join("") || '<tr><td colspan="3">لا توجد سجلات محفوظة.</td></tr>';
    $("teachers-table").innerHTML = state.teachers.map(t => `<tr><td>${escapeHtml(t.name)}</td><td>${escapeHtml(t.subject)}</td><td>${escapeHtml(t.phone)}</td><td>${escapeHtml(t.salary == null ? "—" : money(t.salary))}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات محفوظة.</td></tr>';
    $("attendance-table").innerHTML = state.attendance.map(a => `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.attendance_date)}</td><td>${escapeHtml(a.status)}</td><td>${escapeHtml(a.minutes_late ?? 0)}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات محفوظة.</td></tr>';
    $("results-table").innerHTML = state.results.map(r => `<tr><td>${escapeHtml(studentNames.get(r.student_id)||"طالب")}</td><td>${escapeHtml(r.exam_name)}</td><td>${escapeHtml(r.term)}</td><td>${escapeHtml(r.score)}</td><td>${escapeHtml(r.max_score)}</td></tr>`).join("") || '<tr><td colspan="5">لا توجد نتائج محفوظة.</td></tr>';
    const paidByAssessment = new Map();
    for (const p of state.payments || []) if (p.fee_assessment_id) paidByAssessment.set(p.fee_assessment_id, (paidByAssessment.get(p.fee_assessment_id)||0)+Number(p.amount||0));
    $("fees-table").innerHTML = state.assessments.map(a => { const fee=Number(a.total_fee||0), discount=Number(a.discount||0), paid=paidByAssessment.get(a.id)||0, balance=Math.max(0,fee-discount-paid); return `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.academic_year_label)}</td><td>${escapeHtml(a.term)}</td><td>${escapeHtml(money(fee))}</td><td>${escapeHtml(money(discount))}</td><td>${escapeHtml(money(paid))}</td><td>${escapeHtml(money(balance))}</td></tr>`; }).join("") || '<tr><td colspan="7">لا توجد رسوم محفوظة.</td></tr>';
    $("audit-table").innerHTML = state.audit.map(a => `<tr><td>${escapeHtml(a.created_at)}</td><td>${escapeHtml(a.username)}</td><td>${escapeHtml(a.action)}</td><td>${escapeHtml(a.entity)}</td><td>${escapeHtml(JSON.stringify(a.details||{}))}</td></tr>`).join("") || '<tr><td colspan="5">لا يوجد سجل محفوظ.</td></tr>';
    showMessage("app-message", "عرض نسخة محفوظة بتاريخ " + new Date(cached.savedAt).toLocaleString("ar-LY") + ". لا يمكن حفظ تغييرات جديدة دون اتصال.");
    return true;
  } catch (error) { console.error("Lamin offline restore failed", error); return false; }
}
async function login(event) {
  event.preventDefault();
  if (!navigator.onLine) {
    if (restoreOfflinePortal()) return;
    showMessage("login-message", "لا يمكن تسجيل الدخول لأول مرة دون إنترنت. افتح البوابة واتصل بالإنترنت وسجّل الدخول مرة واحدة أولًا.", true);
    return;
  }
  showMessage("login-message", "جارٍ التحقق من بيانات الدخول…");
  const form = new FormData(event.currentTarget);
  try {
    const { data, error } = await db.functions.invoke("auth-login", { body: { school: String(form.get("school")).trim(), username: String(form.get("username")).trim(), password: String(form.get("password")) } });
    if (error) throw error;
    if (!data?.refresh_token) throw new Error("استجابة الدخول غير مكتملة.");
    const { error: sessionError } = await db.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token });
    if (sessionError) throw sessionError;
    saveRememberedLogin();
    $("password").value = "";
    await loadPortal();
  } catch (error) {
    console.error("Lamin portal login failed", error);
    showMessage("login-message", error?.message || "تعذر تسجيل الدخول. تحقق من البيانات وحاول مجددًا.", true);
  }
}
async function loadPortal() {
  showMessage("app-message", "جارٍ تحميل بيانات المدرسة حسب الصلاحيات…");
  const user = (await db.auth.getUser()).data.user;
  if (!user) { switchView(false); return; }
  const { data: profile, error: profileError } = await db.from("profiles").select("user_id,username,role,active,school_id").eq("user_id", user.id).maybeSingle();
  if (profileError) throw profileError;
  if (!profile || !profile.active || !profile.school_id) throw new Error("الحساب غير مرتبط بمدرسة فعالة.");
  state.profile = profile;
  const { data: school, error: schoolError } = await db.from("schools").select("id,name,code,currency").eq("id", profile.school_id).maybeSingle();
  if (schoolError) throw schoolError;
  state.school = school;
  $("school-name").textContent = school?.name || "مدرستك";
  $("setting-school-name").textContent = school?.name || "—";
  $("setting-school-code").textContent = school?.code || "—";
  $("setting-school-currency").textContent = school?.currency || "LYD";
  $("setting-role").textContent = profile.role || "—";
  $("session-label").textContent = `${profile.username || user.email || "مستخدم"} · ${profile.role || "مستخدم"}`;
  $("today-label").textContent = new Intl.DateTimeFormat("ar-LY", { dateStyle: "full" }).format(new Date());
  switchView(true); switchPanel("overview");
  await refreshDashboard();
  showMessage("app-message", "");
}
async function getCount(table) {
  const { count, error } = await db.from(table).select("id", { count: "exact", head: true });
  if (error) throw error;
  return count ?? 0;
}
async function sumColumn(table, column, filter = null) {
  // Page through every row so large schools do not get silently truncated at
  // Supabase's per-request row limit and display misleading financial totals.
  const pageSize = 500;
  let offset = 0;
  let total = 0;
  while (true) {
    let query = db.from(table).select(column).range(offset, offset + pageSize - 1);
    if (filter) query = filter(query);
    const { data, error } = await query;
    if (error) throw error;
    const rows = safeRows(data);
    total += rows.reduce((sum, row) => sum + Number(row[column] || 0), 0);
    if (rows.length < pageSize) break;
    offset += pageSize;
  }
  return total;
}
async function refreshDashboard() {
  showMessage("app-message", "جارٍ تحديث الملخص…");
  try {
    const [studentsCount, teachersCount, classesCount, payments, expenses, payroll] = await Promise.all([
      getCount("students"), getCount("teachers"), getCount("classes"),
      sumColumn("payments", "amount"), sumColumn("expenses", "amount"), sumColumn("payroll_transactions", "amount"),
    ]);
    $("count-students").textContent = studentsCount.toLocaleString("ar-LY");
    $("count-teachers").textContent = teachersCount.toLocaleString("ar-LY");
    $("count-classes").textContent = classesCount.toLocaleString("ar-LY");
    $("total-payments").textContent = money(payments);
    $("total-expenses").textContent = money(expenses + payroll);
    $("finance-payments").textContent = money(payments);
    $("finance-expenses").textContent = money(expenses);
    $("finance-payroll").textContent = money(payroll);
    const [studentsResult, teachersResult, attendanceResult, resultsResult, assessmentsResult, auditResult, expensesResult, payrollResult] = await Promise.all([
      db.from("students").select("id,name,class_name,phone,active,status").order("name").limit(1000),
      db.from("teachers").select("id,name,subject,phone,salary").order("name").limit(1000),
      db.from("attendance").select("student_id,attendance_date,status,minutes_late").order("attendance_date",{ascending:false}).limit(1000),
      db.from("student_results").select("student_id,term,exam_name,score,max_score,created_at").order("created_at",{ascending:false}).limit(1000),
      db.from("student_fee_assessments").select("id,student_id,academic_year_label,term,total_fee,discount,note").limit(2000),
      db.from("audit_log").select("created_at,username,action,entity,details").order("created_at",{ascending:false}).limit(500),
      db.from("expenses").select("title,category,amount,created_at").order("created_at",{ascending:false}).limit(1000),
      db.from("payroll_transactions").select("transaction_type,amount,payment_date,note").order("payment_date",{ascending:false}).limit(1000),
    ]);
    const results = [studentsResult,teachersResult,attendanceResult,resultsResult,assessmentsResult,auditResult,expensesResult,payrollResult];
    const labels = ["الطلاب","المعلمون","الحضور","النتائج","الرسوم","التدقيق","المصروفات","الرواتب"];
    results.forEach((r,i)=>{ if(r.error) console.warn("Lamin portal optional dataset unavailable:",labels[i],r.error.message); });
    state.students = safeRows(studentsResult.data); state.teachers = safeRows(teachersResult.data);
    state.attendance = safeRows(attendanceResult.data); state.results = safeRows(resultsResult.data);
    state.assessments = safeRows(assessmentsResult.data); state.audit = safeRows(auditResult.data);
    state.expenses = safeRows(expensesResult.data); state.payroll = safeRows(payrollResult.data);
    const studentNames = new Map(state.students.map(s=>[s.id,s.name]));
    $("students-table").innerHTML = state.students.map((s) => `<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone)}</td></tr>`).join("") || '<tr><td colspan="3">لا توجد سجلات متاحة.</td></tr>';
    $("teachers-table").innerHTML = state.teachers.map((t) => `<tr><td>${escapeHtml(t.name)}</td><td>${escapeHtml(t.subject)}</td><td>${escapeHtml(t.phone)}</td><td>${escapeHtml(t.salary == null ? "—" : money(t.salary))}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات متاحة.</td></tr>';
    $("attendance-table").innerHTML = state.attendance.map(a=>`<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.attendance_date)}</td><td>${escapeHtml(a.status)}</td><td>${escapeHtml(a.minutes_late ?? 0)}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات متاحة أو لا تسمح الصلاحيات بعرضها.</td></tr>';
    $("results-table").innerHTML = state.results.map(r=>`<tr><td>${escapeHtml(studentNames.get(r.student_id)||"طالب")}</td><td>${escapeHtml(r.exam_name)}</td><td>${escapeHtml(r.term)}</td><td>${escapeHtml(r.score)}</td><td>${escapeHtml(r.max_score)}</td></tr>`).join("") || '<tr><td colspan="5">لا توجد نتائج متاحة.</td></tr>';
    const paidByAssessment = new Map();
    const paymentsResult = await db.from("payments").select("fee_assessment_id,amount").limit(5000);
    if (!paymentsResult.error) for(const p of safeRows(paymentsResult.data)) if(p.fee_assessment_id) paidByAssessment.set(p.fee_assessment_id,(paidByAssessment.get(p.fee_assessment_id)||0)+Number(p.amount||0));
    let totalFees=0,totalDiscount=0,totalPaid=0;
    $("fees-table").innerHTML = state.assessments.map(a=>{const fee=Number(a.total_fee||0),discount=Number(a.discount||0),paid=paidByAssessment.get(a.id)||0,balance=Math.max(0,fee-discount-paid);totalFees+=fee;totalDiscount+=discount;totalPaid+=paid;return `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.academic_year_label)}</td><td>${escapeHtml(a.term)}</td><td>${escapeHtml(money(fee))}</td><td>${escapeHtml(money(discount))}</td><td>${escapeHtml(money(paid))}</td><td>${escapeHtml(money(balance))}</td>${["admin","owner","accountant"].includes(state.profile?.role) ? `<td><button class="button button-secondary" type="button" data-fee-edit="${escapeHtml(a.id)}">تعديل</button></td>` : ""}</tr>`;}).join("") || '<tr><td colspan="7">لا توجد تقديرات رسوم متاحة.</td></tr>';
    $("fees-total").textContent=money(totalFees); $("fees-paid").textContent=money(totalPaid); $("fees-balance").textContent=money(Math.max(0,totalFees-totalDiscount-totalPaid));
    $("audit-table").innerHTML = state.audit.map(a=>`<tr><td>${escapeHtml(a.created_at)}</td><td>${escapeHtml(a.username)}</td><td>${escapeHtml(a.action)}</td><td>${escapeHtml(a.entity)}</td><td>${escapeHtml(JSON.stringify(a.details||{}))}</td></tr>`).join("") || '<tr><td colspan="5">لا يوجد سجل تدقيق متاح أو لا تسمح الصلاحيات بعرضه.</td></tr>';
    showMessage("app-message", "تم تحديث البيانات المتاحة. قد تكون بعض الأقسام فارغة إذا كانت صلاحيات قاعدة البيانات تمنع قراءتها.");
  } catch (error) {
    console.error("Lamin dashboard read failed", error);
    showMessage("app-message", "تعذر تحميل بعض البيانات. تحقق من صلاحيات قاعدة البيانات؛ لم تُغيّر أي بيانات.", true);
  }
}
async function createBackup() {
  const button = $("create-backup"); button.disabled = true; showMessage("backup-status", "جارٍ إنشاء النسخة والتحقق منها…");
  try {
    const role = state.profile?.role;
    const result = role === "owner"
      ? await db.rpc("export_backup", { p_school: state.school.id })
      : await db.rpc("export_backup");
    if (result.error) throw result.error;
    const data = result.data;
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("استجابة النسخ الاحتياطي غير صالحة.");
    const schoolFilter = data.school_filter ?? data.school_id;
    if (String(schoolFilter ?? "") !== String(state.school.id)) throw new Error("رفض التنزيل لأن النسخة لا تؤكد تطابق المدرسة.");
    const envelope = { format: "lamin-school-backup", version: 2, school_id: state.school.id, school_code: state.school.code, school_name: state.school.name, created_at: new Date().toISOString(), data };
    const text = JSON.stringify(envelope, null, 2);
    const parsed = JSON.parse(text);
    if (parsed.format !== "lamin-school-backup" || parsed.version !== 2 || parsed.school_id !== state.school.id || parsed.data.school_filter !== state.school.id) throw new Error("فشل التحقق النهائي من ملف النسخة.");
    const url = URL.createObjectURL(new Blob([text], { type: "application/json;charset=utf-8" }));
    const a = document.createElement("a"); a.href = url; a.download = `lamin_${new Date().toISOString().slice(0,10)}_${String(state.school.code || "school").replace(/[^\w-]/g,"_")}.json`; a.click(); URL.revokeObjectURL(url);
    showMessage("backup-status", "تم إنشاء الملف والتحقق من هوية المدرسة وبنية النسخة قبل التنزيل.");
  } catch (error) {
    console.error("Lamin backup failed", error);
    showMessage("backup-status", error?.message || "تعذر إنشاء نسخة احتياطية.", true);
  } finally { button.disabled = false; }
}
async function inspectBackup(file) {
  state.backup = null; state.backupFileName = ""; $("restore-backup").disabled = true; $("restore-confirm").value = ""; $("backup-preview").classList.add("hidden");
  if (!file) return;
  try {
    if (file.size > 100 * 1024 * 1024) throw new Error("حجم الملف يتجاوز الحد الآمن البالغ 100 ميغابايت.");
    const envelope = JSON.parse(await file.text());
    if (!envelope || envelope.format !== "lamin-school-backup" || envelope.version !== 2 || !envelope.data || typeof envelope.data !== "object") throw new Error("تنسيق النسخة غير مدعوم.");
    if (String(envelope.school_id) !== String(state.school.id) || String(envelope.data.school_filter) !== String(state.school.id)) throw new Error("هذه النسخة لا تخص المدرسة المسجّلة حاليًا.");
    state.backup = envelope; state.backupFileName = file.name;
    const preview = $("backup-preview"); preview.classList.remove("hidden");
    preview.innerHTML = `<strong>تم اجتياز الفحص الأولي</strong><br>الملف: ${escapeHtml(file.name)}<br>المدرسة: ${escapeHtml(envelope.school_name)}<br>تاريخ النسخة: ${escapeHtml(envelope.created_at)}<br>الإصدار: ${envelope.version}<br><span class="muted">هذه مراجعة بنيوية وليست اختبار استعادة كاملًا.</span>`;
    showMessage("restore-status", "الملف مطابق لهوية المدرسة. راجع التفاصيل واكتب استعادة للمتابعة.");
    updateRestoreButton();
  } catch (error) { showMessage("restore-status", error?.message || "تعذر قراءة الملف.", true); }
}
function updateRestoreButton() {
  $("restore-backup").disabled = !(state.backup && $("restore-confirm").value.trim() === "استعادة");
}
async function restoreBackup() {
  if (!state.backup || $("restore-confirm").value.trim() !== "استعادة") return;
  if (state.profile?.role !== "admin") { showMessage("restore-status", "الاستعادة متاحة لمدير المدرسة فقط وفق صلاحيات الخادم.", true); return; }
  const btn = $("restore-backup"); btn.disabled = true;
  showMessage("restore-status", "جارٍ إرسال النسخة إلى إجراء الاستعادة المحمي على الخادم…");
  try {
    // The server-side RPC remains authoritative for authorization, schema checks,
    // school scope, audit logging and transactional safety.
    const { data, error } = await db.rpc("restore_backup", { p_backup: state.backup.data });
    if (error) throw error;
    if (!data || typeof data !== "object") throw new Error("لم يُرجع الخادم تأكيدًا صالحًا للاستعادة.");
    showMessage("restore-status", "اكتملت استجابة الخادم. أعد تحميل اللوحة للتحقق من البيانات.");
    await refreshDashboard();
  } catch (error) {
    console.error("Lamin restore failed", error);
    showMessage("restore-status", error?.message || "رفض الخادم الاستعادة أو تعذر إتمامها. لم نعتبر العملية ناجحة.", true);
  } finally { updateRestoreButton(); }
}
$("login-form").addEventListener("submit", (e) => login(e).catch((err) => { console.error(err); showMessage("login-message", "تعذر تحميل البوابة.", true); }));
$("logout").addEventListener("click", async () => { await db.auth.signOut(); state.profile = state.school = null; switchView(false); $("session-label").textContent = ""; });
document.querySelectorAll(".tab").forEach((button) => button.addEventListener("click", () => switchPanel(button.dataset.panel)));
$("refresh-dashboard").addEventListener("click", () => { if (!navigator.onLine) { showMessage("app-message", OFFLINE_MODE_MESSAGE, true); return; } refreshDashboard(); });
$("create-backup").addEventListener("click", () => { if (state.offline || !navigator.onLine) { showMessage("backup-status", OFFLINE_MODE_MESSAGE, true); return; } createBackup(); });
$("backup-file").addEventListener("change", (e) => inspectBackup(e.target.files?.[0]));
$("restore-confirm").addEventListener("input", updateRestoreButton);
$("restore-backup").addEventListener("click", () => { if (state.offline || !navigator.onLine) { showMessage("restore-status", OFFLINE_MODE_MESSAGE, true); return; } restoreBackup(); });
$("export-students").addEventListener("click", () => csvDownload("lamin-students.csv", [["الاسم","الصف","الهاتف","الحالة"], ...state.students.map((s) => [s.name, s.class_name, s.phone, s.status])]));
$("export-attendance").addEventListener("click", () => csvDownload("lamin-attendance.csv", [["الطالب","التاريخ","الحالة","التأخير بالدقائق"], ...state.attendance.map((a) => [state.students.find(s=>s.id===a.student_id)?.name||"",a.attendance_date,a.status,a.minutes_late])]));
const feeForm = $("fee-edit-form");
$("fees-table").addEventListener("click", event => {
  const button = event.target.closest("[data-fee-edit]");
  if (!button) return;
  if (state.offline || !navigator.onLine) { showMessage("fee-edit-status", "تعديل الرسوم يتطلب اتصالًا بالإنترنت.", true); return; }
  if (!["admin","owner","accountant"].includes(state.profile?.role)) { showMessage("app-message", "ليست لديك صلاحية تعديل الرسوم.", true); return; }
  const item = state.assessments.find(a => String(a.id) === button.dataset.feeEdit);
  if (!item) return;
  $("fee-edit-id").value = item.id;
  $("fee-edit-student").textContent = (state.students.find(s => s.id === item.student_id)?.name || "طالب") + " · " + (item.academic_year_label || "") + " · " + (item.term || "");
  $("fee-edit-total").value = Number(item.total_fee || 0);
  $("fee-edit-discount").value = Number(item.discount || 0);
  $("fee-edit-note").value = item.note || "";
  $("fee-edit-status").textContent = "";
  feeForm.classList.remove("hidden");
  feeForm.scrollIntoView({behavior:"smooth",block:"center"});
});
$("fee-edit-cancel").addEventListener("click", () => feeForm.classList.add("hidden"));
feeForm.addEventListener("submit", async event => {
  event.preventDefault();
  if (state.offline || !navigator.onLine) { showMessage("fee-edit-status", "تعديل الرسوم يتطلب اتصالًا بالإنترنت.", true); return; }
  if (!["admin","owner","accountant"].includes(state.profile?.role)) { showMessage("fee-edit-status", "ليست لديك صلاحية تعديل الرسوم.", true); return; }
  const id = $("fee-edit-id").value;
  const totalFee = Number($("fee-edit-total").value);
  const discount = Number($("fee-edit-discount").value);
  if (!Number.isFinite(totalFee) || !Number.isFinite(discount) || totalFee < 0 || discount < 0 || discount > totalFee) {
    showMessage("fee-edit-status", "تحقق من الرسوم والخصم؛ يجب ألا يتجاوز الخصم قيمة الرسوم.", true); return;
  }
  const saveButton = feeForm.querySelector('button[type="submit"]');
  saveButton.disabled = true;
  showMessage("fee-edit-status", "جارٍ حفظ التعديل والتحقق من صلاحيات قاعدة البيانات…");
  try {
    const { data, error } = await db.from("student_fee_assessments").update({ total_fee: totalFee, discount, note: $("fee-edit-note").value.trim() }).eq("id", id).eq("school_id", state.school.id).select("id").maybeSingle();
    if (error) throw error;
    if (!data?.id) throw new Error("لم تؤكد قاعدة البيانات حفظ التعديل. تحقق من صلاحيات الحساب.");
    const item = state.assessments.find(a => String(a.id) === String(id));
    if (item) { item.total_fee = totalFee; item.discount = discount; item.note = $("fee-edit-note").value.trim(); }
    feeForm.classList.add("hidden");
    showMessage("app-message", "تم حفظ الرسوم والخصم في قاعدة البيانات.");
    await refreshDashboard();
  } catch (error) {
    console.error("Fee update failed", error);
    showMessage("fee-edit-status", error?.message || "تعذر حفظ الرسوم. لم نعتبر التعديل ناجحًا.", true);
  } finally { saveButton.disabled = false; }
});
$("export-fees").addEventListener("click", () => csvDownload("lamin-fees-summary.csv", [["الطالب","السنة","الفصل","الرسوم","الخصم"], ...state.assessments.map((a) => [state.students.find(s=>s.id===a.student_id)?.name||"",a.academic_year_label,a.term,a.total_fee,a.discount])]));
$("export-finance").addEventListener("click", () => csvDownload("lamin-finance-summary.csv", [["البند","القيمة"],["المقبوضات", $("finance-payments").textContent],["المصروفات", $("finance-expenses").textContent],["الرواتب والسلف", $("finance-payroll").textContent],["الرسوم المقدرة", $("fees-total").textContent],["المدفوع", $("fees-paid").textContent],["الرصيد التقريبي", $("fees-balance").textContent]]));
$("export-staff").addEventListener("click", () => csvDownload("lamin-teachers.csv", [["الاسم","التخصص","الهاتف","الراتب"], ...state.teachers.map((t) => [t.name,t.subject,t.phone,t.salary])]));
$("export-audit").addEventListener("click", () => csvDownload("lamin-audit-log.csv", [["التاريخ","المستخدم","العملية","الكيان","التفاصيل"], ...state.audit.map((a) => [a.created_at,a.username,a.action,a.entity,JSON.stringify(a.details||{})])]));
$("settings-refresh").addEventListener("click", () => loadPortal().catch(e=>showMessage("app-message", "تعذر تحديث بيانات المدرسة.", true)));
$("export-xlsx").addEventListener("click", async () => {
  try {
    showMessage("app-message", "جارٍ تجهيز ملف Excel…");
    const XLSX = await import("https://esm.sh/xlsx@0.18.5");
    const workbook = XLSX.utils.book_new();
    const sheets = [
      ["الطلاب", [["الاسم","الصف","الهاتف","الحالة"], ...state.students.map(s=>[s.name,s.class_name,s.phone,s.status])]],
      ["المعلمون", [["الاسم","التخصص","الهاتف","الراتب"], ...state.teachers.map(t=>[t.name,t.subject,t.phone,t.salary])]],
      ["الحضور", [["الطالب","التاريخ","الحالة","التأخير بالدقائق"], ...state.attendance.map(a=>[state.students.find(s=>s.id===a.student_id)?.name||"",a.attendance_date,a.status,a.minutes_late])]],
      ["الرسوم", [["الطالب","السنة","الفصل","الرسوم","الخصم"], ...state.assessments.map(a=>[state.students.find(s=>s.id===a.student_id)?.name||"",a.academic_year_label,a.term,a.total_fee,a.discount])]],
      ["التدقيق", [["التاريخ","المستخدم","العملية","الكيان","التفاصيل"], ...state.audit.map(a=>[a.created_at,a.username,a.action,a.entity,JSON.stringify(a.details||{})])]]
    ];
    for (const [name, rows] of sheets) XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(rows), name);
    XLSX.writeFile(workbook, "lamin-school-report.xlsx");
    showMessage("app-message", "تم تجهيز تقرير Excel من البيانات المتاحة.");
  } catch (error) {
    console.error("Excel export failed", error);
    showMessage("app-message", "تعذر إنشاء ملف Excel. يمكنك استخدام تصدير CSV.", true);
  }
});
$("export-pdf").addEventListener("click", () => {
  switchPanel("reports");
  window.print();
});
db.auth.onAuthStateChange((event, session) => { if (event === "SIGNED_OUT" || !session) switchView(false); });
window.addEventListener("online", () => { if (state.offline) showMessage("app-message", "عاد الاتصال. حدّث البيانات للتحقق من أحدث السجلات."); });
window.addEventListener("offline", () => { if (state.profile) setOfflineMode(true); });
(async () => {
  try {
    const { data } = await db.auth.getSession();
    if (data.session && navigator.onLine) await loadPortal();
    else if (!navigator.onLine) restoreOfflinePortal();
  } catch (error) {
    console.error(error);
    if (!restoreOfflinePortal()) switchView(false);
  }
})();
