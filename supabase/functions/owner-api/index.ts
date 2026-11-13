import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const fail = (message: string, status = 400) => json({ error: message }, status);

const URL_ = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(URL_, SERVICE, { auth: { persistSession: false, autoRefreshToken: false } });

// Set OWNER_PIN_HASH as a Supabase Edge Function secret (64-char SHA-256 hex).
// Never embed the owner credential or its hash in source control.
const OWNER_PIN_HASH = Deno.env.get("OWNER_PIN_HASH")?.trim().toLowerCase() ?? "";
const OWNER_PIN_CONFIGURED = /^[a-f0-9]{64}$/.test(OWNER_PIN_HASH);

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value.trim());
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
// A single server-side bucket avoids trusting spoofable client IP headers.
// The database RPC performs the check and counter update atomically.
async function checkPin(pin: string) {
  if (!OWNER_PIN_CONFIGURED) return false;
  const valid = (await sha256(pin)) === OWNER_PIN_HASH;
  const { data, error } = await admin.rpc("owner_api_consume_attempt", {
    p_pin_valid: valid,
  });
  if (error) {
    console.error("owner-api rate limiter unavailable", error.message);
    throw new Error("تعذر التحقق الأمني مؤقتاً");
  }
  return data === true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail("طريقة غير مسموحة", 405);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return fail("طلب غير صالح"); }

  const pin = String(body.pin ?? "").trim();
  if (!/^\d{6}$/.test(pin)) return fail("رمز المالك غير صحيح", 401);
  if (!OWNER_PIN_CONFIGURED) return fail("خدمة المالك غير مهيأة أمنياً", 503);
  let pinAccepted = false;
  try {
    pinAccepted = await checkPin(pin);
  } catch {
    return fail("تعذر التحقق الأمني مؤقتاً", 503);
  }
  if (!pinAccepted) return fail("رمز المالك غير صحيح أو تم تجاوز عدد المحاولات المسموح بها", 401);

  const action = String(body.action ?? "");
  try {
    if (action === "list_schools") {
      const { data, error } = await admin.from("schools")
        .select("id,code,name,currency,licensed,active,trial_started_at,license_activated_at,created_at")
        .order("created_at", { ascending: false });
      if (error) return fail("تعذر تحميل المدارس", 500);
      return json({ ok: true, schools: data ?? [] });
    }

    if (action === "create_school") {
      const code = String(body.code ?? "").trim().toLowerCase();
      const name = String(body.name ?? "").trim();
      const currency = String(body.currency ?? "د.ل").trim();
      const username = String(body.admin_username ?? "").trim();
      const password = String(body.admin_password ?? "");
      if (!/^[a-z0-9]{3,20}$/.test(code)) return fail("رمز المدرسة: أحرف إنجليزية صغيرة وأرقام، من 3 إلى 20 خانة");
      if (name.length < 3 || name.length > 80) return fail("اسم المدرسة من 3 إلى 80 حرفاً");
      if (username.length < 2 || username.length > 40) return fail("اسم المدير من 2 إلى 40 حرفاً");
      if (password.length < 6 || password.length > 72 || /\s/.test(password)) return fail("كلمة المرور 6 خانات على الأقل وبدون مسافات");

      const licenseMode = String(body.license_mode ?? "trial");
      if (licenseMode !== "trial" && licenseMode !== "permanent") {
        return fail("نوع التفعيل غير صالح");
      }
      const permanent = licenseMode === "permanent";
      const now = new Date().toISOString();
      const { data: school, error: se } = await admin.from("schools")
        .insert({
          code,
          name,
          currency,
          licensed: permanent,
          trial_started_at: permanent ? null : now,
          license_activated_at: permanent ? now : null,
        })
        .select("id,code,name,currency,licensed,active,trial_started_at,license_activated_at,created_at")
        .single();
      if (se || !school) return fail(se?.code === "23505" ? "رمز المدرسة مستخدم مسبقاً" : "تعذر إنشاء المدرسة", 400);

      const email = crypto.randomUUID() + "@users.school-app.invalid";
      const { data: user, error: ue } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
      if (ue || !user?.user) {
        await admin.from("schools").delete().eq("id", school.id);
        return fail("تعذر إنشاء حساب مدير المدرسة", 500);
      }
      const { error: pe } = await admin.from("profiles").insert({
        user_id: user.user.id, school_id: school.id, username, role: "admin", active: true, must_change_password: true,
      });
      if (pe) {
        await admin.auth.admin.deleteUser(user.user.id);
        await admin.from("schools").delete().eq("id", school.id);
        return fail(pe.code === "23505" ? "اسم المستخدم موجود مسبقاً في هذه المدرسة" : "تعذر حفظ مدير المدرسة", 400);
      }
      await admin.from("subjects").insert([
        { school_id: school.id, name: "الرياضيات" },
        { school_id: school.id, name: "اللغة العربية" },
        { school_id: school.id, name: "اللغة الإنجليزية" },
        { school_id: school.id, name: "العلوم" },
      ]);
      return json({ ok: true, school });
    }

    if (action === "activate_school") {
      const schoolId = String(body.school_id ?? "").trim();
      if (!schoolId) return fail("المدرسة غير محددة");
      const { data: school } = await admin.from("schools")
        .select("id,code,name,licensed,active").eq("id", schoolId).maybeSingle();
      if (!school) return fail("المدرسة غير موجودة", 404);
      if (school.licensed) return json({ ok: true, already: true, school });
      const { data: updated, error } = await admin.from("schools")
        .update({ licensed: true, license_activated_at: new Date().toISOString() })
        .eq("id", schoolId)
        .select("id,code,name,currency,licensed,active,trial_started_at,license_activated_at,created_at")
        .single();
      if (error || !updated) return fail("تعذر تفعيل المدرسة", 500);
      return json({ ok: true, school: updated });
    }

    if (action === "set_school_active") {
      const schoolId = String(body.school_id ?? "").trim();
      const active = body.active === true;
      if (!schoolId) return fail("المدرسة غير محددة");
      const { data: school, error } = await admin.from("schools")
        .update({ active })
        .eq("id", schoolId)
        .select("id,code,name,licensed,active")
        .maybeSingle();
      if (error || !school) return fail("تعذر تغيير حالة المدرسة", 500);
      return json({ ok: true, school });
    }

    if (action === "generate_license") {
      return fail("تم إيقاف رموز التفعيل. استخدم إجراء تفعيل المدرسة من لوحة المالك.", 410);
    }

    if (action === "school_details") {
      const schoolId = String(body.school_id ?? "").trim();
      const { data: school } = await admin.from("schools")
        .select("id,code,name,currency,licensed,active,trial_started_at,license_activated_at,created_at").eq("id", schoolId).maybeSingle();
      if (!school) return fail("المدرسة غير موجودة", 404);
      const [students, teachers, profiles] = await Promise.all([
        admin.from("students").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
        admin.from("teachers").select("id", { count: "exact", head: true }).eq("school_id", schoolId),
        admin.from("profiles").select("user_id,username,role,active,created_at").eq("school_id", schoolId).order("created_at"),
      ]);
      return json({ ok: true, school, stats: { students: students.count ?? 0, teachers: teachers.count ?? 0 }, users: profiles.data ?? [] });
    }

    return fail("إجراء غير معروف");
  } catch (e) {
    console.error("owner-api error", e);
    return fail("حدث خطأ غير متوقع", 500);
  }
});
