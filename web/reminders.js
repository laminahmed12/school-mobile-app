const $ = (id) => document.getElementById(id);
const escapeHtml = (value) => String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));
const styles = document.createElement("style");
styles.textContent = `
.audit-tools{display:grid;grid-template-columns:minmax(180px,1fr) 180px auto;gap:10px;margin:18px 0}
.audit-tools input,.audit-tools select,.reminder-form input,.reminder-form textarea,.reminder-form select{width:100%;background:#081a16;border:1px solid #36584c;color:var(--text);padding:11px 12px;border-radius:10px;font:inherit}
.audit-detail summary{cursor:pointer;color:var(--gold);font-size:12px}
.audit-detail pre{white-space:pre-wrap;overflow-wrap:anywhere;max-width:520px;max-height:240px;overflow:auto;background:#081a16;padding:10px;border-radius:8px;font:12px/1.7 ui-monospace,monospace;direction:ltr;text-align:left}
.audit-tag{display:inline-block;border:1px solid var(--line);border-radius:99px;padding:4px 9px;font-size:12px;white-space:nowrap}
.reminder-panel{margin-bottom:20px}
.reminder-form{display:grid;grid-template-columns:1.2fr 1fr 1fr;gap:12px;margin-top:16px}
.reminder-form .wide{grid-column:1/-1}
.reminder-form label{display:block;color:var(--muted);font-size:13px;margin-bottom:6px}
.reminder-actions{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.reminder-list{display:grid;gap:10px;margin-top:16px}
.reminder-item{display:flex;justify-content:space-between;align-items:flex-start;gap:14px;border:1px solid var(--line);background:#0b211b;border-radius:12px;padding:14px}
.reminder-item.overdue{border-color:#a63d43}
.reminder-item h3{margin:0 0 5px;font-size:15px}
.reminder-item p{margin:4px 0;color:var(--muted);font-size:13px;line-height:1.7}
.reminder-item .due{color:var(--gold);font-size:12px}
.reminder-empty{padding:16px;border:1px dashed var(--line);border-radius:12px;color:var(--muted)}
.audit-empty{color:var(--muted);padding:12px}
@media(max-width:720px){.audit-tools,.reminder-form{grid-template-columns:1fr}.reminder-form .wide{grid-column:auto}.reminder-item{flex-direction:column}}
@media print{.reminder-panel,.audit-tools,.report-actions{display:none!important}}
`;
document.head.append(styles);

const reports = $("panel-reports");
if (reports) {
  const reminderPanel = document.createElement("section");
  reminderPanel.className = "panel reminder-panel";
  reminderPanel.innerHTML = `
    <div class="section-heading"><div><h2>التذكيرات والتنبيهات</h2><p class="muted">أنشئ تذكيرًا بموعد تحصيل أو متابعة أو مهمة إدارية. تحفظ التذكيرات في هذا المتصفح لهذا الحساب/المدرسة.</p></div><button class="button button-secondary" id="reminder-notifications" type="button">تفعيل إشعارات التذكير</button></div>
    <form class="reminder-form" id="reminder-form">
      <div><label for="reminder-title">عنوان التذكير</label><input id="reminder-title" required maxlength="120" placeholder="مثال: متابعة دفعة متأخرة"></div>
      <div><label for="reminder-due">الموعد</label><input id="reminder-due" type="datetime-local" required></div>
      <div><label for="reminder-priority">الأولوية</label><select id="reminder-priority"><option value="normal">عادية</option><option value="high">مهمة</option><option value="urgent">عاجلة</option></select></div>
      <div class="wide"><label for="reminder-notes">ملاحظات (اختياري)</label><textarea id="reminder-notes" rows="2" maxlength="1000" placeholder="تفاصيل تساعدك على تذكر المطلوب"></textarea></div>
      <div class="wide reminder-actions"><button class="button button-primary" type="submit">حفظ التذكير</button><span id="reminder-status" class="message" role="status"></span></div>
    </form>
    <div class="section-heading" style="margin-top:24px"><div><h2>قائمة التذكيرات</h2><p class="muted">يمكنك إكمال التذكير أو تعديله أو حذفه.</p></div><select id="reminder-filter" aria-label="تصفية التذكيرات"><option value="open">المفتوحة</option><option value="all">الكل</option><option value="done">المكتملة</option></select></div>
    <div id="reminder-list" class="reminder-list" aria-live="polite"></div>
    <p class="muted small">ملاحظة: الإشعار يظهر عندما تكون البوابة مفتوحة ويكون إذن الإشعارات مفعّلًا؛ لا تُرسل تذكيرات إلى الهاتف أو البريد عند إغلاق الصفحة.</p>`;
  reports.prepend(reminderPanel);
}

