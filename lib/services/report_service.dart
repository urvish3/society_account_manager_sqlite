// lib/services/report_service.dart
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import 'database_service.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');
final _dateFmt = DateFormat('dd/MM/yyyy');

class ReportService {
  final _db = DatabaseService();

  // ── Excel Report ───────────────────────────

  Future<File> generateExcelReport(int year, int month, {int? societyId}) async {
    final mm = await _db.getMaintenanceMonth(year, month, societyId: societyId);
    final summary = await _db.computeMonthlySummary(year, month, societyId: societyId);
    final transactions = await _db.getTransactions(year, month, societyId: societyId);
    final societies = await _db.getSocieties();
    final society = societies.firstWhere((s) => s.id == societyId, orElse: () => societies.first);

    final excel = Excel.createExcel();

    // ── Sheet 1: Maintenance ──
    final maintSheet = excel['Maintenance'];
    excel.setDefaultSheet('Maintenance');

    final monthLabel = summary.monthLabel;
    _addCell(maintSheet, 0, 0, 'Maintenance - $monthLabel', bold: true, size: 14);

    if (mm != null) {
      final flats = await _db.getFlatMaintenances(mm.id!);

      // Sort flats by Wing then Flat Number numerically
      flats.sort((a, b) {
        if (a.wingName != b.wingName && a.wingName != null && b.wingName != null) {
          return a.wingName!.compareTo(b.wingName!);
        }
        final aNum = int.tryParse(a.flatNumber.replaceAll(RegExp(r'\D'), ''));
        final bNum = int.tryParse(b.flatNumber.replaceAll(RegExp(r'\D'), ''));
        if (aNum != null && bNum != null && aNum != bNum) return aNum.compareTo(bNum);
        return a.flatNumber.compareTo(b.flatNumber);
      });

      // Header row
      _addCell(maintSheet, 2, 0, 'Unit No', bold: true);
      _addCell(maintSheet, 2, 1, 'Base Amount', bold: true);
      _addCell(maintSheet, 2, 2, 'Extra Amount', bold: true);
      _addCell(maintSheet, 2, 3, 'Extra Note', bold: true);
      _addCell(maintSheet, 2, 4, 'Total', bold: true);
      _addCell(maintSheet, 2, 5, 'Status', bold: true);
      _addCell(maintSheet, 2, 6, 'Remarks', bold: true);

      int row = 3;
      double collected = 0;
      for (final fm in flats) {
        _addCell(maintSheet, row, 0, fm.wingName != null ? '${fm.wingName} - ${fm.flatNumber}' : fm.flatNumber);
        _addCell(maintSheet, row, 1, fm.baseAmount);
        _addCell(maintSheet, row, 2, fm.extraAmount > 0 ? fm.extraAmount : '');
        _addCell(maintSheet, row, 3, fm.formattedExtraDetails);
        _addCell(maintSheet, row, 4, fm.totalAmount);
        _addCell(maintSheet, row, 5, _statusLabel(fm.status));
        _addCell(maintSheet, row, 6, fm.remarks ?? '');
        if (fm.status == PaymentStatus.paid) collected += fm.totalAmount;
        row++;
      }

      row++;
      _addCell(maintSheet, row, 3, 'Total Collected', bold: true);
      _addCell(maintSheet, row, 4, collected, bold: true);
    }

    // ── Sheet 2: Transactions ──
    final txnSheet = excel['Transactions'];
    _addCell(txnSheet, 0, 0, 'Transactions - $monthLabel', bold: true, size: 14);

    final cashIncome = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId == null).toList();
    final bankIncome = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId != null).toList();
    final cashExpense = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId == null).toList();
    final bankExpense = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId != null).toList();
    final transfers = transactions.where((t) => t.type == TransactionType.cashToBank || t.type == TransactionType.bankToCash || t.type == TransactionType.bankToBank).toList();

    int row = 2;
    void addTxnSection(String title, List<Transaction> txns, double total) {
      if (txns.isEmpty && title != 'CASH MAINTENANCE' && title != 'BANK MAINTENANCE') return;
      _addCell(txnSheet, row, 0, title, bold: true);
      _addCell(txnSheet, row, 1, 'Date', bold: true);
      _addCell(txnSheet, row, 2, 'Category', bold: true);
      _addCell(txnSheet, row, 3, 'Description', bold: true);
      _addCell(txnSheet, row, 4, 'Amount', bold: true);
      row++;
      for (final t in txns) {
        _addCell(txnSheet, row, 1, _dateFmt.format(t.date));
        _addCell(txnSheet, row, 2, t.categoryName ?? _statusLabelFromType(t.type));
        _addCell(txnSheet, row, 3, t.description);
        _addCell(txnSheet, row, 4, t.amount);
        row++;
      }
      _addCell(txnSheet, row, 3, 'Total $title', bold: true);
      _addCell(txnSheet, row, 4, total, bold: true);
      row += 2;
    }

    addTxnSection('CASH INCOME', cashIncome, summary.cashIncome);
    addTxnSection('CASH MAINTENANCE', [], summary.cashMaintenanceCollected);
    addTxnSection('BANK INCOME', bankIncome, summary.bankIncome);
    addTxnSection('BANK MAINTENANCE', [], summary.bankMaintenanceCollected);
    addTxnSection('CASH EXPENSES', cashExpense, summary.cashExpense);
    addTxnSection('BANK EXPENSES', bankExpense, summary.bankExpense);
    addTxnSection('TRANSFERS', transfers, summary.cashToBank + summary.bankToCash);

    // ── Sheet 3: Summary ──
    final sumSheet = excel['Monthly Summary'];
    _addCell(sumSheet, 0, 0, 'Monthly Summary - $monthLabel', bold: true, size: 14);
    _addCell(sumSheet, 0, 1, society?.name ?? '');

    final rows = [
      ['Opening Cash Balance', summary.openingCashBalance],
      ['Opening Bank Balance', summary.openingBankBalance],
      ['Cash Maintenance Collected', summary.cashMaintenanceCollected],
      ['Bank Maintenance Collected', summary.bankMaintenanceCollected],
      ['Cash Income', summary.cashIncome],
      ['Bank Income', summary.bankIncome],
      ['Total Income', summary.totalIncome],
      ['Cash Expense', summary.cashExpense],
      ['Bank Expense', summary.bankExpense],
      ['Total Expense', summary.totalExpense],
      ['Cash to Bank', summary.cashToBank],
      ['Bank to Cash', summary.bankToCash],
      ['Closing Cash Balance', summary.closingCashBalance],
      ['Closing Bank Balance', summary.closingBankBalance],
      ['Total Balance', summary.totalClosingBalance],
    ];

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final isBold = ['Total Income', 'Total Expense', 'Closing Cash Balance', 'Closing Bank Balance', 'Total Balance'].contains(r[0]);
      _addCell(sumSheet, i + 2, 0, r[0] as String, bold: isBold);
      _addCell(sumSheet, i + 2, 1, r[1] as double, bold: isBold);
    }

    // Delete default Sheet1
    excel.delete('Sheet1');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${society?.name ?? "Society"}_${monthLabel.replaceAll(' ', '_')}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  void _addCell(Sheet sheet, int row, int col, dynamic value, {bool bold = false, double? size}) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is double) {
      cell.value = DoubleCellValue(value);
    } else if (value is int) {
      cell.value = IntCellValue(value);
    } else {
      cell.value = TextCellValue(value.toString());
    }
    if (bold || size != null) {
      cell.cellStyle = CellStyle(bold: bold, fontSize: size?.toInt());
    }
  }

  String _statusLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.exempt:
        return 'Exempt';
    }
  }

  String _statusLabelFromType(TransactionType t) {
    switch (t) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.cashToBank:
        return 'Cash to Bank';
      case TransactionType.bankToCash:
        return 'Bank to Cash';
      case TransactionType.bankToBank:
        return 'Bank to Bank';
    }
  }

  // ── PDF Report ─────────────────────────────

  Future<File> generatePdfReport(int year, int month, {int? societyId}) async {
    final mm = await _db.getMaintenanceMonth(year, month, societyId: societyId);
    final summary = await _db.computeMonthlySummary(year, month, societyId: societyId);
    final transactions = await _db.getTransactions(year, month, societyId: societyId);
    final societies = await _db.getSocieties();
    final society = societies.firstWhere((s) => s.id == societyId, orElse: () => societies.first);
    final monthLabel = summary.monthLabel;

    final robotoRegularData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final robotoBoldData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final arialUnicodeData = await rootBundle.load("assets/fonts/ArialUnicode.ttf");

    final robotoRegular = pw.Font.ttf(robotoRegularData);
    final robotoBold = pw.Font.ttf(robotoBoldData);
    final arialUnicode = pw.Font.ttf(arialUnicodeData);

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: robotoRegular, bold: robotoBold, fontFallback: [arialUnicode]);

    // ── Maintenance Page ──
    if (mm != null) {
      final flats = await _db.getFlatMaintenances(mm.id!);

      // Sort flats by Wing then Flat Number numerically
      flats.sort((a, b) {
        if (a.wingName != b.wingName && a.wingName != null && b.wingName != null) {
          return a.wingName!.compareTo(b.wingName!);
        }
        final aNum = int.tryParse(a.flatNumber.replaceAll(RegExp(r'\D'), ''));
        final bNum = int.tryParse(b.flatNumber.replaceAll(RegExp(r'\D'), ''));
        if (aNum != null && bNum != null && aNum != bNum) return aNum.compareTo(bNum);
        return a.flatNumber.compareTo(b.flatNumber);
      });

      final totalCollected = flats.where((f) => f.status == PaymentStatus.paid).fold(0.0, (s, f) => s + f.totalAmount);

      // Split flats into two columns
      const int midPoint = 28;
      final leftColumn = flats.length > midPoint ? flats.sublist(0, midPoint) : flats;
      final rightColumn = flats.length > midPoint ? flats.sublist(midPoint, (midPoint * 2) > flats.length ? flats.length : (midPoint * 2)) : <FlatMaintenance>[];

      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfHeader(society.name ?? 'Society', 'Maintenance - $monthLabel'),
              pw.SizedBox(height: 12),
              _pdfSectionTitle('Maintenance Collection', total: totalCollected),
              pw.SizedBox(height: 6),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildMaintPdfTable(leftColumn)),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: rightColumn.isNotEmpty ? _buildMaintPdfTable(rightColumn) : pw.Container()),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ── Transactions & Summary Page ──
    final cashIncome = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId == null).toList();
    final bankIncome = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId != null).toList();
    final cashExpense = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId == null).toList();
    final bankExpense = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId != null).toList();
    final transfers = transactions.where((t) => t.type == TransactionType.cashToBank || t.type == TransactionType.bankToCash || t.type == TransactionType.bankToBank).toList();

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          _pdfHeader(society.name ?? 'Society', 'Transactions - $monthLabel'),
          pw.SizedBox(height: 12),
          if (cashIncome.isNotEmpty) ...[_pdfSectionTitle('Cash Income', total: summary.cashIncome), _txnTable(cashIncome), pw.SizedBox(height: 8)],
          if (bankIncome.isNotEmpty) ...[_pdfSectionTitle('Bank Income', total: summary.bankIncome), _txnTable(bankIncome), pw.SizedBox(height: 8)],
          if (cashExpense.isNotEmpty) ...[_pdfSectionTitle('Cash Expenses', total: summary.cashExpense), _txnTable(cashExpense), pw.SizedBox(height: 8)],
          if (bankExpense.isNotEmpty) ...[_pdfSectionTitle('Bank Expenses', total: summary.bankExpense), _txnTable(bankExpense), pw.SizedBox(height: 8)],
          if (transfers.isNotEmpty) ...[_pdfSectionTitle('Transfers (C↔B, B↔B)', total: summary.cashToBank + summary.bankToCash), _txnTable(transfers), pw.SizedBox(height: 8)],
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue800),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                _pdfSummaryRow('Opening Cash Balance', '₹ ${_fmt.format(summary.openingCashBalance)}'),
                _pdfSummaryRow('Opening Bank Balance', '₹ ${_fmt.format(summary.openingBankBalance)}'),
                pw.Divider(color: PdfColors.grey400),
                _pdfSummaryRow('Cash Maintenance Collected', '₹ ${_fmt.format(summary.cashMaintenanceCollected)}'),
                _pdfSummaryRow('Bank Maintenance Collected', '₹ ${_fmt.format(summary.bankMaintenanceCollected)}'),
                _pdfSummaryRow('Cash Income', '₹ ${_fmt.format(summary.cashIncome)}'),
                _pdfSummaryRow('Bank Income', '₹ ${_fmt.format(summary.bankIncome)}'),
                _pdfSummaryRow('Total Income', '₹ ${_fmt.format(summary.totalIncome)}', bold: true),
                pw.Divider(color: PdfColors.grey400),
                _pdfSummaryRow('Cash Expense', '₹ ${_fmt.format(summary.cashExpense)}'),
                _pdfSummaryRow('Bank Expense', '₹ ${_fmt.format(summary.bankExpense)}'),
                _pdfSummaryRow('Total Expense', '₹ ${_fmt.format(summary.totalExpense)}', bold: true),
                pw.Divider(color: PdfColors.grey400),
                _pdfSummaryRow('Cash to Bank', '₹ ${_fmt.format(summary.cashToBank)}'),
                _pdfSummaryRow('Bank to Cash', '₹ ${_fmt.format(summary.bankToCash)}'),
                pw.Divider(color: PdfColors.grey700, thickness: 1.5),
                _pdfSummaryRow('Closing Cash Balance', '₹ ${_fmt.format(summary.closingCashBalance)}', bold: true),
                _pdfSummaryRow('Closing Bank Balance', '₹ ${_fmt.format(summary.closingBankBalance)}', bold: true),
                pw.Divider(color: PdfColors.blue900, thickness: 2),
                _pdfSummaryRow('TOTAL BALANCE', '₹ ${_fmt.format(summary.totalClosingBalance)}', bold: true, large: true),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Generated on ${_dateFmt.format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final soc = society?.name ?? 'Society';
    final fileName = '${soc}_${monthLabel.replaceAll(' ', '_')}_Report.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfHeader(String society, String title) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        society,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
      ),
      pw.Text(title, style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
      pw.Divider(color: PdfColors.blue800, thickness: 1.5),
    ],
  );

  pw.Widget _pdfSectionTitle(String text, {double? total}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          text,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        if (total != null)
          pw.Text(
            'Total: ₹ ${_fmt.format(total)}',
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
      ],
    ),
  );

  pw.Widget _buildMaintPdfTable(List<FlatMaintenance> chunk) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
          children: [_pdfHeaderCell('Unit No'), _pdfHeaderCell('Amount'), _pdfHeaderCell('Note')],
        ),
        ...chunk.map(
          (f) => pw.TableRow(
            decoration: pw.BoxDecoration(color: f.status == PaymentStatus.paid ? const PdfColor.fromInt(0xFFE8F5E9) : null),
            children: [
              _pdfCell(f.wingName != null ? '${f.wingName} - ${f.flatNumber}' : f.flatNumber),
              _pdfCell('₹ ${_fmt.format(f.totalAmount)}'),
              _pdfCell(f.formattedExtraDetails.isNotEmpty ? f.formattedExtraDetails : (f.extraAmount > 0 ? '+ ₹${f.extraAmount}' : '')),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
    ),
  );

  pw.Widget _pdfCell(String text) {
    // Determine font size based on length for better fit
    double fontSize = 9;
    if (text.length > 30) fontSize = 8;
    if (text.length > 45) fontSize = 7;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize), softWrap: true),
    );
  }

  pw.Widget _pdfSummaryRow(String label, String value, {bool bold = false, bool large = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null, fontSize: large ? 13 : 10),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: large ? 14 : 10, color: PdfColors.blue900),
        ),
      ],
    ),
  );

  pw.Widget _txnTable(List<Transaction> txns) => pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: {0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(3), 3: const pw.FlexColumnWidth(1.5)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
        children: [_pdfHeaderCell('Date'), _pdfHeaderCell('Category'), _pdfHeaderCell('Description'), _pdfHeaderCell('Amount')],
      ),
      ...txns.map(
        (t) => pw.TableRow(children: [_pdfCell(_dateFmt.format(t.date)), _pdfCell(t.categoryName ?? _txnTypeLabel(t.type)), _pdfCell(t.description), _pdfCell('₹ ${_fmt.format(t.amount)}')]),
      ),
    ],
  );

  String _txnTypeLabel(TransactionType t) {
    switch (t) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.cashToBank:
        return 'Cash→Bank';
      case TransactionType.bankToCash:
        return 'Bank→Cash';
      case TransactionType.bankToBank:
        return 'Bank→Bank';
    }
  }

  // ── Image-based PDF (for perfect Gujarati rendering) ──

  Future<File> generateImagePdfReport(List<Uint8List> images, String fileNamePrefix) async {
    final pdf = pw.Document();

    for (final imageBytes in images) {
      final image = pw.MemoryImage(imageBytes);
      // Determine image dimensions to set page size
      // Since we use pixelRatio 2.0, we divide by 2 to get point size
      final width = image.width?.toDouble() ?? PdfPageFormat.a4.width;
      final height = image.height?.toDouble() ?? PdfPageFormat.a4.height;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width / 2, height / 2),
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image));
          },
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${fileNamePrefix}_Report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
