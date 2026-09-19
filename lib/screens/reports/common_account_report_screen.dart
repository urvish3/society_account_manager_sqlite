// lib/screens/reports/common_account_report_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/report_service.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');

class CommonAccountReportScreen extends StatefulWidget {
  const CommonAccountReportScreen({super.key});

  @override
  State<CommonAccountReportScreen> createState() => _CommonAccountReportScreenState();
}

class _CommonAccountReportScreenState extends State<CommonAccountReportScreen> {
  final _reportSvc = ReportService();
  bool _loading = true;
  CommonAccountReport? _report;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _allTime = false;

  final List<String> _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    final report = await _reportSvc.computeCommonAccountReport(
      provider.society?.id,
      year: _allTime ? null : _year,
      month: _allTime ? null : _month,
    );
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Common Account & Allocation',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Report Period',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                    Row(
                      children: [
                        const Text(
                          'All Time',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: _allTime,
                          activeColor: primaryBlue,
                          onChanged: (val) {
                            setState(() => _allTime = val);
                            _loadReport();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_allTime) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(() {
                            if (_month == 1) {
                              _month = 12;
                              _year--;
                            } else {
                              _month--;
                            }
                          });
                          _loadReport();
                        },
                      ),
                      Text(
                        '${_months[_month]} $_year',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(() {
                            if (_month == 12) {
                              _month = 1;
                              _year++;
                            } else {
                              _month++;
                            }
                          });
                          _loadReport();
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _report == null || _report!.wingSummaries.isEmpty
                ? const Center(
                    child: Text('No wings or financial data found for this period.', style: TextStyle(color: subTextColor)),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withAlpha(40), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Society Common Expenses',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹ ${_fmt.format(_report!.totalCommonExpenses)}',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Distribution Mode: ${_report!.society.expenseDistributionMode.toUpperCase()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Wings: ${_report!.wingSummaries.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Wing / Block Breakdown & Surplus',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 12),

                      ..._report!.wingSummaries.map((summary) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      summary.wing.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 15),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Share: ${summary.wing.allocationPercentage}%',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: subTextColor, fontSize: 13),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, color: Color(0xFFE2E8F0)),
                              _buildRow('Money Transferred / Received', '₹ ${_fmt.format(summary.totalTransferred)}', textColor),
                              const SizedBox(height: 8),
                              _buildRow('Allocated Common Expense Share', '₹ ${_fmt.format(summary.allocatedExpenseShare)}', const Color(0xFFDC2626)),
                              const SizedBox(height: 8),
                              const Divider(height: 16, color: Color(0xFFF1F5F9)),
                              _buildRow(
                                'Net Surplus in Common Account',
                                '₹ ${_fmt.format(summary.surplusBalance)}',
                                summary.surplusBalance >= 0 ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                isBold: true,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valColor),
        ),
      ],
    );
  }
}