const schoolKey = () => {
  const code = $("setting-school-code")?.textContent?.trim();
  return "lamin-reminders-v1:" + (code && code !== "—" ? code : "local");
};
let activeStorageKey = "";
let reminders = [];
let editingReminderId = null;
const status = (message, error = false) => {
  const el = $("reminder-status");
  if (el) { el.textContent = message; el.classList.toggle("error", error); }
};
function loadReminders() {
  const nextKey = schoolKey();
  if (nextKey !== activeStorageKey) {
    activeStorageKey = nextKey;
    try { reminders = JSON.parse(localStorage.getItem(activeStorageKey) || "[]"); if (!Array.isArray(reminders)) reminders = []; }
    catch { reminders = []; }
  }
  renderReminders();
}
function saveReminders() {
  try {
    localStorage.setItem(activeStorageKey || schoolKey(), JSON.stringify(reminders));
    renderReminders();
    return true;
  } catch {
    status("تعذر الحفظ في المتصفح. تحقق من مساحة التخزين وإعدادات الخصوصية.", true);
    return false;
  }
}
function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat("ar-LY", { dateStyle: "medium", timeStyle: "short" }).format(date);
}
function renderReminders() {
  const list = $("reminder-list");
  if (!list) return;
  const filter = $("reminder-filter")?.value || "open";
  const items = reminders.filter(r => filter === "all" || (filter === "done" ? r.done : !r.done)).sort((a,b) => Number(a.done)-Number(b.done) || new Date(a.due)-new Date(b.due));
  if (!items.length) { list.innerHTML = '<div class="reminder-empty">لا توجد تذكيرات في هذا العرض. أضف تذكيرًا من النموذج أعلاه.</div>'; return; }
  list.innerHTML = items.map(r => {
    const overdue = !r.done && new Date(r.due).getTime() < Date.now();
    const priority = r.priority === "urgent" ? "عاجلة" : r.priority === "high" ? "مهمة" : "عادية";
    return `<article class="reminder-item ${overdue ? "overdue" : ""}">
      <div><h3>${escapeHtml(r.title)} ${r.done ? '<span class="audit-tag">مكتمل</span>' : overdue ? '<span class="audit-tag">فات الموعد</span>' : ""}</h3>
      <p>${escapeHtml(r.notes || "لا توجد ملاحظات")}</p><p class="due">الموعد: ${escapeHtml(formatDate(r.due))} · الأولوية: ${priority}</p></div>
      <div class="reminder-actions"><button class="button button-secondary" data-reminder-edit="${r.id}" type="button">تعديل</button><button class="button button-secondary" data-reminder-done="${r.id}" type="button">${r.done ? "إعادة فتح" : "إكمال"}</button><button class="button button-danger" data-reminder-delete="${r.id}" type="button">حذف</button></div>
    </article>`;
  }).join("");
}
$("reminder-form")?.addEventListener("submit", event => {
  event.preventDefault();
  const title = $("reminder-title").value.trim();
  const due = $("reminder-due").value;
  if (!title || !due || Number.isNaN(new Date(due).getTime())) { status("أدخل عنوانًا وموعدًا صحيحين.", true); return; }
  const updated = { title, due: new Date(due).toISOString(), priority: $("reminder-priority").value, notes: $("reminder-notes").value.trim() };
  if (editingReminderId) {
    const existing = reminders.find(r => r.id === editingReminderId);
    if (existing) Object.assign(existing, updated, { notified: false });
    editingReminderId = null;
  } else {
    reminders.push({ id: (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random()), ...updated, done: false, notified: false, createdAt: new Date().toISOString() });
  }
  if (saveReminders()) { event.currentTarget.reset(); status("تم حفظ التذكير في هذا المتصفح."); }
});
$("reminder-filter")?.addEventListener("change", renderReminders);
$("reminder-list")?.addEventListener("click", event => {
  const button = event.target.closest("button");
  if (!button) return;
  const id = button.dataset.reminderDone || button.dataset.reminderDelete || button.dataset.reminderEdit;
  const item = reminders.find(r => r.id === id);
  if (!item) return;
  if (button.dataset.reminderDone) { item.done = !item.done; item.notified = false; saveReminders(); }
  else if (button.dataset.reminderDelete) {
    if (confirm("هل تريد حذف هذا التذكير؟")) { reminders = reminders.filter(r => r.id !== id); saveReminders(); status("تم حذف التذكير."); }
  } else if (button.dataset.reminderEdit) {
    $("reminder-title").value = item.title;
    $("reminder-due").value = new Date(item.due).getTime() - new Date(item.due).getTimezoneOffset() * 60000
      ? new Date(new Date(item.due).getTime() - new Date(item.due).getTimezoneOffset() * 60000).toISOString().slice(0,16) : "";
    $("reminder-priority").value = item.priority || "normal";
    $("reminder-notes").value = item.notes || "";
    editingReminderId = id;
    $("reminder-title").focus();
    status("عدّل الحقول ثم احفظ التغييرات؛ لن يُحذف التذكير قبل الحفظ.");
  }
});
$("reminder-notifications")?.addEventListener("click", async () => {
  if (!("Notification" in window)) { status("هذا المتصفح لا يدعم إشعارات النظام؛ ستبقى التذكيرات داخل الصفحة.", true); return; }
  try {
    const permission = await Notification.requestPermission();
    status(permission === "granted" ? "تم تفعيل الإشعارات لهذا المتصفح." : "لم يمنح المتصفح إذن الإشعارات؛ يمكنك رؤية التذكيرات داخل الصفحة.");
  } catch { status("تعذر تفعيل الإشعارات في هذا المتصفح.", true); }
});
function checkDueReminders() {
  if (!("Notification" in window) || Notification.permission !== "granted") return;
  let changed = false;
  for (const r of reminders) {
    if (!r.done && !r.notified && new Date(r.due).getTime() <= Date.now()) {
      try { new Notification("لامين — تذكير", { body: r.title + (r.notes ? "\n" + r.notes : "") }); r.notified = true; changed = true; }
      catch {}
    }
  }
  if (changed) { try { localStorage.setItem(activeStorageKey, JSON.stringify(reminders)); } catch {} }
}
const auditLabels = {
  insert: "إضافة سجل", INSERT: "إضافة سجل", update: "تعديل سجل", UPDATE: "تعديل سجل",
  delete: "حذف سجل", DELETE: "حذف سجل", restore: "استعادة", RESTORE: "استعادة",
  upsert: "إضافة أو تحديث", UPSERT: "إضافة أو تحديث"
};
function enhanceAuditTable() {
  const table = $("audit-table");
  if (!table) return;
  const wrap = table.closest(".panel");
  if (wrap && !$("audit-search")) {
    const tools = document.createElement("div");
    tools.className = "audit-tools";
    tools.innerHTML = '<input id="audit-search" type="search" placeholder="ابحث باسم المستخدم أو العملية أو تفاصيلها…" aria-label="البحث في سجل التدقيق"><select id="audit-action-filter" aria-label="تصفية نوع العملية"><option value="">كل العمليات</option><option value="insert">إضافة</option><option value="update">تعديل</option><option value="delete">حذف</option><option value="restore">استعادة</option></select><button id="audit-reset" class="button button-secondary" type="button">مسح البحث</button>';
    table.closest(".table-wrap")?.before(tools);
    $("audit-search")?.addEventListener("input", filterAudit);
    $("audit-action-filter")?.addEventListener("change", filterAudit);
    $("audit-reset")?.addEventListener("click", () => { $("audit-search").value = ""; $("audit-action-filter").value = ""; filterAudit(); });
  }
  for (const row of table.querySelectorAll("tr")) {
    if (row.dataset.enhanced === "1") continue;
    row.dataset.enhanced = "1";
    const cells = row.querySelectorAll("td");
    if (cells.length !== 5) continue;
    const action = cells[2].textContent.trim();
    cells[2].innerHTML = '<span class="audit-tag">' + escapeHtml(auditLabels[action] || action || "عملية") + '</span><br><span class="muted small">' + escapeHtml(action) + '</span>';
    cells[0].textContent = formatDate(cells[0].textContent.trim());
    const raw = cells[4].textContent.trim();
    let parsed;
    try { parsed = JSON.parse(raw); } catch { parsed = raw; }
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      const labels = {
        role: "الدور", username: "اسم المستخدم", restored_from_audit_id: "مرجع سجل الاستعادة",
        student_name: "اسم الطالب", student_id: "معرّف الطالب", amount: "المبلغ",
        payment_date: "تاريخ الدفع", term: "الفصل الدراسي", academic_year_label: "السنة الدراسية",
        note: "ملاحظة", school_code: "رمز المدرسة", email: "البريد الإلكتروني",
        full_name: "الاسم الكامل", name: "الاسم", status: "الحالة", created_at: "تاريخ الإنشاء",
        updated_at: "تاريخ التحديث", deleted_at: "تاريخ الحذف", id: "المعرّف"
      };
      const valueLabels = { supervisor: "مشرف", admin: "مدير", teacher: "معلم", parent: "ولي أمر", student: "طالب", true: "نعم", false: "لا", active: "نشط", inactive: "غير نشط" };
      const entries = Object.entries(parsed);
      const summary = entries.map(([key, value]) => {
        const label = labels[key] || key.replace(/_/g, " ");
        const displayValue = value !== null && typeof value === "object" ? JSON.stringify(value) : (valueLabels[String(value)] || value);
        return '<div><strong>' + escapeHtml(label) + ':</strong> ' + escapeHtml(displayValue ?? "—") + '</div>';
      }).join("");
      const details = document.createElement("details");
      details.className = "audit-detail";
      details.innerHTML = '<summary>عرض التفاصيل (' + entries.length + ' حقول)</summary>' +
        (summary ? '<div class="backup-preview">' + summary + '</div>' : '') +
        '<details class="audit-raw"><summary>عرض البيانات التقنية الأصلية</summary><pre></pre></details>';
      details.querySelector("pre").textContent = JSON.stringify(parsed, null, 2);
      cells[4].replaceChildren(details);
      row.dataset.search = [cells[0].textContent,cells[1].textContent,action,cells[3].textContent,JSON.stringify(parsed),entries.map(([key,value]) => (labels[key] || key) + " " + value).join(" ")].join(" ").toLocaleLowerCase();
    } else row.dataset.search = row.textContent.toLocaleLowerCase();
    row.dataset.action = action.toLowerCase();
  }
  filterAudit();
}
function filterAudit() {
  const table = $("audit-table");
  if (!table) return;
  const term = ($("audit-search")?.value || "").trim().toLocaleLowerCase();
  const action = $("audit-action-filter")?.value || "";
  for (const row of table.querySelectorAll("tr")) {
    const matchText = !term || (row.dataset.search || row.textContent).includes(term);
    const rowAction = row.dataset.action || "";
    const matchAction = !action || rowAction.includes(action);
    row.hidden = !(matchText && matchAction);
  }
}
const auditBody = $("audit-table");
if (auditBody) new MutationObserver(() => enhanceAuditTable()).observe(auditBody, { childList: true });
document.querySelectorAll('.tab[data-panel="reports"]').forEach(button => button.addEventListener("click", () => { loadReminders(); enhanceAuditTable(); }));
window.addEventListener("focus", () => { loadReminders(); checkDueReminders(); });
document.addEventListener("visibilitychange", () => { if (!document.hidden) { loadReminders(); checkDueReminders(); } });
loadReminders();
checkDueReminders();
setInterval(checkDueReminders, 30000);
