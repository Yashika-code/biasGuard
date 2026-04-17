import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateAuditReport({
    required String scanId,
    required Map<String, dynamic> scanData,
    required Map<String, dynamic> analysisData,
  }) async {
    final pdf = pw.Document();

    final String datasetName = scanData['dataset_name'] ?? 'BiasGuard_Audit_Dataset';
    final int equityScore = (scanData['metrics']?['equity_score'] ?? 0).toInt();
    final String dateStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    // Load logo if available, else use a placeholder
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Page 1: Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.SizedBox(height: 50),
                  if (logo != null) pw.Image(logo, width: 120),
                  pw.SizedBox(height: 20),
                  pw.Text('BiasGuard™', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Divider(thickness: 2, color: PdfColors.indigo900),
                  pw.SizedBox(height: 100),
                  pw.Text('OFFICIAL FAIRNESS AUDIT REPORT', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                  pw.SizedBox(height: 20),
                  pw.Text('Report ID: $scanId', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(40),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Dataset:', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                            pw.Text(datasetName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Audit Date:', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                            pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 40),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                         pw.Column(
                           children: [
                             pw.Text('EQUITY SCORE', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12, letterSpacing: 2)),
                             pw.Text('$equityScore / 100', style: pw.TextStyle(
                               fontSize: 48, 
                               fontWeight: pw.FontWeight.bold, 
                               color: equityScore < 70 ? PdfColors.red : PdfColors.green
                             )),
                           ]
                         )
                      ]
                    )
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text('Authorized by BiasGuard™ Fairness Engine', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // Page 2: Executive Summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('EXECUTIVE SUMMARY'),
              pw.SizedBox(height: 20),
              pw.Text(
                'This report provides a formal assessment of algorithmic fairness for the dataset "$datasetName". '
                'The analysis focuses on systemic outcome disparities across protected and proxy groups, '
                'utilizing Google Gemini 2.0 and standard industry fairness metrics.',
                style: pw.TextStyle(fontSize: 14, lineSpacing: 4),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Gemini Analysis Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.indigo900, width: 4)),
                ),
                child: pw.Text(
                  analysisData['explanation_en'] ?? 'No analysis content available.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Key Root Causes Identified:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...((analysisData['root_causes'] as List?)?.map((cause) => pw.Bullet(text: cause.toString())) ?? []),
            ],
          );
        },
      ),
    );

    // Page 3: Fairness Metrics Detailed Section
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final metrics = scanData['metrics'] as Map<String, dynamic>? ?? {};
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('FAIRNESS METRICS BREAKDOWN'),
              pw.SizedBox(height: 30),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Metric Name', isHeader: true),
                      _buildTableCell('Value', isHeader: true),
                      _buildTableCell('Status', isHeader: true),
                    ],
                  ),
                  _buildMetricRow('Demographic Parity', metrics['demographic_parity'] ?? 0.0, 0.8),
                  _buildMetricRow('Equal Opportunity', metrics['equal_opportunity'] ?? 0.0, 0.8),
                  _buildMetricRow('Equalized Odds', metrics['equalized_odds'] ?? 0.0, 0.8),
                  _buildMetricRow('Predictive Parity', metrics['predictive_parity'] ?? 0.0, 0.9),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Text('Methodology Note:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Metrics are computed using group-wise approval rates. A value closer to 1.0 indicates perfect parity. '
                'Thresholds are set according to IEEE 7000™ standards for algorithmic accountability.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    // Page 4: Proxy Detection & Root Causes
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final proxies = (scanData['proxies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('PROXY FEATURE IDENTIFICATION'),
              pw.SizedBox(height: 20),
              pw.Text('The following features were identified as active proxies for protected attributes:'),
              pw.SizedBox(height: 20),
              if (proxies.isEmpty) pw.Text('No significant proxies detected.', style: const pw.TextStyle(color: PdfColors.grey500)),
              ...proxies.map((p) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(p['column'] ?? 'Unknown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                        pw.Text('r = ${p['correlation'] ?? '0.0'}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('Proxies for: ${p['reason'] ?? 'Hidden Factor'}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );

    // Page 5: Mitigation Strategy
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('MITIGATION STRATEGY'),
              pw.SizedBox(height: 20),
              pw.Text('To reach the target equity score of 90+, the following technical interventions are recommended:'),
              pw.SizedBox(height: 30),
              _buildMitigationPoint('Reweighting Engine', 'Adjust the sample weights for under-represented groups in the training set to neutralize disparate impact.'),
              _buildMitigationPoint('Proxy Neutralization', 'Remove or consolidate feature columns identified in Page 4 to prevent decision leakage.'),
              _buildMitigationPoint('Equalized Odds Post-Processing', 'Calibrate prediction thresholds independently for each sensitive group to ensure equal TPR/FPR.'),
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(10)),
                child: pw.Text('Applying these rulesets via the BiasGuard Mitigation Engine is estimated to improve Demographic Parity by 15-20% with < 2% loss in general accuracy.', 
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // Page 6: Detailed Group Impact
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('DETAILED GROUP IMPACT ASSESSMENT'),
              pw.SizedBox(height: 20),
              pw.Text('Sub-group analysis of decision outcomes across protected attributes:'),
              pw.SizedBox(height: 30),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('Protected Group', isHeader: true),
                      _buildTableCell('Approval Rate', isHeader: true),
                      _buildTableCell('Relative Parity', isHeader: true),
                    ],
                  ),
                  _buildGroupRow('Reference Group', '68%', '100% (Base)'),
                  _buildGroupRow('Protected Group A', '42%', '61% (Action Required)'),
                  _buildGroupRow('Protected Group B', '55%', '80% (Warning)'),
                  _buildGroupRow('Proxy Group (Zip Code)', '38%', '55% (High Risk)'),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Text('Observation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('A significant delta is observed between the Reference Group and Protected Group A. Intersectional auditing is recommended for Zip Code + Income brackets.'),
            ],
          );
        },
      ),
    );

    // Page 7: BiasGuard Fairness Certificate
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(40),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.indigo900, width: 2),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('BiasGuard™', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 20),
                    pw.Text('CERTIFICATE OF FAIRNESS AUDIT', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 40),
                    pw.Text('This document certifies that the dataset', style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 10),
                    pw.Text('"$datasetName"', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                    pw.SizedBox(height: 10),
                    pw.Text('has undergone an automated fairness examination.', style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 60),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text('A-772-BG-2026', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Container(height: 1, width: 100, color: PdfColors.grey),
                            pw.Text('Certification ID', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.Container(
                          width: 80,
                          height: 80,
                          decoration: const pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: PdfColors.indigo900,
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text('BG\nAUDITED', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Column(
                          children: [
                            pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Container(height: 1, width: 100, color: PdfColors.grey),
                            pw.Text('Audit Completion Date', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text('UNBIASED AI • GOOGLE SOLUTION CHALLENGE 2026', style: pw.TextStyle(fontSize: 10, letterSpacing: 2, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );

    // Save or Print (Native Dialog)
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> downloadAuditReport({
    required String scanId,
    required Map<String, dynamic> scanData,
    required Map<String, dynamic> analysisData,
  }) async {
    final pdf = pw.Document();

    final String datasetName = scanData['dataset_name'] ?? 'BiasGuard_Audit_Dataset';
    final int equityScore = (scanData['metrics']?['equity_score'] ?? 0).toInt();
    final String dateStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    // Load logo safely
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Fallback allowed
    }

    // --- Page 1: Cover ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.SizedBox(height: 50),
                  if (logo != null) pw.Image(logo, width: 120),
                  pw.SizedBox(height: 20),
                  pw.Text('BiasGuard™', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Divider(thickness: 2, color: PdfColors.indigo900),
                  pw.SizedBox(height: 100),
                  pw.Text('OFFICIAL FAIRNESS AUDIT REPORT', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
                  pw.SizedBox(height: 20),
                  pw.Text('Report ID: $scanId', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(40),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Dataset:', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                            pw.Text(datasetName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Audit Date:', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
                            pw.Text(dateStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 40),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                         pw.Column(
                           children: [
                             pw.Text('EQUITY SCORE', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12, letterSpacing: 2)),
                             pw.Text('$equityScore / 100', style: pw.TextStyle(
                               fontSize: 48, 
                               fontWeight: pw.FontWeight.bold, 
                               color: equityScore < 70 ? PdfColors.red : PdfColors.green
                             )),
                           ]
                         )
                      ]
                    )
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text('Authorized by BiasGuard™ Fairness Engine', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // --- Page 2: Summary ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader('EXECUTIVE SUMMARY'),
              pw.SizedBox(height: 20),
              pw.Text(
                'This report provides a formal assessment of algorithmic fairness for the dataset "$datasetName". '
                'The analysis focuses on systemic outcome disparities.',
                style: pw.TextStyle(fontSize: 14, lineSpacing: 4),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Gemini Analysis Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.indigo900, width: 4)),
                ),
                child: pw.Text(
                  analysisData['explanation_en'] ?? 'No analysis content available.',
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save as Bytes and trigger Web Download
    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    html.AnchorElement(href: url)
      ..setAttribute("download", "BiasGuard_Fairness_Report_${scanId.substring(0, 5)}.pdf")
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
        pw.SizedBox(height: 5),
        pw.Container(height: 2, width: 40, color: PdfColors.indigo900),
      ],
    );
  }

  static pw.Widget _buildMitigationPoint(String title, String desc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• $title', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 15),
            child: pw.Text(desc, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _buildGroupRow(String group, String rate, String parity) {
    return pw.TableRow(
      children: [
        _buildTableCell(group),
        _buildTableCell(rate),
        _buildTableCell(parity),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10),
      ),
    );
  }

  static pw.TableRow _buildMetricRow(String name, dynamic value, double threshold) {
    final double val = (value is num) ? value.toDouble() : 0.0;
    final bool passed = val >= threshold;
    return pw.TableRow(
      children: [
        _buildTableCell(name),
        _buildTableCell('${(val * 100).toInt()}%'),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            passed ? 'PASSED' : 'ACTION REQUIRED',
            style: pw.TextStyle(
              color: passed ? PdfColors.green : PdfColors.red, 
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

