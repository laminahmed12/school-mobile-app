import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

// The publishable key is intended for browser clients. Database access remains
// protected by Supabase Auth, RLS, and the server-side RPC permission checks.
const SUPABASE_URL = "https://stbrhcgzfxvpayfnnqfl.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR";
const db = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});
const $ = (id) => document.getElementById(id);
const state = { profile: null, school: null, students: [], teachers: [], backup: null, backupFileName: "" };
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
async function login(event) {
  event.preventDefault(); showMessage("login-message", "جارٍ التحقق من بيانات الدخول…");
  const form = new FormData(event.currentTarget);
  try {
    const { data, error } = await db.functions.invoke("auth-login", { body: { school: String(form.get("school")).trim(), username: String(form.get("username")).trim(), password: String(form.get("password")) } });
    if (error) throw error;
    if (!data?.refresh_token) throw new Error("استجابة الدخول غير مكتملة.");
    const { error: sessionError } = await db.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token });
    if (sessionError) throw sessionError;
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
  const { data: school, error: schoolError } = await db.from("schools").select("id,name,code").eq("id", profile.school_id).maybeSingle();
  if (schoolError) throw schoolError;
  state.school = school;
  $("school-name").textContent = school?.name || "مدرستك";
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
  let query = db.from(table).select(column);
  if (filter) query = filter(query);
  const { data, error } = await query;
  if (error) throw error;
  return safeRows(data).reduce((sum, row) => sum + Number(row[column] || 0), 0);
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
    const [{ data: students, error: studentError }, { data: teachers, error: teacherError }] = await Promise.all([
      db.from("students").select("name,class_name,phone").order("name").limit(500),
      db.from("teachers").select("name,subject,phone,salary").order("name").limit(500),
    ]);
    if (studentError) throw studentError; if (teacherError) throw teacherError;
    state.students = safeRows(students); state.teachers = safeRows(teachers);
    $("students-table").innerHTML = state.students.map((s) => `<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone)}</td></tr>`).join("") || '<tr><td colspan="3">لا توجد سجلات متاحة.</td></tr>';
    $("teachers-table").innerHTML = state.teachers.map((t) => `<tr><td>${escapeHtml(t.name)}</td><td>${escapeHtml(t.subject)}</td><td>${escapeHtml(t.phone)}</td><td>${escapeHtml(t.salary == null ? "—" : money(t.salary))}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات متاحة.</td></tr>';
    showMessage("app-message", "تم تحديث البيانات.");
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
  if (!["owner", "admin"].includes(state.profile?.role)) { showMessage("restore-status", "الاستعادة متاحة لمدير المدرسة أو مالك النظام فقط.", true); return; }
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
$("refresh-dashboard").addEventListener("click", () => refreshDashboard());
$("create-backup").addEventListener("click", () => createBackup());
$("backup-file").addEventListener("change", (e) => inspectBackup(e.target.files?.[0]));
$("restore-confirm").addEventListener("input", updateRestoreButton);
$("restore-backup").addEventListener("click", () => restoreBackup());
$("export-students").addEventListener("click", () => csvDownload("lamin-students.csv", [["الاسم","الصف","الهاتف"], ...state.students.map((s) => [s.name, s.class_name, s.phone])]));
db.auth.onAuthStateChange((event, session) => { if (event === "SIGNED_OUT" || !session) switchView(false); });
(async () => { try { const { data } = await db.auth.getSession(); if (data.session) await loadPortal(); } catch (error) { console.error(error); switchView(false); } })();
