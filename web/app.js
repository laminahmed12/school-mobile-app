import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

// The publishable key is intended for browser clients. Database access remains
// protected by Supabase Auth, RLS, and the server-side RPC permission checks.
const SUPABASE_URL = "https://stbrhcgzfxvpayfnnqfl.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_HwBqQzgwWlnRR-tUS9iTUQ_HcZrlsfR";
const db = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});
const $ = (id) => document.getElementById(id);
const state = { profile: null, school: null, students: [], teachers: [], staff: [], classes: [], attendance: [], results: [], assessments: [], audit: [], expenses: [], payroll: [], backup: null, backupFileName: "" };
const money = (value) => new Intl.NumberFormat("ar-LY", { style: "currency", currency: "LYD", maximumFractionDigits: 2 }).format(Number(value || 0));
const DATE_LOCALE_OPTIONS={calendar:"gregory",numberingSystem:"latn",timeZone:"Africa/Tripoli",day:"2-digit",month:"2-digit",year:"numeric"};
const formatDate = (value) => { if(!value)return "—"; const raw=String(value); const date=/^\d{4}-\d{2}-\d{2}$/.test(raw)?new Date(raw+"T12:00:00+02:00"):new Date(raw); return Number.isNaN(date.getTime())?raw:new Intl.DateTimeFormat("en-GB",DATE_LOCALE_OPTIONS).format(date); };
const formatDateTime = (value) => { if(!value)return "—"; const date=new Date(value); return Number.isNaN(date.getTime())?String(value):new Intl.DateTimeFormat("en-GB",{...DATE_LOCALE_OPTIONS,hour:"2-digit",minute:"2-digit",hourCycle:"h23"}).format(date); };
const isNetworkFetchError = (error) => error instanceof TypeError && /fetch|network|load failed/i.test(error.message||"");
const queueStudentLocally = ({id,payload,termFee}) => { if(id){queueOfflineChange({action:"update",table:"students",record_id:id,payload});const row=state.students.find(x=>String(x.id)===String(id));if(row)Object.assign(row,payload,{_pending:true});}else{const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));const full={...payload,school_id:state.school.id,active:true,id:localId,_pending:true};queueOfflineChange({action:"rpc_student",table:"students",local_id:localId,params:{p_name:payload.name,p_class_name:payload.class_name,p_phone:payload.phone||"",p_term_fee:termFee,p_term:"الفصل الأول"}});state.students.unshift(full);}renderManagedTables();saveOfflineSnapshot();$("student-form").classList.add("hidden");showMessage("app-message","تعذر الاتصال بالخادم؛ حُفظ الطالب على هذا الجهاز وسيُزامن تلقائياً عند عودة الاتصال."); };
const readableDetails = (details) => { const labels={attendance_date:"تاريخ الحضور",minutes_late:"دقائق التأخير",status:"الحالة",phone:"الهاتف",name:"الاسم",class_name:"الصف",amount:"المبلغ",term:"الفصل",academic_year_id:"السنة الدراسية",exam_name:"الاختبار",score:"الدرجة",max_score:"الدرجة القصوى",total_fee:"الرسوم",discount:"الخصم"}; if(!details||typeof details!=="object")return escapeHtml(details??"—"); return Object.entries(details).filter(([key])=>!["id","school_id","created_by","student_id","user_id"].includes(key)).map(([key,value])=>{const shown=key==="status"?({absent:"غائب",present:"حاضر",late:"متأخر",excused:"معذور"}[value]||value):value;return "<div class=\"audit-detail\"><strong>"+escapeHtml(labels[key]||key.replaceAll("_"," "))+":</strong> <span>"+escapeHtml(typeof shown==="object"?JSON.stringify(shown):shown)+"</span></div>";}).join("")||"لا توجد تفاصيل إضافية."; };
const showMessage = (id, message, error = false) => { const el = $(id); el.textContent = message || ""; el.classList.toggle("error", error); };
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const safeRows = (rows) => Array.isArray(rows) ? rows : [];
const OFFLINE_SNAPSHOT_PREFIX = "lamin-portal-snapshot-v2:";
const OFFLINE_QUEUE_PREFIX = "lamin-portal-queue-v1:";
const OFFLINE_MODE_MESSAGE = "أنت تعمل دون اتصال. التغييرات المسموح بها تُحفظ محلياً وتنتظر المزامنة عند عودة الإنترنت.";
const canManageSchool = () => ["admin","owner"].includes(state.profile?.role);
const canManageFinance = () => ["admin","owner","accountant"].includes(state.profile?.role);
const localQueueKey = () => OFFLINE_QUEUE_PREFIX + String(state.school?.id || "");
function setOfflineMode(enabled) {
  state.offline = Boolean(enabled);
  document.body.classList.toggle("offline-mode", state.offline);
  const banner = $("offline-banner");
  if (banner) banner.classList.toggle("hidden", !state.offline);
}
function saveOfflineSnapshot() {
  if (!state.profile || !state.school || state.offline) return;
  try {
    const data = { students:state.students, teachers:state.teachers, staff:state.staff || [], classes:state.classes || [], attendance:state.attendance, results:state.results, assessments:state.assessments, audit:state.audit, expenses:state.expenses, payroll:state.payroll, payments:state.payments || [] };
    const metrics = {};
    ["count-students","count-teachers","count-classes","total-payments","total-expenses","finance-payments","finance-expenses","finance-payroll","fees-total","fees-paid","fees-balance"].forEach(id => { if ($(id)) metrics[id] = $(id).textContent; });
    localStorage.setItem(OFFLINE_SNAPSHOT_PREFIX + state.school.id, JSON.stringify({ profile:{username:state.profile.username,role:state.profile.role,active:state.profile.active,school_id:state.school.id}, school:state.school, data, metrics, savedAt:new Date().toISOString() }));
  } catch (error) { console.warn("Offline snapshot save failed", error); }
}
function offlineQueueKey() { return OFFLINE_QUEUE_PREFIX + String(state.school?.id || ""); }
function readOfflineQueue() {
  try { const rows = JSON.parse(localStorage.getItem(offlineQueueKey()) || "[]"); return Array.isArray(rows) ? rows : []; }
  catch { return []; }
}
function writeOfflineQueue(rows) { localStorage.setItem(offlineQueueKey(), JSON.stringify(rows)); const el=$("offline-queue-count"); if(el) el.textContent = rows.length ? "تغييرات معلّقة: " + rows.length : "لا توجد تغييرات معلّقة"; }
function queueOfflineChange(item) {
  const rows = readOfflineQueue();
  if (String(item.record_id || "").startsWith("offline-")) {
    const pending = rows.find(x => x.local_id === item.record_id);
    if (item.action === "archive" && pending) { writeOfflineQueue(rows.filter(x => x.local_id !== item.record_id)); return; }
    if (item.action === "update" && pending?.action === "insert") { pending.payload = { ...pending.payload, ...item.payload }; writeOfflineQueue(rows); return; }
    if (item.action === "update" && pending?.action === "rpc_student") {
      const map={name:"p_name",class_name:"p_class_name",phone:"p_phone"};
      for (const [key,value] of Object.entries(item.payload)) if(map[key]) pending.params[map[key]]=value;
      writeOfflineQueue(rows); return;
    }
  }
  rows.push({ queue_id: String(Date.now()) + Math.random(), ...item, created_at: new Date().toISOString() });
  writeOfflineQueue(rows);
}
function renderManagedTables() {
  const studentSearch=($("student-search")?.value||"").trim().toLocaleLowerCase("ar"); const studentClassFilter=($("student-class-filter")?.value||"").trim().toLocaleLowerCase("ar");
  $("students-table").innerHTML = state.students.filter(s=>s.active!==false && (!studentSearch||String(s.name||"").toLocaleLowerCase("ar").includes(studentSearch)) && (!studentClassFilter||String(s.class_name||"").toLocaleLowerCase("ar").includes(studentClassFilter))).map(s => `<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone)}</td><td><button class="button button-secondary" data-student-edit="${escapeHtml(s.id)}" type="button">تعديل</button><button class="button button-danger" data-student-archive="${escapeHtml(s.id)}" type="button">أرشفة</button></td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات.</td></tr>';
  if($("archived-students-table")) $("archived-students-table").innerHTML=state.students.filter(s=>s.active===false && (!studentSearch||String(s.name||"").toLocaleLowerCase("ar").includes(studentSearch)) && (!studentClassFilter||String(s.class_name||"").toLocaleLowerCase("ar").includes(studentClassFilter))).map(s=>`<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone||"—")}</td><td><button class="button button-primary" type="button" data-student-restore="${escapeHtml(s.id)}">استعادة من الأرشيف</button></td></tr>`).join("")||'<tr><td colspan="4">لا توجد سجلات مؤرشفة.</td></tr>';
  $("classes-table").innerHTML = (state.classes||[]).map(x=>`<tr><td>${escapeHtml(x.name)}</td><td>${escapeHtml(x.section)}</td><td><button class="button button-secondary" type="button" data-class-edit="${escapeHtml(x.id)}">تعديل</button></td></tr>`).join("") || '<tr><td colspan="3">لا توجد صفوف مسجلة.</td></tr>';
  if($("class-new")) $("class-new").classList.toggle("hidden",!["admin","owner"].includes(state.profile?.role));
  $("teachers-table").innerHTML = state.teachers.map(t => `<tr><td>${escapeHtml(t.name)}</td><td>${escapeHtml(t.subject)}</td><td>${escapeHtml(t.phone)}</td><td>${escapeHtml(t.salary == null ? "—" : money(t.salary))}</td><td><button class="button button-secondary" data-teacher-edit="${escapeHtml(t.id)}" type="button">تعديل</button></td></tr>`).join("") || '<tr><td colspan="5">لا توجد سجلات.</td></tr>';
  $("staff-table").innerHTML = (state.staff || []).filter(x=>x.active!==false).map(s=>`<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.role)}</td><td>${escapeHtml(s.phone||"—")}</td><td>${escapeHtml(money(s.salary))}</td><td><button class="button button-secondary" type="button" data-staff-edit="${escapeHtml(s.id)}">تعديل</button><button class="button button-danger" type="button" data-staff-archive="${escapeHtml(s.id)}">أرشفة</button></td></tr>`).join("") || '<tr><td colspan="5">لا توجد سجلات موظفين.</td></tr>';
  if($("archived-staff-table")) $("archived-staff-table").innerHTML=(state.staff||[]).filter(x=>x.active===false).map(s=>`<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.role)}</td><td>${escapeHtml(s.phone||"—")}</td><td>${escapeHtml(money(s.salary))}</td><td><button class="button button-primary" type="button" data-staff-restore="${escapeHtml(s.id)}">استعادة من الأرشيف</button></td></tr>`).join("")||'<tr><td colspan="5">لا توجد سجلات موظفين مؤرشفة.</td></tr>';
  $("payroll-table").innerHTML = (state.payroll || []).map(p=>{const rows=p.payee_type==="teacher"?state.teachers:state.staff;const person=(rows||[]).find(x=>String(x.id)===String(p.payee_id));return `<tr><td>${escapeHtml(person?.name || "مستفيد")}</td><td>${p.transaction_type==="advance"?"سلفة":"راتب"}</td><td>${escapeHtml(money(p.amount))}</td><td>${escapeHtml(formatDate(p.payment_date))}</td><td>${escapeHtml(p.note)}</td></tr>`;}).join("") || '<tr><td colspan="5">لا توجد عمليات رواتب.</td></tr>';
  const studentOptions=state.students.filter(s=>s.active!==false && !String(s.id).startsWith("offline-")).map(s=>`<option value="${escapeHtml(s.id)}">${escapeHtml(s.name)}</option>`).join("");
  for(const id of ["attendance-student","result-student"]) { const select=$(id); if(select) select.innerHTML=studentOptions; }
  const paymentSelect=$("payment-assessment"); if(paymentSelect) paymentSelect.innerHTML='<option value="">اختر الطالب وبند الرسوم</option>'+state.assessments.map(a=>{const student=state.students.find(s=>String(s.id)===String(a.student_id));return `<option value="${escapeHtml(a.id)}">${escapeHtml(student?.name||"طالب")} · ${escapeHtml(a.academic_year_label||"")} · ${escapeHtml(a.term||"")} · ${money(a.total_fee)}</option>`;}).join("");
  $("expenses-table").innerHTML = state.expenses.map(e => `<tr><td>${escapeHtml(e.title)}</td><td>${escapeHtml(e.category)}</td><td>${escapeHtml(money(e.amount))}</td><td>${escapeHtml(formatDateTime(e.created_at))}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد مصروفات.</td></tr>';
  if ($("student-new")) $("student-new").classList.toggle("hidden", !["admin","owner"].includes(state.profile?.role));
  if ($("teacher-new")) $("teacher-new").classList.toggle("hidden", !["admin","owner"].includes(state.profile?.role));
  if ($("expense-new")) $("expense-new").classList.toggle("hidden", !["admin","owner","accountant"].includes(state.profile?.role));
  if ($("staff-new")) $("staff-new").classList.toggle("hidden", !["admin","owner"].includes(state.profile?.role));
  const payeeType=$("payroll-payee-type")?.value || "teacher";
  const payeeRows=payeeType==="teacher"?state.teachers:state.staff;
  if ($("payroll-payee")) $("payroll-payee").innerHTML=(payeeRows||[]).filter(x=>x.active!==false).map(x=>`<option value="${escapeHtml(x.id)}">${escapeHtml(x.name)}</option>`).join("");
}

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
const OFFLINE_CREDENTIAL_KEY = "lamin-portal-offline-credential-v1";
async function deriveOfflineVerifier(password,salt){const material=await crypto.subtle.importKey("raw",new TextEncoder().encode(password),"PBKDF2",false,["deriveBits"]);const bits=await crypto.subtle.deriveBits({name:"PBKDF2",salt:Uint8Array.from(atob(salt),c=>c.charCodeAt(0)),iterations:180000,hash:"SHA-256"},material,256);return btoa(String.fromCharCode(...new Uint8Array(bits)));}
async function saveOfflineVerifier(password){if(!$("remember-login").checked){localStorage.removeItem(OFFLINE_CREDENTIAL_KEY);return;}const salt=crypto.getRandomValues(new Uint8Array(16));const saltText=btoa(String.fromCharCode(...salt));const verifier=await deriveOfflineVerifier(password,saltText);localStorage.setItem(OFFLINE_CREDENTIAL_KEY,JSON.stringify({school:$("school-code").value.trim().toLowerCase(),username:$("username").value.trim().toLowerCase(),salt:saltText,verifier,version:1}));}
async function verifyOfflineCredential(school,username,password){try{const saved=JSON.parse(localStorage.getItem(OFFLINE_CREDENTIAL_KEY)||"null");if(!saved||saved.version!==1||saved.school!==school.trim().toLowerCase()||saved.username!==username.trim().toLowerCase())return false;const candidate=await deriveOfflineVerifier(password,saved.salt);return candidate===saved.verifier;}catch{return false;}}
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
  if (!$("remember-login").checked) { try { localStorage.removeItem(REMEMBER_LOGIN_KEY); localStorage.removeItem(OFFLINE_CREDENTIAL_KEY); } catch {} }
});
restoreRememberedLogin();

