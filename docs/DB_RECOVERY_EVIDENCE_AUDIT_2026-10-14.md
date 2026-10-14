# Lamīn — سجل أدلة الاستعادة وتصنيف المطابقة
**التاريخ:** 2026-10-14  
**المستودع:** `laminahmed12/school-mobile-app`  
**الفرع:** `fix/lamin-db-recovery-root-cause-20261014`  
**الغرض:** إضافة نتائج تحقق جديدة دون استبدال تقرير الجذر السابق أو اختلاق المصدر التاريخي.

## 1. النتيجة التنفيذية لهذه الجولة
- تم جلب ملف المطابقة الحالي من الفرع نفسه وقراءة **93 صفًا** بعد رأس CSV.
- كل الحالات الـ93 لا تزال `unresolved` في الملف الأصلي؛ لم أغيّر أي حالة في الخريطة.
- التصنيف المبني على الأدلة الحالية: **68** سجل إنتاج لا يقابله مسار ملف مصدر في الخريطة؛ **6** أسماء متشابهة بإصدارات مختلفة؛ **19** ملف ترحيل في المستودع لا يملك مطابقة إنتاج مثبتة.
- **التطابقات المثبتة: 0.** **اختلافات محتوى مثبتة: 0**؛ ليس لأن الملفات متكافئة، بل لأن المصدر التاريخي المرجعي غير متاح للمقارنة. لا يصح تصنيف اختلاف محتوى دون طرفين موثوقين.
- بحث GitHub النصي في المستودع عن `20260924214051_001_core_tables.sql`, `001_core_tables`, و`supabase_test_bootstrap.sql` لم يُرجع نتائج. بحث الملفات في موصل GitHub يغطي الفرع الافتراضي؛ لذلك هذه النتيجة ليست برهانًا على غياب كائن Git غير مشار إليه أو نسخة محلية خارجية.
- تحقق وجود فرع العمل `fix/lamin-db-recovery-root-cause-20261014`. لم أغيّر `main`، ولم أنفذ أي كتابة في قاعدة الإنتاج أو تشغيل ترحيلات.

## 2. تصنيف الحالات الـ93 — حالة بحالة
التصنيف أدناه يعبّر عن الأدلة المتاحة، لا عن افتراض تكافؤ. «ملف تاريخي غير موجود» يعني غير موجود في المراجع المفحوصة/الخريطة، ولا يعني إثبات محوه من كل نسخة Git أو جهاز.

