// lib/screens/bank/bank_accounts_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';

final _fmt = NumberFormat('#,##0', 'en_IN');
final _dateFmt = DateFormat('dd/MM/yyyy');

class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    const primaryBlue = Color(0xFF1565C0);
    const bgBlue = Color(0xFFF8FAFC);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text(
          'Bank Accounts',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
      ),
      body: provider.bankAccounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: primaryBlue.withAlpha(13), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance, size: 64, color: primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No bank accounts added',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your society bank accounts to track\nbalances and transactions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add First Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddBank(context),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: provider.bankAccounts.length,
              itemBuilder: (_, i) {
                final bank = provider.bankAccounts[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: primaryBlue.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.account_balance, color: primaryBlue, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bank.bankName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                  ),
                                  Text('A/C: ${bank.accountNumber}', style: const TextStyle(color: subTextColor, fontSize: 13)),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: bank.isActive,
                              activeColor: primaryBlue,
                              onChanged: (v) async {
                                final updated = BankAccount(
                                  id: bank.id,
                                  societyId: bank.societyId,
                                  bankName: bank.bankName,
                                  accountNumber: bank.accountNumber,
                                  accountHolder: bank.accountHolder,
                                  openingBalance: bank.openingBalance,
                                  openingDate: bank.openingDate,
                                  isActive: v,
                                );
                                await context.read<AppProvider>().saveBankAccount(updated);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: bgBlue, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Opening Balance',
                                    style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹ ${_fmt.format(bank.openingBalance)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryBlue),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Opened On',
                                    style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _dateFmt.format(bank.openingDate),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (bank.accountHolder.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 14, color: subTextColor),
                                const SizedBox(width: 6),
                                Text('Holder: ${bank.accountHolder}', style: const TextStyle(color: subTextColor, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBank(context),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add),
        label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _showAddBank(BuildContext context) async {
    final bankCtrl = TextEditingController();
    final acctCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    DateTime openingDate = DateTime.now();
    String? error;

    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Add Bank Account',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: subTextColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildFieldLabel('Bank Name'),
                TextField(
                  controller: bankCtrl,
                  decoration: _inputDecoration('e.g. HDFC Bank'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                _buildFieldLabel('Account Number'),
                TextField(
                  controller: acctCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('e.g. 50100123456789'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                _buildFieldLabel('Account Holder Name'),
                TextField(
                  controller: holderCtrl,
                  decoration: _inputDecoration('e.g. Green Valley Society'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Opening Balance'),
                          TextField(
                            controller: balCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('0.00').copyWith(prefixText: '₹ '),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Opening Date'),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: openingDate,
                                firstDate: DateTime(2010),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: primaryBlue)),
                                    child: child!,
                                  );
                                },
                              );
                              if (d != null) setSt(() => openingDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dateFmt.format(openingDate),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (bankCtrl.text.isEmpty || acctCtrl.text.isEmpty) {
                        setSt(() => error = 'Please enter bank name and account number');
                        return;
                      }
                      final b = BankAccount(
                        bankName: bankCtrl.text.trim(),
                        accountNumber: acctCtrl.text.trim(),
                        accountHolder: holderCtrl.text.trim(),
                        openingBalance: double.tryParse(balCtrl.text) ?? 0,
                        openingDate: openingDate,
                      );
                      await context.read<AppProvider>().saveBankAccount(b);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Save Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
    );
  }
}
