import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Standalone interactive quiz builder. Data is stored locally on this device.
class TestBuilderView extends StatefulWidget {
  const TestBuilderView({super.key});
  @override
  State<TestBuilderView> createState() => _TestBuilderViewState();
}

class _TestBuilderViewState extends State<TestBuilderView> {
  static const _storageKey = 'lamin_test_builder_v1';
  final _title = TextEditingController();
  final _question = TextEditingController();
  final _options = List.generate(4, (_) => TextEditingController());
  final _points = TextEditingController(text: '1');
  final _answer = TextEditingController();
  final _student = TextEditingController();
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;
  String _kind = 'اختيار من متعدد';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _question.dispose();
    _points.dispose();
    _answer.dispose();
    _student.dispose();
    for (final c in _options) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _tests = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) { _tests = []; }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_tests));
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _addQuestion() {
    final q = _question.text.trim();
    final pts = double.tryParse(_points.text.replaceAll(',', '.'));
    if (q.isEmpty || pts == null || pts <= 0) {
      _message('أدخل نص السؤال ودرجة صحيحة أكبر من صفر.');
      return;
    }
    final item = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': q,
      'kind': _kind,
      'points': pts,
    };
    if (_kind == 'اختيار من متعدد') {
      final opts = _options.map((e) => e.text.trim()).toList();
      final answer = _answer.text.trim();
      if (opts.any((e) => e.isEmpty) || answer.isEmpty || !opts.contains(answer)) {
        _message('أكمل الخيارات الأربعة واكتب الإجابة الصحيحة مطابقة لأحد الخيارات.');
        return;
      }
      item['options'] = opts;
      item['answer'] = answer;
    } else if (_kind == 'صح أو خطأ') {
      if (!['صح', 'خطأ'].contains(_answer.text.trim())) {
        _message('اكتب الإجابة الصحيحة: صح أو خطأ.');
        return;
      }
      item['answer'] = _answer.text.trim();
      item['options'] = ['صح', 'خطأ'];
    } else {
      if (_answer.text.trim().isEmpty) {
        _message('اكتب الإجابة النموذجية للتصحيح التلقائي.');
        return;
      }
      item['answer'] = _answer.text.trim();
    }
    setState(() {
      _questions.add(item);
      _question.clear();
      for (final c in _options) { c.clear(); }
      _answer.clear();
      _points.text = '1';
    });
  }

  Future<void> _saveTest() async {
    if (_title.text.trim().isEmpty || _questions.isEmpty) {
      _message('أدخل عنوان الاختبار وأضف سؤالًا واحدًا على الأقل.');
      return;
    }
    final test = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': _title.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'questions': _questions.map((e) => Map<String, dynamic>.from(e)).toList(),
      'results': <Map<String, dynamic>>[],
    };
    setState(() { _tests.insert(0, test); _questions = []; _title.clear(); });
    await _persist();
    _message('تم حفظ الاختبار على هذا الجهاز.');
  }

  Future<void> _deleteTest(Map<String, dynamic> test) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف الاختبار؟'),
      content: Text('سيُحذف «${test['title']}» ونتائجه المحفوظة محليًا.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    setState(() => _tests.removeWhere((e) => e['id'] == test['id']));
    await _persist();
  }

  List<Map<String, dynamic>> _variant(Map<String, dynamic> test, int seed) {
    final random = Random(seed);
    return (test['questions'] as List).map((raw) {
      final q = Map<String, dynamic>.from(raw);
      if (q['kind'] == 'اختيار من متعدد') {
        final opts = List<String>.from(q['options'] as List)..shuffle(random);
        q['options'] = opts;
      }
      return q;
    }).toList()..shuffle(random);
  }

  Future<void> _makeVariants(Map<String, dynamic> test) async {
    final variants = <String>[];
    for (var i = 0; i < 3; i++) {
      final qs = _variant(test, DateTime.now().microsecondsSinceEpoch + i * 37);
      final lines = <String>['النموذج ${String.fromCharCode(65 + i)} — ${test['title']}', ''];
      for (var j = 0; j < qs.length; j++) {
        final q = qs[j];
        lines.add('${j + 1}. ${q['text']} (${q['points']} درجة)');
        if (q['kind'] == 'اختيار من متعدد') {
          final opts = List<String>.from(q['options'] as List);
          for (var k = 0; k < opts.length; k++) {
            lines.add('   ${String.fromCharCode(65 + k)}. ${opts[k]}');
          }
        } else if (q['kind'] == 'صح أو خطأ') {
          lines.add('   صح / خطأ');
        } else {
          lines.add('   الإجابة: __________________');
        }
        lines.add('');
      }
      variants.add(lines.join('\n'));
    }
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ثلاثة نماذج مختلفة'),
      content: SizedBox(width: 600, child: SingleChildScrollView(child: SelectableText(variants.join('\n\n────────────────\n\n')))),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: variants.join('\n\n────────────────\n\n')));
            if (ctx.mounted) Navigator.pop(ctx);
            _message('نُسخت النماذج الثلاثة إلى الحافظة.');
          },
          icon: const Icon(Icons.copy), label: const Text('نسخ النماذج'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
      ],
    ));
  }

  Future<void> _takeTest(Map<String, dynamic> test) async {
    final questions = (test['questions'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    final controllers = <String, TextEditingController>{};
    final choices = <String, String>{};
    for (final q in questions) { controllers[q['id'].toString()] = TextEditingController(); }
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final submitted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: Text('تطبيق الاختبار: ${test['title']}'),
      content: SizedBox(width: 650, child: Form(key: formKey, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الطالب')),
          const SizedBox(height: 12),
          for (var i = 0; i < questions.length; i++) ...[
            Text('${i + 1}. ${questions[i]['text']} (${questions[i]['points']} درجة)', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (questions[i]['kind'] == 'اختيار من متعدد')
              RadioGroup<String>(
                groupValue: choices[questions[i]['id'].toString()],
                onChanged: (v) => refresh(() { if (v != null) choices[questions[i]['id'].toString()] = v; }),
                child: Column(children: [
                  for (final option in List<String>.from(questions[i]['options'] as List))
                    RadioListTile<String>(dense: true, title: Text(option), value: option),
                ]),
              )
            else if (questions[i]['kind'] == 'صح أو خطأ')
              RadioGroup<String>(
                groupValue: choices[questions[i]['id'].toString()],
                onChanged: (v) => refresh(() { if (v != null) choices[questions[i]['id'].toString()] = v; }),
                child: const Column(children: [
                  RadioListTile<String>(dense: true, title: Text('صح'), value: 'صح'),
                  RadioListTile<String>(dense: true, title: Text('خطأ'), value: 'خطأ'),
                ]),
              )
            else
              TextField(controller: controllers[questions[i]['id'].toString()], decoration: const InputDecoration(labelText: 'الإجابة')),
            const Divider(),
          ],
        ],
      )))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () { if (name.text.trim().isEmpty) { _message('أدخل اسم الطالب.'); return; } Navigator.pop(ctx, true); }, child: const Text('تصحيح وحفظ')),
      ],
    )));
    if (submitted == true) {
      double score = 0, total = 0;
      final details = <Map<String, dynamic>>[];
      for (final q in questions) {
        final id = q['id'].toString();
        final answer = q['kind'] == 'إجابة قصيرة'
            ? controllers[id]!.text.trim().toLowerCase()
            : (choices[id] ?? '').trim().toLowerCase();
        final key = q['answer'].toString().trim().toLowerCase();
        final correct = answer == key;
        final points = (q['points'] as num).toDouble();
        total += points;
        if (correct) score += points;
        details.add({'question': q['text'], 'given': answer, 'correct': q['answer'], 'earned': correct ? points : 0, 'possible': points, 'correctAnswer': correct});
      }
      final result = <String, dynamic>{
        'student': name.text.trim(), 'date': DateTime.now().toIso8601String(),
        'score': score, 'total': total, 'details': details,
      };
      final live = _tests.firstWhere((e) => e['id'] == test['id']);
      setState(() => (live['results'] as List).insert(0, result));
      await _persist();
      if (mounted) await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('نتيجة الاختبار'),
        content: Text('${name.text.trim()}\nالدرجة: $score / $total\nالنسبة: ${total == 0 ? 0 : (score / total * 100).toStringAsFixed(1)}%'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))],
      ));
    }
    for (final c in controllers.values) { c.dispose(); }
    name.dispose();
  }

  Future<void> _exportResults(Map<String, dynamic> test) async {
    final results = List<Map<String, dynamic>>.from((test['results'] as List).map((e) => Map<String, dynamic>.from(e)));
    if (results.isEmpty) { _message('لا توجد نتائج لتصديرها.'); return; }
    final csv = StringBuffer('الطالب,الدرجة,الدرجة الكاملة,النسبة المئوية,التاريخ\n');
    for (final r in results) {
      final total = (r['total'] as num).toDouble();
      final score = (r['score'] as num).toDouble();
      String cell(dynamic v) => '"${v.toString().replaceAll('"', '""')}"';
      csv.writeln('${cell(r['student'])},${score.toStringAsFixed(2)},${total.toStringAsFixed(2)},${total == 0 ? 0 : (score / total * 100).toStringAsFixed(1)},${cell(r['date'])}');
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    _message('نُسخت النتائج بتنسيق CSV إلى الحافظة؛ الصقها في Excel.');
  }

  Future<void> _printTest(Map<String, dynamic> test) async {
    final doc = pw.Document();
    final qs = (test['questions'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(test['title'].toString(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 14),
        for (var i = 0; i < qs.length; i++) ...[
          pw.Text('${i + 1}. ${qs[i]['text']}  (${qs[i]['points']} درجة)'),
          if (qs[i]['kind'] == 'اختيار من متعدد')
            for (var j = 0; j < (qs[i]['options'] as List).length; j++)
              pw.Text('   ${String.fromCharCode(65 + j)}. ${qs[i]['options'][j]}'),
          if (qs[i]['kind'] != 'اختيار من متعدد') pw.Text('   الإجابة: __________________________'),
          pw.SizedBox(height: 10),
        ],
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('منشئ الاختبارات والتدريبات')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('إنشاء اختبار', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان الاختبار')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'نوع السؤال'),
            items: const [
              DropdownMenuItem(value: 'اختيار من متعدد', child: Text('اختيار من متعدد')),
              DropdownMenuItem(value: 'صح أو خطأ', child: Text('صح أو خطأ')),
              DropdownMenuItem(value: 'إجابة قصيرة', child: Text('إجابة قصيرة — تطابق حرفي بعد توحيد حالة الأحرف')),
            ],
            onChanged: (v) => setState(() => _kind = v ?? 'اختيار من متعدد'),
          ),
          TextField(controller: _question, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'نص السؤال')),
          if (_kind == 'اختيار من متعدد')
            for (var i = 0; i < _options.length; i++)
              TextField(controller: _options[i], decoration: InputDecoration(labelText: 'الخيار ${String.fromCharCode(65 + i)}')),
          TextField(controller: _answer, decoration: InputDecoration(labelText: _kind == 'اختيار من متعدد' ? 'الإجابة الصحيحة (اكتب نص الخيار نفسه)' : _kind == 'صح أو خطأ' ? 'الإجابة الصحيحة: صح أو خطأ' : 'الإجابة النموذجية')),
          TextField(controller: _points, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'درجة السؤال')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: Text('إضافة السؤال (${_questions.length})')),
          if (_questions.isNotEmpty)
            Card(child: Column(children: [
              for (var i = 0; i < _questions.length; i++)
                ListTile(
                  title: Text('${i + 1}. ${_questions[i]['text']}'),
                  subtitle: Text('${_questions[i]['kind']} • ${_questions[i]['points']} درجة'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _questions.removeAt(i))),
                ),
            ])),
          FilledButton.tonalIcon(onPressed: _saveTest, icon: const Icon(Icons.save_outlined), label: const Text('حفظ الاختبار')),
          const Divider(height: 32),
          const Text('الاختبارات المحفوظة على هذا الجهاز', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (_tests.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لم تُنشأ اختبارات بعد.')),
          for (final test in _tests)
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(test['title'].toString()),
                subtitle: Text('${(test['questions'] as List).length} سؤال • ${(test['results'] as List).length} نتيجة'),
                children: [
                  Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
                    TextButton.icon(onPressed: () => _takeTest(test), icon: const Icon(Icons.play_arrow), label: const Text('تطبيق وتصحيح')),
                    TextButton.icon(onPressed: () => _makeVariants(test), icon: const Icon(Icons.copy_all), label: const Text('3 نماذج')),
                    TextButton.icon(onPressed: () => _printTest(test), icon: const Icon(Icons.print), label: const Text('طباعة PDF')),
                    TextButton.icon(onPressed: () => _exportResults(test), icon: const Icon(Icons.table_view), label: const Text('تصدير النتائج CSV')),
                    TextButton.icon(onPressed: () => _deleteTest(test), icon: const Icon(Icons.delete_outline), label: const Text('حذف')),
                  ]),
                  if ((test['results'] as List).isNotEmpty)
                    for (final r in List<Map<String, dynamic>>.from((test['results'] as List).map((e) => Map<String, dynamic>.from(e))))
                      ListTile(
                        leading: const Icon(Icons.assessment_outlined),
                        title: Text(r['student'].toString()),
                        subtitle: Text('الدرجة ${r['score']} / ${r['total']} • ${((r['score'] as num) / ((r['total'] as num) == 0 ? 1 : (r['total'] as num)) * 100).toStringAsFixed(1)}%'),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
