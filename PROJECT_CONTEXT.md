# Lamīn School — Canonical Project Context

## Project identity
- This repository is **Lamīn School**: `laminahmed12/school-mobile-app`.
- Backend: **Supabase**.
- This is NOT Lamīn Management, which is a separate Firebase project. Never mix their code, credentials, deployments, or requirements.

## Working boundaries
- Work only in the active task branch; do not modify `main` or production unless the user explicitly requests it.
- Never expose, request, or change production secrets/keys. Do not run destructive database actions or migrations against production.
- Before every task: read this file, verify repository/branch/PR and inspect current code/state. Do not rely on remembered branch names or assume prior work is still current.
- Preserve completed work. Do not repeat successful steps or ask the user to restate facts already present in this repository or conversation.
- Make the smallest safe change, run relevant checks, and report only verified results. Distinguish code/CI checks from real-device validation.
- If repository tools are available, use them directly. Never claim access is missing without checking tool availability and repository connection.

## Current issue reported (2026-11-01)
- Offline login fails, even with “Remember me” enabled.
- If a session starts online and connectivity drops, actions can leave the screen loading for about 35 seconds.
- Student rollover worked after connectivity returned.
- Treat offline authentication, offline mutation queue/reconciliation, and network timeout behavior as separate areas to inspect. Do not claim fixed until code checks and an actual offline device test confirm it.

## User communication
- نفّذ مباشرة، ولا تكتب مقدمات ولا شرحًا لما ستفعله.
- ممنوع تكرار ما قلته سابقًا أو تلخيص ما فعلناه، ولا تعد شرح ما أعرفه.
- لا تعرض خيارات متعددة ولا قوائم طويلة. اختر الحل الأنسب ونفّذه.
- لا تسأل إلا إذا كان هناك عائق حقيقي لا يمكن تجاوزه، واذكر العائق في سطر واحد.
- التقرير النهائي لا يتجاوز 5 أسطر: ماذا عدّلت، وما الفحوصات التي شغّلتها فعلًا، وما الذي أحتاج أن أجربه أنا على الهاتف.
- لا تقل «تم الإصلاح» إلا بعد التحقق الفعلي، وإن لم تتحقق قل ذلك بصراحة.