| # | إصدار الإنتاج | اسم الإنتاج | إصدار المرشح | ملف المرشح | التصنيف |
|---:|---|---|---|---|---|
| 1 | 20260924214051 | 001_core_tables | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 2 | 20260924214123 | 002_rls_policies_rpcs | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 3 | 20260927042618 | 003_school_operations | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 4 | 20260927043018 | 004_academic_results | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 5 | 20260927044205 | 005_staff_and_class_subjects | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 6 | 20260928070724 | bootstrap_owner_school | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 7 | 20261002023925 | 003_attendance_rpc | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 8 | 20261003150831 | 004_audit_skip_deleted_school | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 9 | 20261006010111 | 005_expenses_controls | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 10 | 20261006100649 | 006_backup_export_restore | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 11 | 20261008002800 | 20261008_security_performance_hardening | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 12 | 20261008002821 | 20261008_rls_policy_performance_cleanup | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 13 | 20261008012010 | 20261008_trial_and_one_time_license | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 14 | 20261008015725 | 20261008_lamin_annual_data_backup_and_school_code | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 15 | 20261008015732 | 20261008_lamin_school_code_normalization | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 16 | 20261008020046 | 20261008_lamin_fix_owner_bootstrap_school_binding | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 17 | 20261008020108 | 20261008_lamin_privileged_rpc_hardening | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 18 | 20261008020118 | 20261008_lamin_annual_data_fk_indexes | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 19 | 20261008020133 | 20261008_lamin_promotion_and_financial_carryover | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 20 | 20261008020139 | 20261008_lamin_backup_completeness | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 21 | 20261008022735 | 20261008_lamin_manager_controlled_onedrive_access | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 22 | 20261008022751 | 20261008_lamin_onedrive_role_guard | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 23 | 20261008054322 | 20261008_lamin_owner_gate_rate_limit | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 24 | 20261008054329 | 20261008_lamin_license_school_binding | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 25 | 20261008064039 | 20261008_lamin_license_atomic_redemption | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 26 | 20261011003123 | allow_payments_without_preconfigured_student_fee | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 27 | 20261011003147 | allow_supervisors_to_add_students | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 28 | 20261011030248 | school_activation_state_and_payroll | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 29 | 20261011030317 | enforce_school_suspension_and_payroll_read_access | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 30 | 20261011030455 | preserve_active_trial_access_when_school_is_enabled | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 31 | 20261011030720 | include_payroll_records_in_school_backups | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 32 | 20261011030753 | validate_payroll_recipient_school | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 33 | 20261011054843 | allow_supervisors_to_read_teachers | 20261011040000 | supabase/migrations/20261011040000_allow_supervisors_to_read_teachers.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 34 | 20261011055003 | complete_school_backup_and_safe_restore | 20261011040001 | supabase/migrations/20261011040001_complete_school_backup_and_safe_restore.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 35 | 20261011082055 | school_branding_logo_for_printouts | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 36 | 20261011185512 | fix_trial_school_backup_permissions | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 37 | 20261011195220 | student_finance_ledger_and_fee_assessments | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 38 | 20261011195704 | include_term_finance_and_branding_in_backups | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 39 | 20261011195728 | enforce_school_scope_for_fee_years | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 40 | 20261012025856 | lamin_finance_foundation_audit_and_fee_rules | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 41 | 20261012025918 | lamin_backup_support_finance_foundation | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 42 | 20261012030006 | lamin_audit_trigger_align_existing_schema | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 43 | 20261012030028 | lamin_finance_audit_timestamps_and_restore_order | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 44 | 20261012030109 | lamin_finance_rls_and_fk_index_cleanup | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 45 | 20261012030321 | lamin_auto_fee_schedule_at_enrollment | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 46 | 20261012030408 | lamin_payment_allocations_and_amount_guard | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 47 | 20261012030421 | lamin_backup_include_payment_allocations | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 48 | 20261012030454 | lamin_rollover_adjustments_and_payroll_periods | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 49 | 20261012030515 | lamin_backup_include_adjustments_rollover_payroll_periods | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 50 | 20261012030603 | lamin_backup_rpc_execute_restrictions | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 51 | 20261012030615 | lamin_backup_audit_history_and_rpc_acl | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 52 | 20261012030742 | lamin_finance_foreign_key_index_coverage | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 53 | 20261012030944 | lamin_atomic_payment_recording_and_allocation | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 54 | 20261012031043 | lamin_discount_approval_and_assessment_sync | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 55 | 20261012031054 | lamin_fix_discount_sync_trigger_record_return | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 56 | 20261012031158 | lamin_preserve_manual_discount_baseline | 20261012062100 | supabase/migrations/20261012062100_lamin_preserve_manual_discount_baseline.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 57 | 20261012031250 | lamin_academic_rollover_preview_and_execute | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 58 | 20261012031306 | lamin_rollover_preserve_all_student_debts | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 59 | 20261012031327 | lamin_rollover_review_each_student | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 60 | 20261012031455 | lamin_enforce_single_active_year_and_rollover | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 61 | 20261012031554 | lamin_link_opening_balances_to_rollover_batch | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 62 | 20261012031650 | lamin_backup_exclude_restored_audit_copies | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 63 | 20261012031751 | lamin_disable_unsafe_legacy_rollover_bypasses | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 64 | 20261012031804 | lamin_disable_legacy_student_promotion_rpc | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 65 | 20261012031908 | lamin_rls_performance_cleanup | 20261012064100 | supabase/migrations/20261012064100_lamin_rls_performance_cleanup.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 66 | 20261012031957 | lamin_require_approval_for_manual_discount_changes | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 67 | 20261012032029 | lamin_restore_rollover_dependency_order | 20261012064200 | supabase/migrations/20261012064200_lamin_restore_rollover_dependency_order.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 68 | 20261012032223 | lamin_rollover_validate_year_states | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 69 | 20261012032249 | lamin_guard_rollover_year_state | 20261012063200 | supabase/migrations/20261012063200_lamin_guard_rollover_year_state.sql | دليل إضافي مطلوب: اختلاف إصدار |
| 70 | 20261012042741 | lamin_tenant_scope_academic_year_finance_links | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 71 | 20261012042902 | lamin_scope_opening_balance_provenance | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 72 | 20261012064423 | lamin_covering_indexes_for_finance_fk_20261012 | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 73 | 20261012080946 | lamin_harden_owner_bootstrap_null_role_guard | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 74 | 20261012191847 | allow_optional_teacher_phone | — | — | ملف تاريخي غير موجود ضمن المراجع المفحوصة |
| 75 | — | — | 20261012045500 | supabase/migrations/20261012045500_lamin_finance_foundation.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 76 | — | — | 20261012050000 | supabase/migrations/20261012050000_lamin_audit_compatibility_and_policy_cleanup.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 77 | — | — | 20261012050500 | supabase/migrations/20261012050500_lamin_enrollment_fee_and_backup_support.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 78 | — | — | 20261012052000 | supabase/migrations/20261012052000_lamin_payment_allocations.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 79 | — | — | 20261012054000 | supabase/migrations/20261012054000_lamin_rollover_adjustments_payroll.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 80 | — | — | 20261012055000 | supabase/migrations/20261012055000_lamin_backup_acl_and_audit_history.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 81 | — | — | 20261012060000 | supabase/migrations/20261012060000_lamin_finance_fk_indexes.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 82 | — | — | 20261012061000 | supabase/migrations/20261012061000_lamin_atomic_payment_recording.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 83 | — | — | 20261012062000 | supabase/migrations/20261012062000_lamin_discount_approval.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 84 | — | — | 20261012062200 | supabase/migrations/20261012062200_lamin_manager_approval_for_manual_discounts.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 85 | — | — | 20261012063000 | supabase/migrations/20261012063000_lamin_academic_rollover_rpc.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 86 | — | — | 20261012063100 | supabase/migrations/20261012063100_lamin_rollover_provenance_and_single_active_year.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 87 | — | — | 20261012064000 | supabase/migrations/20261012064000_lamin_disable_legacy_rollover_bypasses.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 88 | — | — | 20261013041800 | supabase/migrations/20261013041800_lamin_prioritize_selected_fee_payment.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 89 | — | — | 20261013190000 | supabase/migrations/20261013190000_lamin_rollover_balance_from_allocations.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 90 | — | — | 20261014030000 | supabase/migrations/20261014030000_allow_owner_teacher_management.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 91 | — | — | 20261014050000 | supabase/migrations/20261014050000_fix_academic_rollover_year_closing.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 92 | — | — | 20261014070000 | supabase/migrations/20261014070000_include_fee_assessments_in_backup.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |
| 93 | — | — | 20261014080000 | supabase/migrations/20261014080000_complete_financial_backup_restore.sql | دليل إضافي مطلوب: مرشح مستودع غير مربوط |