function restoreOfflinePortal(expectedSchool="",expectedUsername="") {
  try {
    const candidates = Object.keys(localStorage).filter(key => key.startsWith(OFFLINE_SNAPSHOT_PREFIX));
    if (!candidates.length) return false;
    const snapshots = candidates.map(key => ({ key, value: JSON.parse(localStorage.getItem(key) || "null") })).filter(x => x.value?.profile && x.value?.school && x.value?.data && (!expectedSchool || String(x.value.school.code||"").toLowerCase()===expectedSchool.trim().toLowerCase()) && (!expectedUsername || String(x.value.profile.username||"").toLowerCase()===expectedUsername.trim().toLowerCase()));
    const cached = snapshots.sort((a,b) => new Date(b.value.savedAt)-new Date(a.value.savedAt))[0]?.value;
    if (!cached) return false;
    if(expectedSchool && String(cached.school.code||"").toLowerCase()!==expectedSchool.trim().toLowerCase()) return false;
    if(expectedUsername && String(cached.profile.username||"").toLowerCase()!==expectedUsername.trim().toLowerCase()) return false;
    state.profile = cached.profile; state.school = cached.school;
    Object.assign(state, cached.data); state.offline = true;
    for (const op of readOfflineQueue()) { const rows = state[op.table]; if (!Array.isArray(rows)) continue; if (op.action === "insert") rows.unshift({ ...op.payload, id: op.local_id, _pending: true }); if (op.action === "rpc_student") rows.unshift({ id: op.local_id, name: op.params.p_name, class_name: op.params.p_class_name, phone: op.params.p_phone, active: true, _pending: true }); if (op.action === "rpc_payment") { state.payments=state.payments||[]; if(!state.payments.some(p=>p.id===op.local_id)) state.payments.unshift({id:op.local_id,student_id:op.params.p_student_id,fee_assessment_id:op.params.p_fee_assessment_id,term:op.params.p_term,amount:op.params.p_amount,note:op.params.p_note,created_at:op.created_at,_pending:true}); } if (op.action === "upsert") { const row=rows.find(x=>x.student_id===op.payload.student_id&&x.attendance_date===op.payload.attendance_date); if(row) Object.assign(row,op.payload,{_pending:true}); else rows.unshift({...op.payload,_pending:true}); } if (op.action === "update") { const row=rows.find(x=>String(x.id)===String(op.record_id)); if(row) Object.assign(row,op.payload,{_pending:true}); } if (op.action === "archive") { const row=rows.find(x=>String(x.id)===String(op.record_id)); if(row) row.active=false; } }
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
    renderManagedTables();
    populateFeeSearchOptions(); renderFeeSearchResults();
    $("attendance-table").innerHTML = state.attendance.map(a => `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(formatDate(a.attendance_date))}</td><td>${escapeHtml(a.status)}</td><td>${escapeHtml(a.minutes_late ?? 0)}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات محفوظة.</td></tr>';
    $("results-table").innerHTML = state.results.map(r => `<tr><td>${escapeHtml(studentNames.get(r.student_id)||"طالب")}</td><td>${escapeHtml(r.exam_name)}</td><td>${escapeHtml(r.term)}</td><td>${escapeHtml(r.score)}</td><td>${escapeHtml(r.max_score)}</td></tr>`).join("") || '<tr><td colspan="5">لا توجد نتائج محفوظة.</td></tr>';
    const paidByAssessment = new Map();
    for (const p of state.payments || []) if (p.fee_assessment_id) paidByAssessment.set(p.fee_assessment_id, (paidByAssessment.get(p.fee_assessment_id)||0)+Number(p.amount||0));
    $("fees-table").innerHTML = state.assessments.map(a => { const fee=Number(a.total_fee||0), discount=Number(a.discount||0), paid=paidByAssessment.get(a.id)||0, balance=Math.max(0,fee-discount-paid); return `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.academic_year_label)}</td><td>${escapeHtml(a.term)}</td><td>${escapeHtml(money(fee))}</td><td>${escapeHtml(money(discount))}</td><td>${escapeHtml(money(paid))}</td><td>${escapeHtml(money(balance))}</td></tr>`; }).join("") || '<tr><td colspan="8">لا توجد رسوم محفوظة.</td></tr>';
    $("audit-table").innerHTML = state.audit.map(a => `<tr><td>${escapeHtml(formatDateTime(a.created_at))}</td><td>${escapeHtml(a.username)}</td><td>${escapeHtml(({insert:"إضافة سجل",INSERT:"إضافة سجل",update:"تعديل سجل",UPDATE:"تعديل سجل",delete:"حذف سجل",DELETE:"حذف سجل"}[a.action]||a.action))}</td><td>${escapeHtml(({student_fee_assessments:"رسوم الطلاب",attendance:"الحضور",teachers:"المعلمون",students:"الطلاب",expenses:"المصروفات",payments:"الدفعات",staff:"الموظفون",classes:"الصفوف",payroll_transactions:"الرواتب والسلف"}[a.entity]||a.entity))}</td><td class="audit-details">${readableDetails(a.details)}</td></tr>`).join("") || '<tr><td colspan="5">لا يوجد سجل محفوظ.</td></tr>';
    const queueBadge = $("offline-queue-count"); if (queueBadge) queueBadge.textContent = readOfflineQueue().length ? "تغييرات معلّقة: " + readOfflineQueue().length : "لا توجد تغييرات معلّقة";
    showMessage("app-message", "عرض نسخة محفوظة بتاريخ " + new Date(cached.savedAt).toLocaleString("ar-LY") + ". يمكنك إجراء التغييرات المسموح بها؛ ستتم مزامنتها عند عودة الإنترنت.");
    return true;
  } catch (error) { console.error("Lamin offline restore failed", error); return false; }
}
async function requestAuthLogin(payload){
  const first=await db.functions.invoke("auth-login",{body:payload});
  if(!first.error)return first;
  if(first.error.name!=="FunctionsFetchError" && !(first.error instanceof TypeError))return first;
  try{
    const response=await fetch(SUPABASE_URL+"/functions/v1/auth-login",{method:"POST",headers:{apikey:SUPABASE_PUBLISHABLE_KEY,Authorization:"Bearer "+SUPABASE_PUBLISHABLE_KEY,"Content-Type":"application/json"},body:JSON.stringify(payload),cache:"no-store"});
    const data=await response.json().catch(()=>null);
    if(!response.ok)return {data,error:new Error(data?.error||("تعذر تسجيل الدخول (HTTP "+response.status+")."))};
    return {data,error:null};
  }catch(error){return {data:null,error};}
}
async function login(event) {
  event.preventDefault();
  const form = new FormData(event.currentTarget);
  const school=String(form.get("school")).trim(), username=String(form.get("username")).trim(), password=String(form.get("password"));
  if (!navigator.onLine) {
    if (await verifyOfflineCredential(school,username,password) && restoreOfflinePortal(school,username)) { $("password").value=""; showMessage("app-message","تم فتح النسخة المحلية بعد التحقق من بيانات الدخول المحفوظة على هذا الجهاز."); return; }
    showMessage("login-message", "تعذر الدخول دون إنترنت. يلزم تسجيل دخول ناجح مع تفعيل «تذكرني» مرة واحدة قبل استخدام الدخول المحلي.", true);
    return;
  }
  showMessage("login-message", "جارٍ التحقق من بيانات الدخول…");
  try {
    const { data, error } = await requestAuthLogin({ school, username, password });
    if (error) throw error;
    if (!data?.refresh_token) throw new Error("استجابة الدخول غير مكتملة.");
    const { error: sessionError } = await db.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token });
    if (sessionError) throw sessionError;
    saveRememberedLogin();
    await saveOfflineVerifier(password);
    $("password").value = "";
    await loadPortal();
  } catch (error) {
    console.error("Lamin portal login failed", error);
    if(await verifyOfflineCredential(school,username,password) && restoreOfflinePortal(school,username)){ $("password").value=""; showMessage("app-message","تعذر الوصول لخدمة تسجيل الدخول؛ تم فتح بيانات المدرسة المحفوظة محلياً بعد التحقق من كلمة المرور."); return; }
    const sessionResult=await db.auth.getSession().catch(()=>({data:{session:null}}));
    if(sessionResult.data?.session){try{await loadPortal();$("password").value="";showMessage("app-message","تم الدخول بالجلسة المحفوظة؛ تعذر الوصول لخدمة تسجيل الدخول مؤقتاً.");return;}catch(loadError){console.warn("Saved session could not load portal",loadError);}}
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
  if (readOfflineQueue().length) await syncOfflineQueue();
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
async function fetchAllRows(table,columns,orderBy=null,ascending=true,pageSize=500) {
  const rows=[];let offset=0;
  while(true){
    let query=db.from(table).select(columns).range(offset,offset+pageSize-1);
    if(orderBy)query=query.order(orderBy,{ascending});
    const {data,error}=await query;
    if(error)return {data:null,error};
    const page=safeRows(data);rows.push(...page);
    if(page.length<pageSize)break;
    offset+=pageSize;
  }
  return {data:rows,error:null};
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
    const [studentsResult, teachersResult, staffResult, classesResult, attendanceResult, resultsResult, assessmentsResult, auditResult, expensesResult, payrollResult] = await Promise.all([
      fetchAllRows("students","id,name,class_name,phone,active,status","name"),
      fetchAllRows("teachers","id,name,subject,phone,salary","name"),
      fetchAllRows("staff","id,name,role,phone,salary,active,created_at","name"),
      fetchAllRows("classes","id,name,section,academic_year_id","name"),
      fetchAllRows("attendance","student_id,attendance_date,status,minutes_late","attendance_date",false),
      fetchAllRows("student_results","student_id,term,exam_name,score,max_score,created_at","created_at",false),
      fetchAllRows("student_fee_assessments","id,student_id,academic_year_id,academic_year_label,term,total_fee,discount,note"),
      fetchAllRows("audit_log","created_at,username,action,entity,details","created_at",false,500),
      fetchAllRows("expenses","title,category,amount,created_at","created_at",false),
      fetchAllRows("payroll_transactions","payee_type,payee_id,transaction_type,amount,payment_date,note","payment_date",false),
    ]);
    const results = [studentsResult,teachersResult,staffResult,classesResult,attendanceResult,resultsResult,assessmentsResult,auditResult,expensesResult,payrollResult];
    const labels = ["الطلاب","المعلمون","الموظفون","الصفوف","الحضور","النتائج","الرسوم","التدقيق","المصروفات","الرواتب"];
    results.forEach((r,i)=>{ if(r.error) console.warn("Lamin portal optional dataset unavailable:",labels[i],r.error.message); });
    state.students = safeRows(studentsResult.data); state.teachers = safeRows(teachersResult.data); state.staff = safeRows(staffResult.data); state.classes = safeRows(classesResult.data);
    state.attendance = safeRows(attendanceResult.data); state.results = safeRows(resultsResult.data);
    state.assessments = safeRows(assessmentsResult.data); state.audit = safeRows(auditResult.data);
    state.expenses = safeRows(expensesResult.data); state.payroll = safeRows(payrollResult.data);
    const studentNames = new Map(state.students.map(s=>[s.id,s.name]));
    $("students-table").innerHTML = state.students.map((s) => `<tr><td>${escapeHtml(s.name)}</td><td>${escapeHtml(s.class_name)}</td><td>${escapeHtml(s.phone)}</td></tr>`).join("") || '<tr><td colspan="3">لا توجد سجلات متاحة.</td></tr>';
    $("teachers-table").innerHTML = state.teachers.map((t) => `<tr><td>${escapeHtml(t.name)}</td><td>${escapeHtml(t.subject)}</td><td>${escapeHtml(t.phone)}</td><td>${escapeHtml(t.salary == null ? "—" : money(t.salary))}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات متاحة.</td></tr>';
    $("attendance-table").innerHTML = state.attendance.map(a=>`<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(formatDate(a.attendance_date))}</td><td>${escapeHtml(a.status)}</td><td>${escapeHtml(a.minutes_late ?? 0)}</td></tr>`).join("") || '<tr><td colspan="4">لا توجد سجلات متاحة أو لا تسمح الصلاحيات بعرضها.</td></tr>';
    $("results-table").innerHTML = state.results.map(r=>`<tr><td>${escapeHtml(studentNames.get(r.student_id)||"طالب")}</td><td>${escapeHtml(r.exam_name)}</td><td>${escapeHtml(r.term)}</td><td>${escapeHtml(r.score)}</td><td>${escapeHtml(r.max_score)}</td></tr>`).join("") || '<tr><td colspan="5">لا توجد نتائج متاحة.</td></tr>';
    const paidByAssessment = new Map();
    const paymentsResult = await fetchAllRows("payments","id,fee_assessment_id,amount,student_id,term,created_at","created_at",false);
    if(paymentsResult.error)throw paymentsResult.error;
    state.payments = paymentsResult.data;
    if (!paymentsResult.error) for(const p of state.payments) if(p.fee_assessment_id) paidByAssessment.set(p.fee_assessment_id,(paidByAssessment.get(p.fee_assessment_id)||0)+Number(p.amount||0));
    let totalFees=0,totalDiscount=0,totalPaid=0;
    $("fees-table").innerHTML = state.assessments.map(a=>{const fee=Number(a.total_fee||0),discount=Number(a.discount||0),paid=paidByAssessment.get(a.id)||0,balance=Math.max(0,fee-discount-paid);totalFees+=fee;totalDiscount+=discount;totalPaid+=paid;return `<tr><td>${escapeHtml(studentNames.get(a.student_id)||"طالب")}</td><td>${escapeHtml(a.academic_year_label)}</td><td>${escapeHtml(a.term)}</td><td>${escapeHtml(money(fee))}</td><td>${escapeHtml(money(discount))}</td><td>${escapeHtml(money(paid))}</td><td>${escapeHtml(money(balance))}</td>${["admin","owner","accountant"].includes(state.profile?.role) ? `<td><button class="button button-secondary" type="button" data-fee-edit="${escapeHtml(a.id)}">تعديل</button></td>` : ""}</tr>`;}).join("") || '<tr><td colspan="8">لا توجد تقديرات رسوم متاحة.</td></tr>';
    $("fees-total").textContent=money(totalFees); $("fees-paid").textContent=money(totalPaid); $("fees-balance").textContent=money(Math.max(0,totalFees-totalDiscount-totalPaid));
    $("audit-table").innerHTML = state.audit.map(a=>`<tr><td>${escapeHtml(formatDateTime(a.created_at))}</td><td>${escapeHtml(a.username)}</td><td>${escapeHtml(({insert:"إضافة سجل",INSERT:"إضافة سجل",update:"تعديل سجل",UPDATE:"تعديل سجل",delete:"حذف سجل",DELETE:"حذف سجل"}[a.action]||a.action))}</td><td>${escapeHtml(({student_fee_assessments:"رسوم الطلاب",attendance:"الحضور",teachers:"المعلمون",students:"الطلاب",expenses:"المصروفات",payments:"الدفعات",staff:"الموظفون",classes:"الصفوف",payroll_transactions:"الرواتب والسلف"}[a.entity]||a.entity))}</td><td class="audit-details">${readableDetails(a.details)}</td></tr>`).join("") || '<tr><td colspan="5">لا يوجد سجل تدقيق متاح أو لا تسمح الصلاحيات بعرضه.</td></tr>';
    renderManagedTables();
    populateFeeSearchOptions(); renderFeeSearchResults();
    setOfflineMode(false);
    saveOfflineSnapshot();
    showMessage("app-message", "تم تحديث البيانات المتاحة. قد تكون بعض الأقسام فارغة إذا كانت صلاحيات قاعدة البيانات تمنع قراءتها.");
  } catch (error) {
    console.error("Lamin dashboard read failed", error);
    showMessage("app-message", "تعذر تحميل بعض البيانات. تحقق من صلاحيات قاعدة البيانات؛ لم تُغيّر أي بيانات.", true);
  }
}
function populateFeeSearchOptions(){
  const yearSelect=$("fee-search-year"), termSelect=$("fee-search-term");
  if(yearSelect){const selected=yearSelect.value;const years=[...new Map(state.assessments.map(a=>[String(a.academic_year_id||a.academic_year_label||""),a.academic_year_label||"سنة غير محددة"])).entries()];yearSelect.innerHTML='<option value="">كل السنوات</option>'+years.map(([value,label])=>'<option value="'+escapeHtml(value)+'">'+escapeHtml(label)+'</option>').join("");yearSelect.value=selected;}
  if(termSelect){const selected=termSelect.value;const terms=[...new Set(state.assessments.map(a=>a.term).filter(Boolean))];termSelect.innerHTML='<option value="">كل الفصول</option>'+terms.map(value=>'<option value="'+escapeHtml(value)+'">'+escapeHtml(value)+'</option>').join("");termSelect.value=selected;}
}
function renderFeeSearchResults(){
  const name=($("fee-search-name")?.value||"").trim().toLocaleLowerCase("ar"), cls=($("fee-search-class")?.value||"").trim().toLocaleLowerCase("ar"), year=$("fee-search-year")?.value||"", term=$("fee-search-term")?.value||"";
  const rows=state.assessments.filter(a=>{const student=state.students.find(s=>String(s.id)===String(a.student_id));return (!name||String(student?.name||"").toLocaleLowerCase("ar").includes(name))&&(!cls||String(student?.class_name||"").toLocaleLowerCase("ar").includes(cls))&&(!year||String(a.academic_year_id||a.academic_year_label||"")===year)&&(!term||String(a.term||"")===term);});
  const paid=new Map();for(const p of state.payments||[])if(p.fee_assessment_id)paid.set(p.fee_assessment_id,(paid.get(p.fee_assessment_id)||0)+Number(p.amount||0));
  $("fees-table").innerHTML=rows.map(a=>{const student=state.students.find(s=>String(s.id)===String(a.student_id));const fee=Number(a.total_fee||0),discount=Number(a.discount||0),amount=paid.get(a.id)||0,balance=Math.max(0,fee-discount-amount);return `<tr><td>${escapeHtml(student?.name||"طالب")}</td><td>${escapeHtml(a.academic_year_label||"—")}</td><td>${escapeHtml(a.term||"—")}</td><td>${escapeHtml(money(fee))}</td><td>${escapeHtml(money(discount))}</td><td>${escapeHtml(money(amount))}</td><td>${escapeHtml(money(balance))}</td>${["admin","owner","accountant"].includes(state.profile?.role)?`<td><button class="button button-secondary" type="button" data-fee-edit="${escapeHtml(a.id)}">تعديل</button>`:""}</tr>`;}).join("")||'<tr><td colspan="8">لا توجد نتائج مطابقة لمعايير البحث.</td></tr>';
}
function downloadBackupFile(payload, suffix) {
  const text=JSON.stringify(payload,null,2);
  const url=URL.createObjectURL(new Blob([text],{type:"application/json;charset=utf-8"}));
  const a=document.createElement("a");a.href=url;a.download=`lamin_${new Date().toISOString().slice(0,10)}_${String(state.school.code||"school").replace(/[^\\w-]/g,"_")}_${suffix}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function createLocalBackup() {
  const key=OFFLINE_SNAPSHOT_PREFIX+state.school.id;
  const cached=JSON.parse(localStorage.getItem(key)||"null");
  const snapshot=cached||{profile:{username:state.profile.username,role:state.profile.role,active:state.profile.active,school_id:state.school.id},school:state.school,data:{students:state.students,teachers:state.teachers,staff:state.staff||[],classes:state.classes||[],attendance:state.attendance,results:state.results,assessments:state.assessments,audit:state.audit,expenses:state.expenses,payroll:state.payroll,payments:state.payments||[]},metrics:{},savedAt:new Date().toISOString()};
  const payload={format:"lamin-offline-backup-v1",school_id:state.school.id,school_code:state.school.code,school_name:state.school.name,exported_at:new Date().toISOString(),snapshot,queue:readOfflineQueue()};
  if(!snapshot?.data||!Array.isArray(payload.queue))throw new Error("تعذر تجهيز النسخة المحلية بسبب عدم اكتمال البيانات المحفوظة.");
  downloadBackupFile(payload,"offline");
  showMessage("backup-status","تم تنزيل نسخة محلية تشمل آخر بيانات محفوظة و"+payload.queue.length+" تغييرات معلّقة. هذه نسخة محلية وليست نسخة خادم؛ ستبقى المزامنة مرتبطة بحساب المدرسة.");
}
async function createBackup() {
  const button = $("create-backup"); button.disabled = true;
  if(state.offline||!navigator.onLine){try{createLocalBackup();}catch(error){showMessage("backup-status",error.message||"تعذر إنشاء النسخة المحلية.",true);}finally{button.disabled=false;}return;}
  showMessage("backup-status", "جارٍ إنشاء النسخة والتحقق منها…");
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
    const envelope = { ...data, school_code:state.school.code, school_name:state.school.name, exported_at:new Date().toISOString() };
    const text = JSON.stringify(envelope, null, 2);
    const parsed = JSON.parse(text);
    if (parsed.format !== "lamin-school-backup-v2" || String(parsed.school_filter) !== String(state.school.id)) throw new Error("فشل التحقق النهائي من ملف النسخة.");
    const url = URL.createObjectURL(new Blob([text], { type: "application/json;charset=utf-8" }));
    const a = document.createElement("a"); a.href = url; a.download = `lamin_${new Date().toISOString().slice(0,10)}_${String(state.school.code || "school").replace(/[^\w-]/g,"_")}.json`; a.click(); URL.revokeObjectURL(url);
    showMessage("backup-status", "تم إنشاء الملف والتحقق من هوية المدرسة وبنية النسخة قبل التنزيل.");
  } catch (error) {
    console.error("Lamin backup failed", error);
    showMessage("backup-status", error?.message || "تعذر إنشاء نسخة احتياطية.", true);
  } finally { button.disabled = false; }
}
async function inspectBackup(file) {
  state.backup = null; state.backupFileName = ""; $("restore-backup").disabled = true; $("restore-confirm").checked = false; $("backup-preview").classList.add("hidden");
  if (!file) return;
  try {
    if (file.size > 100 * 1024 * 1024) throw new Error("حجم الملف يتجاوز الحد الآمن البالغ 100 ميغابايت.");
    const envelope = JSON.parse(await file.text());
    if (!envelope || typeof envelope !== "object") throw new Error("تنسيق النسخة غير مدعوم.");
    if(envelope.format==="lamin-offline-backup-v1"){
      if(String(envelope.school_id)!==String(state.school.id)||String(envelope.school_code||"")!==String(state.school.code||""))throw new Error("هذه النسخة المحلية لا تخص المدرسة الحالية.");
      if(!envelope.snapshot?.profile||!envelope.snapshot?.school||!envelope.snapshot?.data||!Array.isArray(envelope.queue))throw new Error("ملف النسخة المحلية غير مكتمل أو تالف.");
      const allowedTables=new Set(["students","teachers","staff","classes","attendance","student_results","assessments","student_fee_assessments","payments","expenses","payroll_transactions"]);
      const allowedActions=new Set(["insert","update","archive","rpc_student","rpc_payment","upsert"]);
      if(envelope.queue.some(op=>!allowedTables.has(op.table)||!allowedActions.has(op.action)))throw new Error("تحتوي النسخة على عمليات محلية غير معتمدة.");
      state.backup={__localOfflineBackup:true,envelope};state.backupFileName=file.name;
      const preview=$("backup-preview");preview.classList.remove("hidden");preview.innerHTML=`<strong>نسخة محلية صالحة مبدئياً</strong><div>الملف: ${escapeHtml(file.name)}</div><div>المدرسة: ${escapeHtml(envelope.school_name||state.school.name)}</div><div>تاريخ النسخة: ${escapeHtml(formatDateTime(envelope.exported_at))}</div><div>الطلاب المحفوظون: ${(envelope.snapshot.data.students||[]).length}</div><div>التغييرات المعلّقة: ${envelope.queue.length}</div><span class="muted">ستُستعاد محلياً على هذا الجهاز، ولن تُستبدل بيانات الخادم بهذه النسخة.</span>`;
      showMessage("restore-status","تم التحقق من النسخة المحلية وهوية المدرسة. يمكنك استعادتها محلياً.");updateRestoreButton();return;
    }
    const payload = envelope.format === "lamin-school-backup" && envelope.version === 2 ? envelope.data : envelope;
    const schoolId = envelope.format === "lamin-school-backup" ? envelope.school_id : payload?.school_filter;
    if (String(schoolId) !== String(state.school.id) || String(payload?.school_filter) !== String(state.school.id) || payload?.format !== "lamin-school-backup-v2") throw new Error("هذه النسخة لا تخص المدرسة الحالية أو تنسيقها غير مدعوم.");
    for(const key of ["academic_years","classes","students","teachers","staff","student_fee_assessments","payments","attendance","student_results","expenses","payroll_transactions"]) if(payload[key]!==undefined&&!Array.isArray(payload[key])) throw new Error("بنية النسخة غير سليمة في قسم: "+key);
    state.backup = payload; state.backupFileName = file.name;
    const preview = $("backup-preview"); preview.classList.remove("hidden");
    preview.innerHTML = `<strong>النسخة صالحة مبدئياً</strong><div>الملف: ${escapeHtml(file.name)}</div><div>المدرسة: ${escapeHtml(payload.school_name||envelope.school_name||state.school.name)}</div><div>تاريخ النسخة: ${escapeHtml(formatDateTime(payload.taken_at||envelope.created_at||payload.exported_at))}</div><div>الإصدار: 2</div><div>عدد الطلاب: ${(payload.students||[]).length}</div><div>عدد الرسوم: ${(payload.student_fee_assessments||[]).length}</div><div>عدد الدفعات: ${(payload.payments||[]).length}</div><span class="muted">الاستعادة تدمج السجلات الناقصة ولا تستبدل السجلات الحالية.</span>`;
    showMessage("restore-status", "تم التحقق من الملف وهوية المدرسة. يمكنك تنفيذ الاستعادة.");
    updateRestoreButton();
  } catch (error) { showMessage("restore-status", error?.message || "تعذر قراءة الملف.", true); }
}
function updateRestoreButton() {
  $("restore-backup").disabled = !(state.backup && $("restore-confirm").checked);
}
async function restoreBackup() {
  if (!state.backup || !$("restore-confirm").checked) return;
  if (state.profile?.role !== "admin") { showMessage("restore-status", "الاستعادة متاحة لمدير المدرسة فقط وفق صلاحيات الخادم.", true); return; }
  if(state.backup.__localOfflineBackup){
    const envelope=state.backup.envelope;
    try{localStorage.setItem(OFFLINE_SNAPSHOT_PREFIX+state.school.id,JSON.stringify(envelope.snapshot));writeOfflineQueue(envelope.queue);state.profile={...state.profile};state.school=envelope.snapshot.school;Object.assign(state,envelope.snapshot.data);state.offline=!navigator.onLine;renderManagedTables();switchView(true);setOfflineMode(!navigator.onLine);showMessage("restore-status","تمت استعادة البيانات محلياً. لم تتغير قاعدة بيانات المدرسة؛ وستُزامن العمليات المعلّقة عند عودة الاتصال.");$("backup-preview").classList.add("hidden");state.backup=null;if(navigator.onLine&&readOfflineQueue().length)syncOfflineQueue().catch(error=>showMessage("restore-status",error.message||"تعذرت مزامنة العمليات المحلية.",true));return;}catch(error){showMessage("restore-status",error.message||"تعذرت الاستعادة المحلية.",true);return;}
  }
  const btn = $("restore-backup"); btn.disabled = true;
  showMessage("restore-status", "جارٍ إرسال النسخة إلى إجراء الاستعادة المحمي على الخادم…");
  try {
    // The server-side RPC remains authoritative for authorization, schema checks,
    // school scope, audit logging and transactional safety.
    const { data, error } = await db.rpc("restore_backup", { p_backup: state.backup });
    if (error) throw error;
    if (!data || typeof data !== "object" || data.ok !== true) throw new Error("لم يؤكد الخادم اكتمال الاستعادة.");
    const restored=data.restored||{}; const summary=Object.entries(restored).map(([key,count])=>key+": "+count).join(" · ");
    showMessage("restore-status", "تمت الاستعادة بنجاح. السجلات المضافة: "+(summary||"تم الدمج دون تفاصيل إضافية")+".");
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
$("create-backup").addEventListener("click", () => createBackup());
$("backup-file").addEventListener("change", (e) => inspectBackup(e.target.files?.[0]));
$("restore-confirm").addEventListener("change", updateRestoreButton);
$("restore-backup").addEventListener("click", () => { if(state.backup?.__localOfflineBackup){restoreBackup();return;} if (state.offline || !navigator.onLine) { showMessage("restore-status", "استعادة نسخة الخادم تتطلب اتصالاً بالإنترنت. يمكن استعادة النسخ المحلية دون اتصال.", true); return; } restoreBackup(); });
$("export-students").addEventListener("click", () => csvDownload("lamin-students.csv", [["الاسم","الصف","الهاتف","الحالة"], ...state.students.map((s) => [s.name, s.class_name, s.phone, s.status])]));
$("export-attendance").addEventListener("click", () => csvDownload("lamin-attendance.csv", [["الطالب","التاريخ","الحالة","التأخير بالدقائق"], ...state.attendance.map((a) => [state.students.find(s=>s.id===a.student_id)?.name||"",formatDate(a.attendance_date),a.status,a.minutes_late])]));
const feeForm = $("fee-edit-form");
$("fees-table").addEventListener("click", event => {
  const button = event.target.closest("[data-fee-edit]");
  if (!button) return;
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
  if (!["admin","owner","accountant"].includes(state.profile?.role)) { showMessage("fee-edit-status", "ليست لديك صلاحية تعديل الرسوم.", true); return; }
  const id = $("fee-edit-id").value;
  const totalFee = Number($("fee-edit-total").value);
  const discount = Number($("fee-edit-discount").value);
  if (!Number.isFinite(totalFee) || !Number.isFinite(discount) || totalFee < 0 || discount < 0 || discount > totalFee) {
    showMessage("fee-edit-status", "تحقق من الرسوم والخصم؛ يجب ألا يتجاوز الخصم قيمة الرسوم.", true); return;
  }
  if (state.offline || !navigator.onLine) {
    const payload={total_fee:totalFee,discount,note:$("fee-edit-note").value.trim()};
    queueOfflineChange({action:"update",table:"assessments",record_id:id,payload});
    const item=state.assessments.find(a=>String(a.id)===String(id));
    if(item) Object.assign(item,payload,{_pending:true});
    feeForm.classList.add("hidden"); showMessage("app-message","حُفظ تعديل الرسوم محلياً وسيُزامن عند عودة الإنترنت."); return;
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

function openStudentForm(record = null) {
  $("student-form").reset(); $("student-id").value = record?.id || "";
  $("student-name").value = record?.name || ""; $("student-class").value = record?.class_name || "";
  $("student-phone").value = record?.phone || "";
  $("student-form-title").textContent = record ? "تعديل بيانات الطالب" : "إضافة طالب";
  $("student-form").classList.remove("hidden"); $("student-form").scrollIntoView({behavior:"smooth",block:"center"});
}
function openTeacherForm(record = null) {
  $("teacher-form").reset(); $("teacher-id").value = record?.id || "";
  $("teacher-name").value = record?.name || ""; $("teacher-subject").value = record?.subject || "";
  $("teacher-phone").value = record?.phone || ""; $("teacher-salary").value = record?.salary ?? "";
  $("teacher-form-title").textContent = record ? "تعديل بيانات المعلم" : "إضافة معلم";
  $("teacher-form").classList.remove("hidden"); $("teacher-form").scrollIntoView({behavior:"smooth",block:"center"});
}
$("student-new").addEventListener("click", () => openStudentForm());
$("student-cancel").addEventListener("click", () => $("student-form").classList.add("hidden"));
$("students-table").addEventListener("click", async event => {
  const edit = event.target.closest("[data-student-edit]");
  const archive = event.target.closest("[data-student-archive]");
  const restore = event.target.closest("[data-student-restore]");
  if(restore){if(!canManageSchool())return;const row=state.students.find(x=>String(x.id)===restore.dataset.studentRestore);if(!row)return;if(!confirm("إعادة الطالب إلى قائمة الطلاب النشطين؟"))return;try{if(state.offline||!navigator.onLine){queueOfflineChange({action:"update",table:"students",record_id:row.id,payload:{active:true}});row.active=true;row._pending=true;renderManagedTables();showMessage("app-message","تمت استعادة الطالب محلياً وستتم المزامنة عند عودة الإنترنت.");}else{const {data,error}=await db.from("students").update({active:true}).eq("id",row.id).eq("school_id",state.school.id).select("id").maybeSingle();if(error)throw error;if(!data?.id)throw new Error("لم تؤكد قاعدة البيانات استعادة الطالب.");await refreshDashboard();}}catch(error){showMessage("app-message",error.message||"تعذرت استعادة الطالب.",true);}return;}
  if (edit) { const row=state.students.find(x=>String(x.id)===edit.dataset.studentEdit); if(row) openStudentForm(row); }
  if (archive) {
    if (!canManageSchool()) return;
    const row=state.students.find(x=>String(x.id)===archive.dataset.studentArchive); if(!row) return;
    if (!confirm("ستتم أرشفة الطالب مع الاحتفاظ بسجلاته المالية والتاريخية. متابعة؟")) return;
    try {
      if (state.offline || !navigator.onLine) {
        queueOfflineChange({action:"archive",table:"students",record_id:row.id});
        row.active=false; row._pending=true; renderManagedTables();
        showMessage("app-message","حُفظت أرشفة الطالب محلياً وستتم مزامنتها عند عودة الإنترنت.");
      } else {
        const {data,error}=await db.from("students").update({active:false}).eq("id",row.id).eq("school_id",state.school.id).select("id").maybeSingle();
        if(error) throw error; if(!data?.id) throw new Error("لم تؤكد قاعدة البيانات الأرشفة.");
        await refreshDashboard();
      }
    } catch(error) { showMessage("app-message",error.message || "تعذرت أرشفة الطالب.",true); }
  }
});
$("student-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageSchool()) return;
  const id=$("student-id").value;
  const payload={name:$("student-name").value.trim(),class_name:$("student-class").value.trim(),phone:$("student-phone").value.trim()};
  const termFee=Number($("student-term-fee").value || 0);
  if(!payload.name || !Number.isFinite(termFee) || termFee<0) { showMessage("student-status","تحقق من اسم الطالب ورسوم الفصل.",true); return; }
  try {
    if(state.offline || !navigator.onLine) { queueStudentLocally({id,payload,termFee}); return; }
    const result=id
      ? await db.from("students").update(payload).eq("id",id).eq("school_id",state.school.id).select("id").maybeSingle()
      : await db.rpc("create_student_with_fee",{p_name:payload.name,p_class_name:payload.class_name,p_phone:payload.phone || "",p_term_fee:termFee,p_term:"الفصل الأول"});
    if(result.error) throw result.error; if(id && !result.data?.id) throw new Error("لم تؤكد قاعدة البيانات تحديث الطالب."); if(!id && !result.data) throw new Error("لم يؤكد الخادم إنشاء الطالب والرسوم.");
    $("student-form").classList.add("hidden"); await refreshDashboard(); showMessage("app-message",id?"تم تحديث بيانات الطالب.":"تمت إضافة الطالب.");
  } catch(error) { if(isNetworkFetchError(error)||!navigator.onLine){queueStudentLocally({id,payload,termFee});return;} showMessage("student-status",error.message || "تعذر حفظ الطالب.",true); }
});
$("teacher-new").addEventListener("click", () => openTeacherForm());
$("teacher-cancel").addEventListener("click", () => $("teacher-form").classList.add("hidden"));
$("teachers-table").addEventListener("click", event => {
  const button=event.target.closest("[data-teacher-edit]"); if(!button) return;
  const row=state.teachers.find(x=>String(x.id)===button.dataset.teacherEdit); if(row) openTeacherForm(row);
});
$("teacher-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageSchool()) return;
  const id=$("teacher-id").value;
  const salary=$("teacher-salary").value.trim();
  const payload={name:$("teacher-name").value.trim(),subject:$("teacher-subject").value.trim(),phone:$("teacher-phone").value.trim() || "",salary:salary===""?null:Number(salary)};
  if(!payload.name || (payload.salary!==null && (!Number.isFinite(payload.salary)||payload.salary<0))) { showMessage("teacher-status","تحقق من الاسم والراتب.",true); return; }
  try {
    if(state.offline || !navigator.onLine) {
      if(id) { queueOfflineChange({action:"update",table:"teachers",record_id:id,payload}); const row=state.teachers.find(x=>String(x.id)===id); if(row) Object.assign(row,payload,{_pending:true}); }
      else { const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now())); queueOfflineChange({action:"insert",table:"teachers",local_id:localId,payload:{...payload,school_id:state.school.id}}); state.teachers.unshift({...payload,school_id:state.school.id,id:localId,_pending:true}); }
      renderManagedTables(); $("teacher-form").classList.add("hidden"); showMessage("app-message","حُفظت بيانات المعلم محلياً وستتم مزامنتها عند عودة الإنترنت."); return;
    }
    const result=id
      ? await db.from("teachers").update(payload).eq("id",id).eq("school_id",state.school.id).select("id").maybeSingle()
      : await db.from("teachers").insert({...payload,school_id:state.school.id}).select("id").single();
    if(result.error) throw result.error; if(!result.data?.id) throw new Error("لم تؤكد قاعدة البيانات حفظ المعلم.");
    $("teacher-form").classList.add("hidden"); await refreshDashboard(); showMessage("app-message",id?"تم تحديث بيانات المعلم.":"تمت إضافة المعلم.");
  } catch(error) { showMessage("teacher-status",error.message || "تعذر حفظ المعلم.",true); }
});
$("expense-new").addEventListener("click", () => { $("expense-form").reset(); $("expense-form").classList.remove("hidden"); });
$("expense-cancel").addEventListener("click", () => $("expense-form").classList.add("hidden"));
$("expense-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageFinance()) return;
  const payload={title:$("expense-title").value.trim(),category:$("expense-category").value.trim(),amount:Number($("expense-amount").value),school_id:state.school.id};
  if(!payload.title || !Number.isFinite(payload.amount) || payload.amount<=0) { showMessage("expense-status","أدخل بياناً ومبلغاً صحيحاً.",true); return; }
  try {
    if(state.offline || !navigator.onLine) {
      const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));
      queueOfflineChange({action:"insert",table:"expenses",local_id:localId,payload});
      state.expenses.unshift({...payload,id:localId,created_at:new Date().toISOString(),_pending:true});
      renderManagedTables(); $("expense-form").classList.add("hidden"); showMessage("app-message","حُفظ المصروف محلياً وسيُزامن عند عودة الإنترنت."); return;
    }
    const {data,error}=await db.from("expenses").insert(payload).select("id").single();
    if(error) throw error; if(!data?.id) throw new Error("لم تؤكد قاعدة البيانات حفظ المصروف.");
    $("expense-form").classList.add("hidden"); await refreshDashboard(); showMessage("app-message","تم تسجيل المصروف.");
  } catch(error) { showMessage("expense-status",error.message || "تعذر حفظ المصروف.",true); }
});
async function findExistingQueuedStudent(op) {
  const params=op.params||{},name=String(params.p_name||"").trim().toLocaleLowerCase("ar"),phone=String(params.p_phone||"").replace(/[^0-9]/g,"");
  if(!name)return null;
  const {data,error}=await db.from("students").select("id,name,phone,current_academic_year_id").eq("school_id",state.school.id).eq("phone",phone).limit(100);
  if(error)throw error;
  const existing=(data||[]).find(row=>String(row.name||"").trim().toLocaleLowerCase("ar")===name);
  if(!existing)return null;
  const fee=Number(params.p_term_fee||0);
  if(fee>0){
    let query=db.from("student_fee_assessments").select("id,total_fee,term").eq("school_id",state.school.id).eq("student_id",existing.id).eq("term",String(params.p_term||"الفصل الأول"));
    query=existing.current_academic_year_id?query.eq("academic_year_id",existing.current_academic_year_id):query.is("academic_year_id",null);
    const {data:fees,error:feeError}=await query.limit(20);
    if(feeError)throw feeError;
    if(!(fees||[]).some(row=>Math.abs(Number(row.total_fee||0)-fee)<0.005))return {conflict:true,student:existing};
  }
  return {student:existing};
}
async function syncOfflineQueue() {
  if(state.syncing || !navigator.onLine || !state.school || !state.profile) return;
  state.syncing=true;
  let remaining=[];
  try {
    const queue=readOfflineQueue();
    if(!queue.length){setOfflineMode(false);return;}
    remaining=[...queue];
    showMessage("app-message","جارٍ مزامنة التغييرات المحفوظة دون إنترنت…");
    while(remaining.length) {
      const op=remaining[0]; let result;
      if(op.action==="insert") { const payload={...op.payload}; delete payload.id; result=await db.from(op.table).insert(payload); }
      else if(op.action==="rpc_student") result=await db.rpc("create_student_with_fee",op.params);
      else if(op.action==="rpc_payment") result=await db.rpc("record_student_payment",op.params);
      else if(op.action==="upsert") result=await db.from(op.table).upsert(op.payload);
      else if(op.action==="update") result=await db.from(op.table === "assessments" ? "student_fee_assessments" : op.table).update(op.payload).eq("id",op.record_id).eq("school_id",state.school.id);
      else if(op.action==="archive") result=await db.from(op.table).update({active:false}).eq("id",op.record_id).eq("school_id",state.school.id);
      else throw new Error("تعذر تحديد نوع التغيير المحلي.");
      if(result.error && op.action==="rpc_student" && (result.error.code==="23505" || /students_dup_uq|duplicate key/i.test(result.error.message||""))) {
        try {
          const match=await findExistingQueuedStudent(op);
          if(match?.student && !match.conflict){remaining.shift();writeOfflineQueue(remaining);continue;}
          if(match?.conflict){writeOfflineQueue(remaining);showMessage("app-message","تعذرت مزامنة طالب موجود مسبقاً: رسوم الفصل المسجلة لا تطابق الرسوم المعلقة. احتفظنا بالتغيير للمراجعة ولم نغيّر الرسوم.",true);return;}
        } catch(reconcileError){writeOfflineQueue(remaining);showMessage("app-message","تعذر التحقق من الطالب الموجود. احتفظنا بالتغيير محلياً دون حذفه.",true);return;}
        writeOfflineQueue(remaining);showMessage("app-message","يوجد طالب بالاسم ورقم الهاتف نفسيهما في قاعدة البيانات. احتفظنا بالتغيير محلياً ولم ننشئ سجلاً مكرراً.",true);return;
      }
      if(result.error){writeOfflineQueue(remaining);showMessage("app-message","بقيت تغييرات غير متزامنة ومحفوظة على الجهاز: "+result.error.message,true);return;}
      remaining.shift();writeOfflineQueue(remaining);
    }
    setOfflineMode(false);await refreshDashboard();showMessage("app-message","اكتملت مزامنة التغييرات المحلية.");
  } catch(error) {
    writeOfflineQueue(remaining.length?remaining:readOfflineQueue());
    showMessage("app-message","تعذرت المزامنة مؤقتاً. احتفظنا بالتغييرات على هذا الجهاز: "+(error?.message||"خطأ في الاتصال."),true);
  } finally { state.syncing=false; }
}


$("attendance-date").value = new Date().toISOString().slice(0,10);
$("attendance-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageSchool()) return;
  const payload={student_id:$("attendance-student").value,attendance_date:$("attendance-date").value,status:$("attendance-status").value,minutes_late:Number($("attendance-late").value||0),school_id:state.school.id};
  if(!payload.student_id || !payload.attendance_date || !Number.isInteger(payload.minutes_late) || payload.minutes_late<0) { showMessage("attendance-status-message","تحقق من بيانات الحضور.",true); return; }
  try {
    if(state.offline || !navigator.onLine) {
      queueOfflineChange({action:"upsert",table:"attendance",payload});
      const old=state.attendance.find(a=>a.student_id===payload.student_id&&a.attendance_date===payload.attendance_date);
      if(old) Object.assign(old,payload,{_pending:true}); else state.attendance.unshift({...payload,_pending:true});
      showMessage("attendance-status-message","حُفظ الحضور محلياً وسيُزامن عند عودة الإنترنت.");
    } else {
      const {error}=await db.from("attendance").upsert(payload); if(error) throw error;
      await refreshDashboard(); showMessage("attendance-status-message","تم حفظ الحضور.");
    }
  } catch(error) { showMessage("attendance-status-message",error.message || "تعذر حفظ الحضور.",true); }
});
$("result-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageSchool()) return;
  const score=Number($("result-score").value), max=Number($("result-max").value);
  const payload={student_id:$("result-student").value,term:$("result-term").value.trim(),exam_name:$("result-exam").value.trim(),score,max_score:max,school_id:state.school.id};
  if(!payload.student_id || !payload.term || !payload.exam_name || !Number.isFinite(score) || !Number.isFinite(max) || max<=0 || score<0 || score>max) { showMessage("result-status","تحقق من الطالب والاختبار والدرجة.",true); return; }
  try {
    if(state.offline || !navigator.onLine) {
      const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));
      queueOfflineChange({action:"insert",table:"student_results",local_id:localId,payload});
      state.results.unshift({...payload,id:localId,_pending:true}); showMessage("result-status","حُفظت النتيجة محلياً وستُزامن عند عودة الإنترنت.");
    } else {
      const {error}=await db.from("student_results").insert(payload); if(error) throw error;
      await refreshDashboard(); showMessage("result-status","تم حفظ النتيجة.");
    }
  } catch(error) { showMessage("result-status",error.message || "تعذر حفظ النتيجة.",true); }
});



$("class-new").addEventListener("click",()=>{$("class-form").reset();$("class-id").value="";$("class-form").classList.remove("hidden");});
$("class-cancel").addEventListener("click",()=> $("class-form").classList.add("hidden"));
$("classes-table").addEventListener("click",event=>{const button=event.target.closest("[data-class-edit]");if(!button)return;const row=(state.classes||[]).find(x=>String(x.id)===button.dataset.classEdit);if(!row)return;$("class-id").value=row.id;$("class-name").value=row.name||"";$("class-section").value=row.section||"";$("class-form").classList.remove("hidden");});
$("class-form").addEventListener("submit",async event=>{
  event.preventDefault();if(!canManageSchool())return;
  const id=$("class-id").value;const payload={name:$("class-name").value.trim(),section:$("class-section").value.trim()};
  if(!payload.name){showMessage("class-status","اسم الصف مطلوب.",true);return;}
  try{if(state.offline||!navigator.onLine){if(id){queueOfflineChange({action:"update",table:"classes",record_id:id,payload});const row=state.classes.find(x=>String(x.id)===id);if(row)Object.assign(row,payload,{_pending:true});}
    else{const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));queueOfflineChange({action:"insert",table:"classes",local_id:localId,payload:{...payload,school_id:state.school.id}});state.classes.unshift({...payload,id:localId,_pending:true});}
    $("class-form").classList.add("hidden");renderManagedTables();showMessage("app-message","حُفظ الصف محلياً وسيُزامن عند عودة الإنترنت.");return;}
    let yearId=null;const activeYear=await db.from("academic_years").select("id").eq("active",true).order("created_at",{ascending:false}).limit(1).maybeSingle();if(!activeYear.error)yearId=activeYear.data?.id||null;
    const data=id?await db.from("classes").update(payload).eq("id",id).eq("school_id",state.school.id).select("id").maybeSingle():await db.from("classes").insert({...payload,school_id:state.school.id,...(yearId?{academic_year_id:yearId}:{})}).select("id").single();
    if(data.error)throw data.error;if(!data.data?.id)throw new Error("لم تؤكد قاعدة البيانات حفظ الصف.");$("class-form").classList.add("hidden");await refreshDashboard();}
  catch(error){showMessage("class-status",error.message||"تعذر حفظ الصف.",true);}
});

$("staff-new").addEventListener("click",()=>{ $("staff-form").reset(); $("staff-id").value=""; $("staff-form").classList.remove("hidden"); });
$("staff-cancel").addEventListener("click",()=> $("staff-form").classList.add("hidden"));
$("staff-table").addEventListener("click",async event=>{
  const edit=event.target.closest("[data-staff-edit]"), archive=event.target.closest("[data-staff-archive]"), restore=event.target.closest("[data-staff-restore]");
  if(restore){const row=state.staff.find(x=>String(x.id)===restore.dataset.staffRestore);if(!row||!canManageSchool()||!confirm("إعادة الموظف إلى قائمة الموظفين النشطين؟"))return;try{if(state.offline||!navigator.onLine){queueOfflineChange({action:"update",table:"staff",record_id:row.id,payload:{active:true}});row.active=true;row._pending=true;renderManagedTables();showMessage("app-message","تمت استعادة الموظف محلياً وستتم المزامنة عند عودة الإنترنت.");}else{const {data,error}=await db.from("staff").update({active:true}).eq("id",row.id).eq("school_id",state.school.id).select("id").maybeSingle();if(error)throw error;if(!data?.id)throw new Error("لم تؤكد قاعدة البيانات استعادة الموظف.");await refreshDashboard();}}catch(error){showMessage("staff-status",error.message||"تعذرت استعادة الموظف.",true);}return;}
  if(edit){const row=state.staff.find(x=>String(x.id)===edit.dataset.staffEdit);if(row){$("staff-id").value=row.id;$("staff-name").value=row.name||"";$("staff-role").value=row.role||"";$("staff-phone").value=row.phone||"";$("staff-salary").value=row.salary??0;$("staff-form").classList.remove("hidden");}}
  if(archive){const row=state.staff.find(x=>String(x.id)===archive.dataset.staffArchive);if(!row||!confirm("أرشفة الموظف مع الاحتفاظ بسجل الرواتب؟"))return;
    try{if(state.offline||!navigator.onLine){queueOfflineChange({action:"update",table:"staff",record_id:row.id,payload:{active:false}});row.active=false;renderManagedTables();showMessage("app-message","حُفظت أرشفة الموظف محلياً.");}
    else{const {data,error}=await db.from("staff").update({active:false}).eq("id",row.id).eq("school_id",state.school.id).select("id").maybeSingle();if(error)throw error;if(!data?.id)throw new Error("لم تؤكد قاعدة البيانات الأرشفة.");await refreshDashboard();}}
    catch(error){showMessage("staff-status",error.message||"تعذرت أرشفة الموظف.",true);}}
});
$("staff-form").addEventListener("submit",async event=>{
  event.preventDefault();if(!canManageSchool())return;
  const id=$("staff-id").value;const payload={name:$("staff-name").value.trim(),role:$("staff-role").value.trim(),phone:$("staff-phone").value.trim() || "",salary:Number($("staff-salary").value)};
  if(!payload.name||!payload.role||!Number.isFinite(payload.salary)||payload.salary<0){showMessage("staff-status","تحقق من الاسم والوظيفة والراتب.",true);return;}
  try{if(state.offline||!navigator.onLine){if(id){queueOfflineChange({action:"update",table:"staff",record_id:id,payload});const row=state.staff.find(x=>String(x.id)===id);if(row)Object.assign(row,payload,{_pending:true});}
    else{const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));queueOfflineChange({action:"insert",table:"staff",local_id:localId,payload:{...payload,school_id:state.school.id,active:true}});state.staff.unshift({...payload,id:localId,active:true,_pending:true});}
    $("staff-form").classList.add("hidden");renderManagedTables();showMessage("app-message","حُفظت بيانات الموظف محلياً وستُزامن عند عودة الإنترنت.");return;}
    const result=id?await db.from("staff").update(payload).eq("id",id).eq("school_id",state.school.id).select("id").maybeSingle():await db.from("staff").insert({...payload,school_id:state.school.id,active:true}).select("id").single();
    if(result.error)throw result.error;if(!result.data?.id)throw new Error("لم تؤكد قاعدة البيانات حفظ الموظف.");$("staff-form").classList.add("hidden");await refreshDashboard();}
  catch(error){showMessage("staff-status",error.message||"تعذر حفظ الموظف.",true);}
});
$("student-search")?.addEventListener("input", renderManagedTables);
$("student-class-filter")?.addEventListener("input", renderManagedTables);
$("payroll-payee-type").addEventListener("change",renderManagedTables);
$("payroll-date").value=new Date().toISOString().slice(0,10);
$("payroll-form").addEventListener("submit",async event=>{
  event.preventDefault();if(!canManageFinance())return;
  const payload={payee_type:$("payroll-payee-type").value,payee_id:$("payroll-payee").value,transaction_type:$("payroll-type").value,amount:Number($("payroll-amount").value),payment_date:$("payroll-date").value,note:$("payroll-note").value.trim(),school_id:state.school.id};
  if(!payload.payee_id||!Number.isFinite(payload.amount)||payload.amount<=0||!payload.payment_date){showMessage("payroll-status","تحقق من المستفيد والمبلغ والتاريخ.",true);return;}
  try{if(state.offline||!navigator.onLine){const localId="offline-"+(crypto.randomUUID?crypto.randomUUID():String(Date.now()));queueOfflineChange({action:"insert",table:"payroll_transactions",local_id:localId,payload});state.payroll.unshift({...payload,id:localId,_pending:true});$("payroll-form").reset();$("payroll-date").value=new Date().toISOString().slice(0,10);renderManagedTables();showMessage("payroll-status","حُفظت العملية محلياً وستُزامن عند عودة الإنترنت.");return;}
    const {error}=await db.from("payroll_transactions").insert(payload);if(error)throw error;$("payroll-form").reset();$("payroll-date").value=new Date().toISOString().slice(0,10);await refreshDashboard();showMessage("payroll-status","تم تسجيل العملية المالية.");}
  catch(error){showMessage("payroll-status",error.message||"تعذر تسجيل العملية.",true);}
});

$("payment-form").addEventListener("submit", async event => {
  event.preventDefault(); if(!canManageFinance()) return;
  const assessmentId=$("payment-assessment").value;
  const assessment=state.assessments.find(a=>String(a.id)===String(assessmentId));
  const amount=Number($("payment-amount").value);
  if(!assessment || !Number.isFinite(amount) || amount<=0) { showMessage("payment-status","اختر بند رسوم وأدخل مبلغاً صحيحاً.",true); return; }
  const idempotencyKey=crypto.randomUUID?crypto.randomUUID():("lamin-pay-"+Date.now()+"-"+Math.random().toString(36).slice(2));
  const params={p_student_id:assessment.student_id,p_amount:amount,p_note:$("payment-note").value.trim(),p_term:assessment.term||"غير محدد",p_fee_assessment_id:assessment.id,p_idempotency_key:idempotencyKey};
  const saveOffline=()=>{
    const localId="offline-"+idempotencyKey;
    queueOfflineChange({action:"rpc_payment",table:"payments",local_id:localId,params});
    state.payments=state.payments||[];
    if(!state.payments.some(p=>p.id===localId))state.payments.push({id:localId,student_id:assessment.student_id,fee_assessment_id:assessment.id,term:assessment.term||"غير محدد",amount,note:params.p_note,created_at:new Date().toISOString(),_pending:true});
    showMessage("payment-status","حُفظت الدفعة محلياً. ستُسجل وتوزع على الرسوم تلقائياً عند عودة الاتصال.");
    $("payment-form").reset();renderManagedTables();
  };
  try {
    if(state.offline || !navigator.onLine){saveOffline();return;}
    const {data,error}=await db.rpc("record_student_payment",params);
    if(error)throw error;
    if(!data)throw new Error("لم يؤكد الخادم تسجيل الدفعة.");
    $("payment-form").reset();await refreshDashboard();showMessage("payment-status","تم تسجيل الدفعة وتوزيعها على المستحقات وتحديث الرصيد.");
  } catch(error) {
    if(!navigator.onLine || error instanceof TypeError || error?.name==="FunctionsFetchError"){saveOffline();return;}
    showMessage("payment-status",error.message || "تعذر تسجيل الدفعة. لم تُسجل كعملية ناجحة.",true);
  }
});
$("export-fees").addEventListener("click", () => csvDownload("lamin-fees-summary.csv", [["الطالب","السنة","الفصل","الرسوم","الخصم"], ...state.assessments.map((a) => [state.students.find(s=>s.id===a.student_id)?.name||"",a.academic_year_label,a.term,a.total_fee,a.discount])]));
$("export-finance").addEventListener("click", () => csvDownload("lamin-finance-summary.csv", [["البند","القيمة"],["المقبوضات", $("finance-payments").textContent],["المصروفات", $("finance-expenses").textContent],["الرواتب والسلف", $("finance-payroll").textContent],["الرسوم المقدرة", $("fees-total").textContent],["المدفوع", $("fees-paid").textContent],["الرصيد التقريبي", $("fees-balance").textContent]]));
$("export-staff").addEventListener("click", () => csvDownload("lamin-teachers.csv", [["الاسم","التخصص","الهاتف","الراتب"], ...state.teachers.map((t) => [t.name,t.subject,t.phone,t.salary])]));
$("export-audit").addEventListener("click", () => csvDownload("lamin-audit-log.csv", [["التاريخ","المستخدم","العملية","الكيان","التفاصيل"], ...state.audit.map((a) => [formatDateTime(a.created_at),a.username,a.action,a.entity,JSON.stringify(a.details||{})])]));
$("settings-refresh").addEventListener("click", () => loadPortal().catch(e=>showMessage("app-message", "تعذر تحديث بيانات المدرسة.", true)));
$("export-xlsx").addEventListener("click", async () => {
  try {
    showMessage("app-message", "جارٍ تجهيز ملف Excel…");
    const XLSX = await import("https://esm.sh/xlsx@0.18.5");
    const workbook = XLSX.utils.book_new();
    const sheets = [
      ["الطلاب", [["الاسم","الصف","الهاتف","الحالة"], ...state.students.map(s=>[s.name,s.class_name,s.phone,s.status])]],
      ["المعلمون", [["الاسم","التخصص","الهاتف","الراتب"], ...state.teachers.map(t=>[t.name,t.subject,t.phone,t.salary])]],
      ["الحضور", [["الطالب","التاريخ","الحالة","التأخير بالدقائق"], ...state.attendance.map(a=>[state.students.find(s=>s.id===a.student_id)?.name||"",formatDate(a.attendance_date),a.status,a.minutes_late])]],
      ["الرسوم", [["الطالب","السنة","الفصل","الرسوم","الخصم"], ...state.assessments.map(a=>[state.students.find(s=>s.id===a.student_id)?.name||"",a.academic_year_label,a.term,a.total_fee,a.discount])]],
      ["التدقيق", [["التاريخ","المستخدم","العملية","الكيان","التفاصيل"], ...state.audit.map(a=>[formatDateTime(a.created_at),a.username,a.action,a.entity,JSON.stringify(a.details||{})])]]
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
window.addEventListener("online", () => { if (state.profile) syncOfflineQueue().catch(error => showMessage("app-message", error.message || "تعذرت المزامنة.", true)); });
window.addEventListener("offline", () => { if (state.profile) setOfflineMode(true); });
(async () => {
  try {
    const { data } = await db.auth.getSession();
    if (data.session && navigator.onLine) await loadPortal();
    else if (!navigator.onLine) { /* Offline access requires the explicit local credential check in the login form. */ }
  } catch (error) {
    console.error(error);
    if (!restoreOfflinePortal()) switchView(false);
  }
})();
