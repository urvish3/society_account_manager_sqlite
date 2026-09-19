// lib/screens/reports/report_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/database_service.dart';
import '../../services/report_service.dart';
import 'common_account_report_screen.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');
const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _db = DatabaseService();
  final _reportSvc = ReportService();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  MonthlySummary? _summary;
  bool _loading = false;
  int _generatingIndex = -1; // -1 for none, 0: Std, 1: High, 2: Excel
  final _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    final summary = await _db.computeMonthlySummary(_year, _month, societyId: provider.society?.id);
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Financial Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MonthNavButton(
                  icon: Icons.chevron_left,
                  onPressed: () {
                    setState(() {
                      if (_month == 1) {
                        _month = 12;
                        _year--;
                      } else {
                        _month--;
                      }
                    });
                    _load();
                  },
                ),
                Column(
                  children: [
                    Text(
                      _months[_month],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '$_year',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                _MonthNavButton(
                  icon: Icons.chevron_right,
                  onPressed: () {
                    setState(() {
                      if (_month == 12) {
                        _month = 1;
                        _year++;
                      } else {
                        _month++;
                      }
                    });
                    _load();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_summary != null) _SummaryCard(summary: _summary!),
                        const SizedBox(height: 28),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Export Options',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ReportButton(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Standard PDF',
                          subtitle: 'Fast, text-based',
                          color: const Color(0xFF1565C0),
                          generating: _generatingIndex == 0,
                          onTap: () => _generatePdf(),
                        ),
                        const SizedBox(height: 12),
                        _ReportButton(
                          icon: Icons.auto_awesome_outlined,
                          label: 'High Precision PDF',
                          subtitle: 'Perfect for Gujarati text',
                          color: const Color(0xFF6366F1),
                          generating: _generatingIndex == 1,
                          onTap: () => _generatePerfectPdf(),
                        ),
                        const SizedBox(height: 12),
                        _ReportButton(
                          icon: Icons.table_chart_outlined,
                          label: 'Excel Spreadsheet',
                          subtitle: 'For accounting software',
                          color: const Color(0xFF10B981),
                          generating: _generatingIndex == 2,
                          onTap: () => _generateExcel(),
                        ),
                        const SizedBox(height: 12),
                        _ReportButton(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Common Account & Allocation Report',
                          subtitle: 'View wing transfers, shares & surplus',
                          color: const Color(0xFF7C3AED),
                          generating: false,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CommonAccountReportScreen()),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingIndex = 0);
    try {
      final provider = context.read<AppProvider>();
      final file = await _reportSvc.generatePdfReport(_year, _month, societyId: provider.society?.id);
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() => _generatingIndex = -1);
        await Printing.sharePdf(bytes: bytes, filename: file.path.split('/').last);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingIndex = -1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _generatePerfectPdf() async {
    if (_summary == null) return;
    setState(() => _generatingIndex = 1);
    try {
      final provider = context.read<AppProvider>();
      final society = provider.society;
      final socId = society?.id;

      // Calculate wings label once
      final wingNames = provider.wings.map((w) => w.name).toSet().toList();
      wingNames.sort();
      final wingsLabel = wingNames.isNotEmpty ? ' (${wingNames.join(', ')})' : '';

      // 1. Fetch all data
      final mm = await _db.getMaintenanceMonth(_year, _month, societyId: socId);
      final transactions = await _db.getTransactions(_year, _month, societyId: socId);
      List<FlatMaintenance> flats = [];
      if (mm != null) {
        flats = await _db.getFlatMaintenances(mm.id!);
        flats.sort((a, b) {
          if (a.wingName != b.wingName && a.wingName != null && b.wingName != null) {
            return a.wingName!.compareTo(b.wingName!);
          }
          final aNum = int.tryParse(a.flatNumber.replaceAll(RegExp(r'\D'), ''));
          final bNum = int.tryParse(b.flatNumber.replaceAll(RegExp(r'\D'), ''));
          if (aNum != null && bNum != null && aNum != bNum) return aNum.compareTo(bNum);
          return a.flatNumber.compareTo(b.flatNumber);
        });
      }

      final List<Uint8List> images = [];
      final targetSize = const Size(595, 842);
      bool summaryCaptured = false;

      // 2. Generate Maintenance Page
      if (flats.isNotEmpty) {
        final totalCollected = flats.where((f) => f.status == PaymentStatus.paid).fold(0.0, (s, f) => s + f.totalAmount);

        final image = await _screenshotController.captureFromWidget(
          _ReportPageWrapper(
            isA4: true,
            child: _MaintenancePageContent(
              society: society,
              monthLabel: _summary!.monthLabel,
              flats: flats,
              isFirstPage: true,
              isLastPage: true,
              totalCollected: totalCollected,
              wingsLabel: wingsLabel,
            ),
          ),
          targetSize: targetSize,
          pixelRatio: 2.0,
          delay: const Duration(milliseconds: 100),
        );
        images.add(image);
      }

      // 3. Generate Transactions Pages
      const int txnsPerPage = 22; // Slightly more per page due to reduced padding
      if (transactions.isNotEmpty) {
        final cashInc = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId == null).toList();
        final bankInc = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId != null).toList();
        final cashExp = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId == null).toList();
        final bankExp = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId != null).toList();
        final transfers = transactions.where((t) => t.type == TransactionType.cashToBank || t.type == TransactionType.bankToCash || t.type == TransactionType.bankToBank).toList();

        final sortedTransactions = [...cashInc, ...bankInc, ...cashExp, ...bankExp, ...transfers];

        for (int i = 0; i < sortedTransactions.length; i += txnsPerPage) {
          final isLastChunk = (i + txnsPerPage) >= sortedTransactions.length;
          final chunk = sortedTransactions.sublist(i, isLastChunk ? sortedTransactions.length : i + txnsPerPage);

          final image = await _screenshotController.captureFromWidget(
            _ReportPageWrapper(
              isA4: true,
              child: _TransactionsPageContent(society: society, monthLabel: _summary!.monthLabel, transactions: chunk, isFirstPage: i == 0, summary: _summary!, wingsLabel: wingsLabel),
            ),
            targetSize: targetSize,
            pixelRatio: 2.0,
            delay: const Duration(milliseconds: 100),
          );
          images.add(image);
        }
      }

      // 4. Dedicated Summary Page
      final summaryImage = await _screenshotController.captureFromWidget(
        _ReportPageWrapper(
          isA4: true,
          child: _SummaryPageContent(summary: _summary!, society: society, wingsLabel: wingsLabel),
        ),
        targetSize: targetSize,
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 100),
      );
      images.add(summaryImage);

      if (images.isNotEmpty) {
        final socName = society?.name ?? 'Society';
        final fileName = '${socName}_${_months[_month]}_$_year';
        final file = await _reportSvc.generateImagePdfReport(images, fileName);
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() => _generatingIndex = -1);
          await Printing.sharePdf(bytes: bytes, filename: file.path.split('/').last);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingIndex = -1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _generateExcel() async {
    setState(() => _generatingIndex = 2);
    try {
      final provider = context.read<AppProvider>();
      final file = await _reportSvc.generateExcelReport(_year, _month, societyId: provider.society?.id);
      if (mounted) {
        setState(() => _generatingIndex = -1);
        await Share.shareXFiles([XFile(file.path)], subject: 'Society Report ${_months[_month]} $_year');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingIndex = -1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _MonthNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF1E293B)),
        onPressed: onPressed,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthlySummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: const Row(
              children: [
                Icon(Icons.summarize_outlined, color: Color(0xFF1565C0), size: 20),
                SizedBox(width: 12),
                Text(
                  'Financial Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _BalanceSection(title: 'Opening Balances', items: [_rowItem('Cash', summary.openingCashBalance), _rowItem('Bank', summary.openingBankBalance)]),
                const SizedBox(height: 20),
                _BalanceSection(
                  title: 'Collections & Income',
                  titleColor: const Color(0xFF2E7D32),
                  items: [
                    _rowItem('Maintenance (Cash)', summary.cashMaintenanceCollected, valueColor: const Color(0xFF2E7D32)),
                    _rowItem('Maintenance (Bank)', summary.bankMaintenanceCollected, valueColor: const Color(0xFF2E7D32)),
                    _rowItem('Other Income', summary.cashIncome + summary.bankIncome, valueColor: const Color(0xFF2E7D32)),
                  ],
                  footer: _rowItem('Total Income', summary.totalIncome, isBold: true, valueColor: const Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 20),
                _BalanceSection(
                  title: 'Expenses',
                  titleColor: const Color(0xFFD32F2F),
                  items: [
                    _rowItem('Cash Expenses', summary.cashExpense, valueColor: const Color(0xFFD32F2F)),
                    _rowItem('Bank Expenses', summary.bankExpense, valueColor: const Color(0xFFD32F2F)),
                  ],
                  footer: _rowItem('Total Expense', summary.totalExpense, isBold: true, valueColor: const Color(0xFFD32F2F)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(13), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _rowItem('Closing Cash', summary.closingCashBalance, isBold: true, valueColor: const Color(0xFF1565C0)),
                      const SizedBox(height: 8),
                      _rowItem('Closing Bank', summary.closingBankBalance, isBold: true, valueColor: const Color(0xFF1565C0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: const Color(0xFF1565C0).withAlpha(51)),
                      ),
                      _rowItem('NET BALANCE', summary.totalClosingBalance, isBold: true, isLarge: true, valueColor: const Color(0xFF1565C0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  final Widget? footer;
  final Color? titleColor;

  const _BalanceSection({required this.title, required this.items, this.footer, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: titleColor ?? const Color(0xFF64748B), letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        ...items,
        if (footer != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          footer!,
        ],
      ],
    );
  }
}

Widget _rowItem(String label, double value, {bool isBold = false, bool isLarge = false, Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: isLarge ? 15 : 13, color: isBold ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
        ),
        Text(
          '₹ ${_fmt.format(value)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF1E293B), fontSize: isLarge ? 17 : 14),
        ),
      ],
    ),
  );
}

class _ReportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final bool generating;
  final VoidCallback onTap;

  const _ReportButton({required this.icon, required this.label, this.subtitle, required this.color, required this.generating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Determine if ANY report is being generated to disable other buttons
    final isAnyGenerating = context.findAncestorStateOfType<_ReportScreenState>()?._generatingIndex != -1;

    return InkWell(
      onTap: (generating || isAnyGenerating) ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14)),
              child: generating ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: color)) : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14),
                  ),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(color: const Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Widgets for Perfect PDF (Image-based) ──────────────────

class _ReportPageWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool isA4;
  const _ReportPageWrapper({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 20), this.isA4 = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Container(
          width: 595, // A4 width at 72dpi
          height: isA4 ? 842 : null, // A4 height at 72dpi OR wrap content
          color: Colors.white,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  final Society? society;
  final String title;
  final String? wingsLabel;
  const _ReportHeader({this.society, required this.title, this.wingsLabel});

  @override
  Widget build(BuildContext context) {
    final displayWingsLabel = wingsLabel ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${society?.name ?? 'Society'}$displayWingsLabel',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
        ),
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        const SizedBox(height: 4),
        const Divider(color: Color(0xFF1565C0), thickness: 1.5),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final double? total;
  const _SectionTitle(this.text, {this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(2),
      ),
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5),
          ),
          if (total != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(4)),
              child: Text(
                'Total: ₹ ${_fmt.format(total!)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _MaintenancePageContent extends StatelessWidget {
  final Society? society;
  final String monthLabel;
  final List<FlatMaintenance> flats;
  final bool isFirstPage;
  final bool isLastPage;
  final double totalCollected;
  final String? wingsLabel;

  const _MaintenancePageContent({this.society, required this.monthLabel, required this.flats, this.isFirstPage = true, this.isLastPage = true, required this.totalCollected, this.wingsLabel});

  @override
  Widget build(BuildContext context) {
    // Split flats into two columns (approx 28 per side)
    const int midPoint = 28;
    final leftColumn = flats.length > midPoint ? flats.sublist(0, midPoint) : flats;
    final rightColumn = flats.length > midPoint ? flats.sublist(midPoint, (midPoint * 2) > flats.length ? flats.length : (midPoint * 2)) : <FlatMaintenance>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirstPage) ...[_ReportHeader(society: society, title: 'Maintenance - $monthLabel', wingsLabel: wingsLabel), const SizedBox(height: 8)],
        _SectionTitle('Maintenance Collection${isFirstPage ? '' : ' (Continued)'}', total: isFirstPage ? totalCollected : null),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left Column
            Expanded(child: _buildMaintTable(leftColumn)),
            const SizedBox(width: 12),
            // Right Column
            Expanded(child: rightColumn.isNotEmpty ? _buildMaintTable(rightColumn) : Container()),
          ],
        ),
      ],
    );
  }

  Widget _buildMaintTable(List<FlatMaintenance> chunk) {
    return Table(
      border: TableBorder.all(color: Colors.grey[400]!, width: 0.5),
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(2)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1565C0)),
          children: [_headerCell('Unit No'), _headerCell('Amount'), _headerCell('Note')],
        ),
        ...chunk.map(
          (f) => TableRow(
            decoration: BoxDecoration(color: f.status == PaymentStatus.paid ? Colors.green[50] : null),
            children: [
              _cell(f.wingName != null ? '${f.wingName} - ${f.flatNumber}' : f.flatNumber),
              _cell('₹ ${_fmt.format(f.totalAmount)}'),
              _cell(f.formattedExtraDetails.isNotEmpty ? f.formattedExtraDetails : (f.extraAmount > 0 ? '+ ₹${f.extraAmount}' : '')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8.5),
    ),
  );

  Widget _cell(String text) {
    // Determine font size based on text length to try and fit more
    double fontSize = 8.5;
    if (text.length > 25) fontSize = 7.5;
    if (text.length > 35) fontSize = 6.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize),
        softWrap: true,
        maxLines: 5,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

class _TransactionsPageContent extends StatelessWidget {
  final Society? society;
  final String monthLabel;
  final List<Transaction> transactions;
  final bool isFirstPage;
  final MonthlySummary summary;
  final String? wingsLabel;

  const _TransactionsPageContent({this.society, required this.monthLabel, required this.transactions, this.isFirstPage = true, required this.summary, this.wingsLabel});

  @override
  Widget build(BuildContext context) {
    final cashInc = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId == null).toList();
    final bankInc = transactions.where((t) => t.type == TransactionType.income && t.bankAccountId != null).toList();
    final cashExp = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId == null).toList();
    final bankExp = transactions.where((t) => t.type == TransactionType.expense && t.bankAccountId != null).toList();
    final transfers = transactions.where((t) => t.type == TransactionType.cashToBank || t.type == TransactionType.bankToCash || t.type == TransactionType.bankToBank).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirstPage) ...[_ReportHeader(society: society, title: 'Transactions - $monthLabel', wingsLabel: wingsLabel), const SizedBox(height: 12)],
        if (cashInc.isNotEmpty) ...[_SectionTitle('Cash Income${isFirstPage ? '' : ' (Cont.)'}', total: isFirstPage ? summary.cashIncome : null), _txnTable(cashInc), const SizedBox(height: 12)],
        if (bankInc.isNotEmpty) ...[_SectionTitle('Bank Income${isFirstPage ? '' : ' (Cont.)'}', total: isFirstPage ? summary.bankIncome : null), _txnTable(bankInc), const SizedBox(height: 12)],
        if (cashExp.isNotEmpty) ...[_SectionTitle('Cash Expenses${isFirstPage ? '' : ' (Cont.)'}', total: isFirstPage ? summary.cashExpense : null), _txnTable(cashExp), const SizedBox(height: 12)],
        if (bankExp.isNotEmpty) ...[_SectionTitle('Bank Expenses${isFirstPage ? '' : ' (Cont.)'}', total: isFirstPage ? summary.bankExpense : null), _txnTable(bankExp), const SizedBox(height: 12)],
        if (transfers.isNotEmpty) ...[_SectionTitle('Transfers (C↔B, B↔B)${isFirstPage ? '' : ' (Cont.)'}', total: isFirstPage ? summary.cashToBank + summary.bankToCash : null), _txnTable(transfers)],
      ],
    );
  }

  Widget _txnTable(List<Transaction> txns) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(3), 3: FlexColumnWidth(1.2)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1565C0)),
          children: [_headerCell('Date'), _headerCell('Category'), _headerCell('Description'), _headerCell('Amount')],
        ),
        ...txns.map((t) => TableRow(children: [_cell(dateFmt.format(t.date)), _cell(t.categoryName ?? t.type.name), _cell(t.description), _cell('₹ ${_fmt.format(t.amount)}')])),
      ],
    );
  }

  Widget _headerCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5, color: Colors.white),
    ),
  );

  Widget _cell(String text) {
    double fontSize = 8.5;
    if (text.length > 30) fontSize = 7.5;
    if (text.length > 45) fontSize = 6.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize),
        softWrap: true,
        maxLines: 2,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

