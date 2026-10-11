import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'repository.dart';

class LaminPdfService {
  static Future<Map<String, dynamic>> _branding(SchoolRepository repo) async {
    final school = await repo.school() ?? <String, dynamic>{};
    final branding = await repo.schoolBranding() ?? <String, dynamic>{};
    final encoded = branding['logo_data']?.toString();
    return {
      'school_name': school['name']?.toString() ?? 'المدرسة',
      'logo': encoded == null || encoded.isEmpty ? null : base64Decode(encoded),
    };
  }

  static Future<void> printDailyReport({
    required SchoolRepository repo,
    required DateTime day,
    required Map<String, dynamic> data,
  }) async {
    final branding = await _branding(repo);
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final logoBytes = branding['logo'] as List<int>?;
    final logo = logoBytes == null ? null : pw.MemoryImage(Uint8List.fromList(logoBytes));
    final date = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final rows = <List<String>>[
      ['إجمالي الطلاب', '${data['students'] ?? 0}'],
      ['الحاضرون', '${data['present'] ?? 0}'],
      ['الغائبون', '${data['absent'] ?? 0}'],
      ['المتأخرون', '${data['late'] ?? 0}'],
      ['المدفوعات', '${_money(data['payments'])} د.ل'],
      ['المرتبات المصروفة', '${_money(data['payroll_salaries'])} د.ل'],
      ['السلف', '${_money(data['payroll_advances'])} د.ل'],
      ['إجمالي المصروفات', '${_money(data['expenses'])} د.ل'],
    ];
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(branding['school_name'] as String, logo, 'التقرير اليومي'),
              pw.SizedBox(height: 12),
              pw.Text('التاريخ: $date', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 18),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('البند', bold, header: true),
                      _cell('القيمة', bold, header: true),
                    ],
                  ),
                  ...rows.map((row) => pw.TableRow(children: [
                    _cell(row[0], font),
                    _cell(row[1], font),
                  ])),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Text('تم إنشاء التقرير بواسطة نظام لامين لإدارة وتنظيم المدارس', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    ));
    await Printing.layoutPdf(
      name: 'lamin-daily-report-$date.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  static Future<void> printPaymentReceipt({
    required SchoolRepository repo,
    required String studentName,
    required String className,
    required double amount,
    required String note,
  }) async {
    final branding = await _branding(repo);
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final logoBytes = branding['logo'] as List<int>?;
    final logo = logoBytes == null ? null : pw.MemoryImage(Uint8List.fromList(logoBytes));
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(30),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(branding['school_name'] as String, logo, 'إيصال استلام دفعة'),
              pw.SizedBox(height: 22),
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _detail('اسم الطالب', studentName, font, bold),
                    _detail('الصف', className.isEmpty ? '—' : className, font, bold),
                    _detail('المبلغ المستلم', '${amount.toStringAsFixed(2)} د.ل', font, bold),
                    _detail('تاريخ الإيصال', date, font, bold),
                    _detail('ملاحظة', note.trim().isEmpty ? '—' : note.trim(), font, bold),
                  ],
                ),
              ),
              pw.SizedBox(height: 22),
              pw.Text('تم استلام المبلغ الموضح أعلاه.', style: pw.TextStyle(font: bold, fontSize: 14), textAlign: pw.TextAlign.center),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المحاسب: ______________', style: pw.TextStyle(font: font, fontSize: 11)),
                  pw.Text('ختم المدرسة: ______________', style: pw.TextStyle(font: font, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text('لامين لإدارة وتنظيم المدارس', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    ));
    await Printing.layoutPdf(
      name: 'lamin-payment-receipt-${now.millisecondsSinceEpoch}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  static Future<void> printStudentStatement({
    required SchoolRepository repo,
    required String studentName,
    required String className,
    required String guardianPhone,
    required Map<String, dynamic> summary,
  }) async {
    final branding = await _branding(repo);
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoNaskhArabicRegular();
    final bold = await PdfGoogleFonts.notoNaskhArabicBold();
    final logoBytes = branding['logo'] as List<int>?;
    final logo = logoBytes == null ? null : pw.MemoryImage(Uint8List.fromList(logoBytes));
    final fees = (summary['assessments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final payments = (summary['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final year = summary['academic_year']?.toString() ?? 'غير محدد';
    final totalFees = _money(summary['fees']);
    final discount = _money(summary['discount']);
    final opening = _money(summary['opening_balance']);
    final paid = _money(summary['paid']);
    final remaining = _money(summary['remaining']);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(branding['school_name'] as String, logo, 'كشف حساب الطالب / ولي الأمر'),
              pw.SizedBox(height: 8),
              _detail('اسم الطالب', studentName, font, bold),
              _detail('الصف / الفصل', className.isEmpty ? '—' : className, font, bold),
              _detail('هاتف ولي الأمر', guardianPhone.isEmpty ? '—' : guardianPhone, font, bold),
              _detail('السنة الدراسية', year, font, bold),
              _detail('تاريخ الكشف', date, font, bold),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    _detail('إجمالي الرسوم', '$totalFees د.ل', font, bold),
                    _detail('الخصومات', '$discount د.ل', font, bold),
                    _detail('رصيد مرحّل', '$opening د.ل', font, bold),
                    _detail('إجمالي المدفوع', '$paid د.ل', font, bold),
                    _detail( double.tryParse(remaining.replaceAll(',', '')) != null &&
                            double.parse(remaining.replaceAll(',', '')) < 0
                        ? 'رصيد دائن للطالب' : 'المتبقي على ولي الأمر',
                      '${double.tryParse(remaining.replaceAll(',', '')) != null && double.parse(remaining.replaceAll(',', '')) < 0 ? (-double.parse(remaining)).toStringAsFixed(2) : remaining} د.ل',
                      font, bold),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text('الرسوم الدراسية حسب الفصل', style: pw.TextStyle(font: bold, fontSize: 14)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                    _cell('السنة', bold, header: true),
                    _cell('الفصل', bold, header: true),
                    _cell('الرسوم', bold, header: true),
                    _cell('الخصم', bold, header: true),
                    _cell('الصافي', bold, header: true),
                  ]),
                  ...fees.map((row) {
                    final fee = (row['total_fee'] as num?)?.toDouble() ?? 0;
                    final disc = (row['discount'] as num?)?.toDouble() ?? 0;
                    return pw.TableRow(children: [
                      _cell(row['academic_year_label']?.toString() ?? year, font),
                      _cell(row['term']?.toString() ?? '—', font),
                      _cell(fee.toStringAsFixed(2), font),
                      _cell(disc.toStringAsFixed(2), font),
                      _cell((fee - disc).toStringAsFixed(2), font),
                    ]);
                  }),
                  if (fees.isEmpty)
                    pw.TableRow(children: [
                      _cell('—', font), _cell('لا توجد رسوم مسجلة', font),
                      _cell('0.00', font), _cell('0.00', font), _cell('0.00', font),
                    ]),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Text('سجل الدفعات', style: pw.TextStyle(font: bold, fontSize: 14)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                    _cell('التاريخ', bold, header: true),
                    _cell('الفصل', bold, header: true),
                    _cell('المبلغ', bold, header: true),
                    _cell('ملاحظة', bold, header: true),
                  ]),
                  ...payments.map((row) => pw.TableRow(children: [
                    _cell(row['payment_date']?.toString() ?? row['created_at']?.toString().split('T').first ?? '—', font),
                    _cell(row['term']?.toString() ?? '—', font),
                    _cell('${_money(row['amount'])} د.ل', font),
                    _cell(row['note']?.toString().isNotEmpty == true ? row['note'].toString() : '—', font),
                  ])),
                  if (payments.isEmpty)
                    pw.TableRow(children: [
                      _cell('—', font), _cell('لا توجد دفعات', font),
                      _cell('0.00 د.ل', font), _cell('—', font),
                    ]),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text('هذا الكشف صادر من نظام لامين لإدارة وتنظيم المدارس.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ],
    ));
    await Printing.layoutPdf(
      name: 'lamin-student-statement-${DateTime.now().millisecondsSinceEpoch}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  static pw.Widget _header(String schoolName, pw.ImageProvider? logo, String title) {
    return pw.Column(
      children: [
        if (logo != null)
          pw.Container(height: 72, alignment: pw.Alignment.center, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.Text(schoolName, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.green800, thickness: 1.2),
      ],
    );
  }

  static pw.Widget _cell(String value, pw.Font font, {bool header = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
  );

  static pw.Widget _detail(String label, String value, pw.Font font, pw.Font bold) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 2, child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 12))),
        pw.Expanded(flex: 3, child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 12))),
      ],
    ),
  );

  static String _money(dynamic value) =>
      ((value as num?)?.toDouble() ?? 0).toStringAsFixed(2);
}