## 3. المصدران المطلوب استعادتهما
1. `supabase/migrations/20260924214051_001_core_tables.sql`: لم يُستعد محتواه الأصلي من المصادر التي فُحصت. سجل Supabase يثبت وجود إصدار `20260924214051` بالاسم `001_core_tables`، لكنه لا يثبت محتوى ملف SQL التاريخي.
2. `test/sql/supabase_test_bootstrap.sql`: لم يُعثر على مصدره الأصلي. لا يجوز إعادة تسميته أو توليد بديل ثم الادعاء أنه bootstrap التاريخي.

### الأدلة المطلوبة للحسم
- نسخة checkout أصلية أو Git bundle أو clone محفوظة من بيئة التطوير، مع `.git` وrefs/reflogs، أو أرشيف CI موثوق يحوي المصدر.
- أو نسخة SQL أصلية محفوظة من نسخة احتياطية/نظام إدارة أسرار/مخزن ملفات مع تاريخ وSHA ومصدر واضح.
- لمطابقة كل ترحيل: ملف المصدر التاريخي الفعلي، سجل الإصدار من قاعدة الإنتاج، ومقارنة بنيوية/سلوكية قابلة لإعادة الإنتاج. أسماء متشابهة أو schema حالي وحده لا تكفي.

## 4. مخطط Supabase الحي — قراءة metadata فقط
تم الاستعلام من مشروع `School-Management` ذي المرجع `stbrhcgzfxvpayfnnqfl` عبر استعلامات catalog/metadata فقط:
- PostgreSQL 17.6.1.166.
- سجل الترحيلات: 74 إصدارًا، ويتضمن `20260924214051 / 001_core_tables`.
- الجرد السابق للمخطط: 40 جدولًا أساسيًا عامًا، 3 views عامة، 99 سياسة RLS، و39 دالة في `public` و7 في `private`.
- قائمة الجداول/الأعمدة والمفاتيح الأجنبية التي رجعها فحص الجداول هي لقطة metadata للمخطط الحالي، وليست dump تاريخيًا كاملًا ولا دليلًا على ترتيب الترحيلات. لم تُقرأ صفوف الطلاب أو أولياء الأمور أو الدفعات.
- لم تُنفذ `pg_dump` كاملة من اتصال عميل في هذه الجولة؛ أدوات Supabase المتاحة هنا قدّمت catalog queries. لذلك لا أصف الناتج بأنه تصدير schema كامل أو قابل لإعادة إنشاء المشروع.