class _SummaryPageContent extends StatelessWidget {
  final MonthlySummary summary;
  final Society? society;
  final bool showHeader;
  final String? wingsLabel;
  const _SummaryPageContent({required this.summary, this.society, this.showHeader = true, this.wingsLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[_ReportHeader(society: society, title: 'Monthly Summary - ${summary.monthLabel}', wingsLabel: wingsLabel), const SizedBox(height: 20)],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1565C0)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _summaryRow('Opening Cash Balance', summary.openingCashBalance),
              _summaryRow('Opening Bank Balance', summary.openingBankBalance),
              const Divider(),
              _summaryRow('Cash Maintenance', summary.cashMaintenanceCollected),
              _summaryRow('Bank Maintenance', summary.bankMaintenanceCollected),
              _summaryRow('Cash Income', summary.cashIncome),
              _summaryRow('Bank Income', summary.bankIncome),
              _summaryRow('Total Income', summary.totalIncome, bold: true),
              const Divider(),
              _summaryRow('Cash Expense', summary.cashExpense),
              _summaryRow('Bank Expense', summary.bankExpense),
              _summaryRow('Total Expense', summary.totalExpense, bold: true),
              const Divider(),
              _summaryRow('Cash to Bank', summary.cashToBank),
              _summaryRow('Bank to Cash', summary.bankToCash),
              const Divider(thickness: 1.5, color: Colors.grey),
              _summaryRow('Closing Cash Balance', summary.closingCashBalance, bold: true),
              _summaryRow('Closing Bank Balance', summary.closingBankBalance, bold: true),
              const Divider(thickness: 2, color: Color(0xFF1565C0)),
              _summaryRow('TOTAL BALANCE', summary.totalClosingBalance, bold: true, large: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: large ? 13 : 10),
          ),
          Text(
            '₹ ${_fmt.format(value)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: large ? 14 : 10, color: const Color(0xFF1565C0)),
          ),
        ],
      ),
    );
  }
}
