import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'repository.dart';

class SchoolBrandingView extends StatefulWidget {
  final SchoolRepository repo;
  const SchoolBrandingView({super.key, required this.repo});

  @override
  State<SchoolBrandingView> createState() => _SchoolBrandingViewState();
}

class _SchoolBrandingViewState extends State<SchoolBrandingView> {
  bool loading = true;
  bool saving = false;
  String? logoData;
  String? mimeType;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final branding = await widget.repo.schoolBranding();
      logoData = branding?['logo_data']?.toString();
      mimeType = branding?['logo_mime_type']?.toString();
    } catch (_) {
      error = 'تعذر تحميل شعار المدرسة.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pickLogo() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('تعذر قراءة الصورة. حاول اختيارها مرة أخرى.');
      }
      if (bytes.length > 950 * 1024) {
        throw Exception(
          'حجم الشعار يجب ألا يتجاوز 950 كيلوبايت. صغّر الصورة ثم أعد المحاولة.',
        );
      }
      final ext = (file.extension ?? '').toLowerCase();
      final type = ext == 'png' ? 'image/png' : 'image/jpeg';
      final encoded = base64Encode(bytes);
      setState(() {
        saving = true;
        error = null;
      });
      await widget.repo.saveSchoolLogo(logoBase64: encoded, mimeType: type);
      if (!mounted) return;
      setState(() {
        logoData = encoded;
        mimeType = type;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ شعار المدرسة. سيظهر في تقارير PDF وإيصالات الدفع الجديدة.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeLogo() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف شعار المدرسة'),
            content: const Text(
              'سيُحذف الشعار المحفوظ لهذه المدرسة، ولن يظهر في المستندات الجديدة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف الشعار'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repo.removeSchoolLogo();
      if (mounted)
        setState(() {
          logoData = null;
          mimeType = null;
        });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الشعار.')));
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = logoData == null ? null : base64Decode(logoData!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('شعار المدرسة للطباعة'),
        actions: [
          IconButton(
            onPressed: loading || saving ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.branding_watermark_outlined, size: 42),
                        const SizedBox(height: 10),
                        const Text(
                          'شعار المدرسة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ارفع شعارًا بصيغة PNG أو JPG ليظهر أعلى التقارير اليومية وإيصالات الدفع عند الطباعة أو حفظها PDF. يُحفظ الشعار مع المدرسة ويظهر على الأجهزة التي تستخدم حسابها.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 220,
                          height: 160,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD7E1DA)),
                          ),
                          child: bytes == null
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      size: 44,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text('لا يوجد شعار محفوظ'),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                    width: 200,
                                    height: 140,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : pickLogo,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(
                              saving
                                  ? 'جارِ الحفظ...'
                                  : bytes == null
                                  ? 'اختيار شعار من الجهاز'
                                  : 'تغيير الشعار',
                            ),
                          ),
                        ),
                        if (bytes != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: saving ? null : removeLogo,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('حذف الشعار'),
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('ملاحظات'),
                    subtitle: Text(
                      'الصيغ المدعومة PNG وJPG، والحد الأقصى 950 كيلوبايت. لا يؤثر تغيير الشعار في المستندات التي سبق حفظها.',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