## 5. مراجعة أولية لتعريفات SECURITY DEFINER
تمت قراءة تعريفات الدوال من `pg_get_functiondef` واستعلام ACLs من الكتالوج، دون تعديل الصلاحيات. الجرد: 34 دالة SECURITY DEFINER ضمن `public/private`; جميعها لديها إعداد صريح لـ`search_path`. هذا شرط دفاعي مفيد، لكنه لا يكفي وحده لإثبات سلامة التفويض.

ملاحظات تحتاج متابعة على بيئة معزولة:
- `private.validate_payroll_transaction()`: دالة trigger؛ لديها ACL EXECUTE ظاهر لـ`anon` و`authenticated`، لكن دور `anon` لا يملك USAGE على مخطط `private`، كما أن الدالة تُستخدم كـtrigger. لا يثبت ذلك استدعاءً مباشرًا ناجحًا، لكنه يستحق ضبط ACL على مبدأ أقل صلاحية بعد اختبار المستدعين.
- `private.restore_school_data(jsonb)`: لا يوجد فحص تفويض داخل جسمها، لكن ACL لا يمنح EXECUTE لـ`anon` أو `authenticated`، والمخطط خاص. لم يثبت مسار استدعاء غير موثوق لها. لا تُمنح صلاحيات ولا تُعدّل الدالة قبل حصر جميع المستدعين.
- `public.export_backup` يمرّر التنفيذ إلى `export_backup_core_v4` ثم `export_backup_core_v2`؛ فحص التفويض الفعلي موجود في v2 (owner/admin مع تقييد المدرسة). لا يكفي غياب فحص محلي في wrapper وحده لاعتباره ثغرة.
- `public.restore_backup` يتحقق من دور admin ومن تطابق `school_filter` مع المدرسة الحالية قبل استدعاء دوال الاستعادة الأساسية.
- `public.record_student_payment` يتحقق من هوية المستخدم والمدرسة والدور، ويتحقق من ملكية الطالب وبند الرسوم.
- هذه مراجعة تعريفات/ACL أولية، لا اختبارات استغلال، ولا شهادة أمنية نهائية. ما زال مطلوبًا اختبار RLS عبر أدوار فعلية، وحدود المستأجر، وملكية الدوال، وامتيازات التنفيذ على قاعدة معزولة.

## 6. قرار الاختبار
- لا يمكن تنفيذ سلسلة الترحيلات الكاملة على قاعدة فارغة بصدق قبل استعادة المصدر الفعلي وحسم الاعتماديات.
- لم يُنشأ bootstrap بديل، ولم يُنشأ ترحيل تأسيسي بديل.
- لا يمكن تصنيف الـ19 ملفًا المرشّح على أنها مطابقة لمجرد وجودها؛ تحتاج مقارنة مع المصدر/السجل الموثوق.
- لم يتم تعديل `main`، أو إجراء DDL/DML على الإنتاج، أو حذف سجل ترحيلات، أو إصدار APK.

## 7. حدود الفحص المتبقي
واجهات GitHub المتاحة لا تمنح دليلًا على فحص كل كائنات Git غير المشار إليها، وكل reflog محلي، وكل جهاز مطور أو cache خارجي. لا توجد في السياق الحالي نسخة Git bundle أو checkout أصلي يمكن فحصه. يلزم توفير أحد الأدلة في القسم 3 لإزالة هذا الحاجز؛ تكرار البحث في الواجهة نفسها دون مصدر جديد لن يحسمه.
