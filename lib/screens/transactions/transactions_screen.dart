// lib/screens/transactions/transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/database_service.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');
final _dateFmt = DateFormat('dd MMM yyyy');
const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tab;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  List<Transaction> _transactions = [];
  MonthlySummary? _summary;
  int? _bankFilterId; // null = All, -1 = Cash, else = BankId
  int? _selectedWingId; // null = All / Common, else = Wing ID

  static const primaryBlue = Color(0xFF1565C0);
  static const bgBlue = Color(0xFFF8FAFC);
  static const textColor = Color(0xFF1E293B);
  static const subTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  MonthlySummary? _wingSummary;

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final txns = await _db.getTransactions(_year, _month, societyId: provider.society?.id);
    final summary = await _db.computeMonthlySummary(_year, _month, societyId: provider.society?.id);
    setState(() {
      _transactions = txns;
      _summary = summary;
    });
    await _loadWingSummary();
  }

  Future<void> _loadWingSummary() async {
    final provider = context.read<AppProvider>();
    final allMms = await _db.getAllMaintenanceMonths(societyId: provider.society?.id);
    double wingMaintCollected = 0;
    for (final mm in allMms) {
      if (mm.year == _year && mm.month == _month) {
        if (_selectedWingId == null || mm.wingId == _selectedWingId || mm.wingId == null) {
          final fms = await _db.getFlatMaintenances(mm.id!);
          for (final fm in fms) {
            if (fm.status == PaymentStatus.paid) {
              if (_selectedWingId != null) {
                final flat = provider.allFlats.where((f) => f.id == fm.flatId).firstOrNull;
                if (flat == null || flat.wingId == _selectedWingId) {
                  wingMaintCollected += fm.totalAmount;
                }
              } else {
                wingMaintCollected += fm.totalAmount;
              }
            }
          }
        }
      }
    }

    final incomeTxns = _ofType(TransactionType.income);
    final expenseTxns = _ofType(TransactionType.expense);
    double totalIncomeTxn = incomeTxns.fold(0.0, (sum, t) => sum + t.amount);
    double totalExpense = expenseTxns.fold(0.0, (sum, t) => sum + t.amount);

    if (mounted) {
      setState(() {
        _wingSummary = MonthlySummary(
          year: _year,
          month: _month,
          openingCashBalance: _summary?.openingCashBalance ?? 0,
          openingBankBalance: _summary?.openingBankBalance ?? 0,
          cashIncome: totalIncomeTxn + wingMaintCollected,
          bankIncome: 0,
          cashExpense: totalExpense,
          bankExpense: 0,
          cashToBank: 0,
          bankToCash: 0,
          cashMaintenanceCollected: wingMaintCollected,
          bankMaintenanceCollected: 0,
        );
      });
    }
  }

  List<Transaction> _ofType(TransactionType type) {
    var list = _transactions.where((t) => t.type == type).toList();
    if (_selectedWingId != null) {
      list = list.where((t) => t.wingId == _selectedWingId || t.wingId == null || t.isCommonExpense).toList();
    }
    if (_bankFilterId == -1) {
      list = list.where((t) => t.bankAccountId == null).toList();
    } else if (_bankFilterId != null) {
      list = list.where((t) => t.bankAccountId == _bankFilterId).toList();
    }
    return list;
  }

  List<Transaction> _transfers() {
    var list = _transactions.where((t) => t.type == TransactionType.cashToBank || t.type == TransactionType.bankToCash || t.type == TransactionType.bankToBank).toList();
    if (_selectedWingId != null) {
      list = list.where((t) => t.wingId == _selectedWingId || t.wingId == null).toList();
    }
    if (_bankFilterId != null && _bankFilterId != -1) {
      list = list.where((t) => t.bankAccountId == _bankFilterId || t.toBankAccountId == _bankFilterId).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(borderRadius: BorderRadius.circular(14), color: primaryBlue),
              labelColor: Colors.white,
              unselectedLabelColor: subTextColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Income'),
                Tab(text: 'Expense'),
                Tab(text: 'Transfers'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _MonthSummaryBar(
            year: _year,
            month: _month,
            summary: _wingSummary,
            onMonthChanged: (y, m) {
              setState(() {
                _year = y;
                _month = m;
              });
              _load();
            },
          ),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All / Common',
                  selected: _selectedWingId == null,
                  onSelected: () {
                    setState(() => _selectedWingId = null);
                    _loadWingSummary();
                  },
                ),
                ...provider.wings.map(
                  (w) => _FilterChip(
                    label: w.name,
                    selected: _selectedWingId == w.id,
                    onSelected: () {
                      setState(() => _selectedWingId = w.id);
                      _loadWingSummary();
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(label: 'All Accounts', selected: _bankFilterId == null, onSelected: () => setState(() => _bankFilterId = null)),
                _FilterChip(label: 'Cash', selected: _bankFilterId == -1, onSelected: () => setState(() => _bankFilterId = -1)),
                ...provider.bankAccounts.map((b) => _FilterChip(label: b.bankName, selected: _bankFilterId == b.id, onSelected: () => setState(() => _bankFilterId = b.id))),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TxnList(transactions: _ofType(TransactionType.income), onEdit: _showTransactionForm, onDelete: _delete),
                _TxnList(transactions: _ofType(TransactionType.expense), onEdit: _showTransactionForm, onDelete: _delete),
                _TxnList(transactions: _transfers(), onEdit: _showTransactionForm, onDelete: _delete),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionForm(),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _delete(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete this ${t.type.name} transaction for ₹${t.amount}?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteTransaction(t.id!);
      _load();
    }
  }

  Future<void> _showTransactionForm([Transaction? existing]) async {
    final provider = context.read<AppProvider>();
    final categories = provider.categories;
    final bankAccounts = provider.bankAccounts;

    TransactionType type = existing?.type ?? TransactionType.income;
    TransactionCategory? selectedCategory;
    if (existing?.categoryId != null) {
      try {
        selectedCategory = categories.firstWhere((c) => c.id == existing!.categoryId);
      } catch (_) {}
    }
    BankAccount? selectedBank;
    if (existing?.bankAccountId != null) {
      try {
        selectedBank = bankAccounts.firstWhere((b) => b.id == existing!.bankAccountId);
      } catch (_) {}
    }

    BankAccount? selectedToBank;
    if (existing?.toBankAccountId != null) {
      try {
        selectedToBank = bankAccounts.firstWhere((b) => b.id == existing!.toBankAccountId);
      } catch (_) {}
    }

    final wings = provider.wings;
    bool isCommonExpense = existing?.isCommonExpense ?? false;
    String distributionMode = existing?.distributionMode ?? 'equal';
    Wing? selectedWing;
    if (existing?.wingId != null) {
      try {
        selectedWing = wings.firstWhere((w) => w.id == existing!.wingId);
      } catch (_) {}
    }

    final amtCtrl = TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.date ?? DateTime(_year, _month, DateTime.now().day);
    if (selectedDate.month != _month || selectedDate.year != _year) {
      selectedDate = DateTime(_year, _month, 1);
    }

    double availableBalance = -1;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            final filteredCats = categories
                .where((c) => (type == TransactionType.income && c.type == TransactionType.income) || (type == TransactionType.expense && c.type == TransactionType.expense))
                .toList();

            void updateBalance() async {
              int? sourceId;
              if (type == TransactionType.cashToBank) {
                sourceId = null;
              } else if (type == TransactionType.bankToCash || type == TransactionType.bankToBank) {
                sourceId = selectedBank?.id;
              } else if (type == TransactionType.expense) {
                sourceId = selectedBank?.id;
              } else {
                setSt(() => availableBalance = -1);
                return;
              }

              double bal = await provider.getAccountBalance(sourceId, selectedDate.year, selectedDate.month);

              if (existing != null) {
                if (existing!.type == TransactionType.income) {
                  if (existing!.bankAccountId == sourceId) bal -= existing!.amount;
                } else if (existing!.type == TransactionType.expense) {
                  if (existing!.bankAccountId == sourceId) bal += existing!.amount;
                } else if (existing!.type == TransactionType.cashToBank) {
                  if (sourceId == null) bal += existing!.amount;
                  if (existing!.bankAccountId == sourceId) bal -= existing!.amount;
                } else if (existing!.type == TransactionType.bankToCash) {
                  if (existing!.bankAccountId == sourceId) bal += existing!.amount;
                  if (sourceId == null) bal -= existing!.amount;
                } else if (existing!.type == TransactionType.bankToBank) {
                  if (existing!.bankAccountId == sourceId) bal += existing!.amount;
                  if (existing!.toBankAccountId == sourceId) bal -= existing!.amount;
                }
              }

              if (ctx.mounted) setSt(() => availableBalance = double.parse(bal.toStringAsFixed(2)));
            }

            if (availableBalance == -1) {
              updateBalance();
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        existing == null ? 'Add Transaction' : 'Edit Transaction',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: subTextColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: bgBlue, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        _buildTypeSegment(TransactionType.income, 'Income', type, (t) {
                          setSt(() {
                            type = t;
                            selectedCategory = null;
                          });
                          updateBalance();
                        }),
                        _buildTypeSegment(TransactionType.expense, 'Expense', type, (t) {
                          setSt(() {
                            type = t;
                            selectedCategory = null;
                          });
                          updateBalance();
                        }),
                        _buildTypeSegment(TransactionType.cashToBank, 'C→B', type, (t) {
                          setSt(() {
                            type = t;
                            selectedCategory = null;
                            selectedBank = null;
                          });
                          updateBalance();
                        }),
                        _buildTypeSegment(TransactionType.bankToCash, 'B→C', type, (t) {
                          setSt(() {
                            type = t;
                            selectedCategory = null;
                            if (bankAccounts.isNotEmpty && selectedBank == null) selectedBank = bankAccounts.first;
                          });
                          updateBalance();
                        }),
                        if (bankAccounts.length >= 2)
                          _buildTypeSegment(TransactionType.bankToBank, 'B→B', type, (t) {
                            setSt(() {
                              type = t;
                              selectedCategory = null;
                              if (bankAccounts.length >= 2) {
                                if (selectedBank == null) selectedBank = bankAccounts.first;
                                if (selectedToBank == null) selectedToBank = bankAccounts[1];
                              }
                            });
                            updateBalance();
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (wings.isNotEmpty) ...[
                    _buildFieldLabel('Transaction Account / Scope'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Wing?>(
                          value: selectedWing,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<Wing?>(
                              value: null,
                              child: Text('Society (General / Common Account)', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...wings.map(
                              (w) => DropdownMenuItem<Wing?>(
                                value: w,
                                child: Text('Wing / Block: ${w.name}', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                          onChanged: (v) => setSt(() => selectedWing = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (type != TransactionType.income)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: availableBalance <= 0.001 ? const Color(0xFFFEF2F2) : primaryBlue.withAlpha(13), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(
                            availableBalance <= 0.001 ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                            size: 18,
                            color: availableBalance <= 0.001 ? const Color(0xFFEF4444) : primaryBlue,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Available ${(type == TransactionType.cashToBank || (type != TransactionType.bankToCash && type != TransactionType.bankToBank && selectedBank == null)) ? "Cash" : "Bank"} Balance: ₹ ${_fmt.format(availableBalance < 0 ? 0 : availableBalance)}',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: availableBalance <= 0.001 ? const Color(0xFFB91C1C) : primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  if (errorMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 20),
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
                              errorMessage!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFFB91C1C)),
                            onPressed: () => setSt(() => errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Date'),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(_year, _month, 1), lastDate: DateTime(_year, _month + 1, 0));
                                if (d != null) {
                                  setSt(() => selectedDate = d);
                                  updateBalance();
                                }
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
                                      _dateFmt.format(selectedDate),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Amount'),
                            TextField(
                              controller: amtCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('0.00').copyWith(prefixText: '₹ '),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (type == TransactionType.income || type == TransactionType.expense) ...[
                    _buildFieldLabel('Category'),
                    DropdownButtonFormField<TransactionCategory>(
                      value: selectedCategory,
                      decoration: _inputDecoration('Select Category'),
                      items: filteredCats.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (v) => setSt(() => selectedCategory = v),
                    ),
                    const SizedBox(height: 18),
                    _buildFieldLabel('Payment Mode'),
                    DropdownButtonFormField<BankAccount?>(
                      value: selectedBank,
                      decoration: _inputDecoration('Select Mode'),
                      items: [
                        const DropdownMenuItem<BankAccount?>(value: null, child: Text('Cash')),
                        ...bankAccounts.map((b) => DropdownMenuItem(value: b, child: Text(b.bankName))),
                      ],
                      onChanged: (v) {
                        setSt(() => selectedBank = v);
                        updateBalance();
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (type == TransactionType.cashToBank && bankAccounts.isNotEmpty) ...[
                    _buildFieldLabel('To Bank Account'),
                    DropdownButtonFormField<BankAccount>(
                      value: selectedBank,
                      decoration: _inputDecoration('Select Bank'),
                      items: bankAccounts
                          .map((b) => DropdownMenuItem(value: b, child: Text('${b.bankName} (${b.accountNumber.substring(b.accountNumber.length > 4 ? b.accountNumber.length - 4 : 0)})')))
                          .toList(),
                      onChanged: (v) {
                        setSt(() => selectedBank = v);
                        updateBalance();
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (type == TransactionType.bankToCash && bankAccounts.isNotEmpty) ...[
                    _buildFieldLabel('From Bank Account'),
                    DropdownButtonFormField<BankAccount>(
                      value: selectedBank,
                      decoration: _inputDecoration('Select Bank'),
                      items: bankAccounts
                          .map((b) => DropdownMenuItem(value: b, child: Text('${b.bankName} (${b.accountNumber.substring(b.accountNumber.length > 4 ? b.accountNumber.length - 4 : 0)})')))
                          .toList(),
                      onChanged: (v) {
                        setSt(() => selectedBank = v);
                        updateBalance();
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (type == TransactionType.bankToBank && bankAccounts.length >= 2) ...[
                    _buildFieldLabel('From Bank Account'),
                    DropdownButtonFormField<BankAccount>(
                      value: selectedBank,
                      decoration: _inputDecoration('Source Bank'),
                      items: bankAccounts
                          .map((b) => DropdownMenuItem(value: b, child: Text('${b.bankName} (${b.accountNumber.substring(b.accountNumber.length > 4 ? b.accountNumber.length - 4 : 0)})')))
                          .toList(),
                      onChanged: (v) {
                        setSt(() => selectedBank = v);
                        if (selectedToBank == v) {
                          selectedToBank = bankAccounts.firstWhere((b) => b.id != v!.id);
                        }
                        updateBalance();
                      },
                    ),
                    const SizedBox(height: 18),
                    _buildFieldLabel('To Bank Account'),
                    DropdownButtonFormField<BankAccount>(
                      value: selectedToBank,
                      decoration: _inputDecoration('Destination Bank'),
                      items: bankAccounts
                          .where((b) => b.id != selectedBank?.id)
                          .map((b) => DropdownMenuItem(value: b, child: Text('${b.bankName} (${b.accountNumber.substring(b.accountNumber.length > 4 ? b.accountNumber.length - 4 : 0)})')))
                          .toList(),
                      onChanged: (v) => setSt(() => selectedToBank = v),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (type == TransactionType.expense) ...[
                    SwitchListTile(
                      title: const Text(
                        'Is Society Common Expense',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      subtitle: const Text('Allocate across wings according to setup', style: TextStyle(fontSize: 12, color: subTextColor)),
                      value: isCommonExpense,
                      activeColor: primaryBlue,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setSt(() => isCommonExpense = val),
                    ),
                    if (isCommonExpense) ...[
                      const SizedBox(height: 12),
                      _buildFieldLabel('Expense Distribution Mode'),
                      DropdownButtonFormField<String>(
                        value: distributionMode,
                        decoration: _inputDecoration('Distribution Mode'),
                        items: const [
                          DropdownMenuItem(value: 'equal', child: Text('Equal Distribution')),
                          DropdownMenuItem(value: 'percentage', child: Text('Percentage / Share-Based')),
                        ],
                        onChanged: (v) => setSt(() => distributionMode = v ?? 'equal'),
                      ),
                    ],
                    const SizedBox(height: 18),
                  ],
                  // Replaced by top-level Transaction Account / Scope selector
                  _buildFieldLabel('Description'),
                  TextField(
                    controller: descCtrl,
                    decoration: _inputDecoration('e.g. Monthly maintenance'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        FocusScope.of(ctx).unfocus();
                        final amount = double.tryParse(amtCtrl.text) ?? 0;
                        if (amount <= 0) {
                          setSt(() => errorMessage = 'Please enter a valid amount');
                          return;
                        }
                        if (type != TransactionType.income) {
                          int? sourceBankId;
                          String sourceName = "Cash";
                          if (type == TransactionType.expense) {
                            sourceBankId = selectedBank?.id;
                            sourceName = selectedBank == null ? "Cash" : "Bank";
                          } else if (type == TransactionType.cashToBank) {
                            sourceBankId = null;
                            sourceName = "Cash";
                          } else if (type == TransactionType.bankToCash) {
                            if (selectedBank == null) {
                              setSt(() => errorMessage = 'Please select a bank account');
                              return;
                            }
                            sourceBankId = selectedBank!.id;
                            sourceName = "Bank";
                          } else if (type == TransactionType.bankToBank) {
                            if (selectedBank == null || selectedToBank == null) {
                              setSt(() => errorMessage = 'Please select both bank accounts');
                              return;
                            }
                            sourceBankId = selectedBank!.id;
                            sourceName = "Source Bank";
                          }
                          double bal = await provider.getAccountBalance(sourceBankId, selectedDate.year, selectedDate.month);
                          if (existing != null) {
                            if (existing!.type == TransactionType.income && existing!.bankAccountId == sourceBankId)
                              bal -= existing!.amount;
                            else if (existing!.type == TransactionType.expense && existing!.bankAccountId == sourceBankId)
                              bal += existing!.amount;
                            else if (existing!.type == TransactionType.cashToBank) {
                              if (sourceBankId == null) bal += existing!.amount;
                              if (existing!.bankAccountId == sourceBankId) bal -= existing!.amount;
                            } else if (existing!.type == TransactionType.bankToCash) {
                              if (existing!.bankAccountId == sourceBankId) bal += existing!.amount;
                              if (sourceBankId == null) bal -= existing!.amount;
                            } else if (existing!.type == TransactionType.bankToBank) {
                              if (existing!.bankAccountId == sourceBankId) bal += existing!.amount;
                              if (existing!.toBankAccountId == sourceBankId) bal -= existing!.amount;
                            }
                          }
                          if (amount > (bal + 0.001)) {
                            if (ctx.mounted) {
                              setSt(() {
                                errorMessage = 'Insufficient $sourceName balance! Available: ₹ ${_fmt.format(bal)}';
                                availableBalance = double.parse(bal.toStringAsFixed(2));
                              });
                            }
                            return;
                          }
                        }
                        final t = Transaction(
                          id: existing?.id,
                          societyId: provider.society?.id,
                          date: selectedDate,
                          type: type,
                          amount: amount,
                          description: descCtrl.text.trim(),
                          categoryId: selectedCategory?.id,
                          categoryName: selectedCategory?.name,
                          bankAccountId: selectedBank?.id,
                          toBankAccountId: selectedToBank?.id,
                          wingId: selectedWing?.id,
                          isCommonExpense: isCommonExpense,
                          distributionMode: distributionMode,
                          year: selectedDate.year,
                          month: selectedDate.month,
                        );
                        if (existing == null)
                          await _db.insertTransaction(t);
                        else
                          await _db.updateTransaction(t);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(existing == null ? 'Add Transaction' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypeSegment(TransactionType value, String label, TransactionType selected, Function(TransactionType) onTap) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? primaryBlue : subTextColor),
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
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor),
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
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }
}

class _MonthSummaryBar extends StatelessWidget {
  final int year, month;
  final MonthlySummary? summary;
  final void Function(int, int) onMonthChanged;

  const _MonthSummaryBar({required this.year, required this.month, required this.summary, required this.onMonthChanged});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthNavBtn(
                icon: Icons.chevron_left,
                onTap: () {
                  final m = month == 1 ? 12 : month - 1;
                  final y = month == 1 ? year - 1 : year;
                  onMonthChanged(y, m);
                },
              ),
              InkWell(
                onTap: () => _showMonthPicker(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${_months[month]} $year',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 20, color: subTextColor),
                    ],
                  ),
                ),
              ),
              _MonthNavBtn(
                icon: Icons.chevron_right,
                onTap: () {
                  final m = month == 12 ? 1 : month + 1;
                  final y = month == 12 ? year + 1 : year;
                  onMonthChanged(y, m);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (summary != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  _SummaryItem(label: 'Income', value: summary!.totalIncome, color: const Color(0xFF10B981)),
                  _vDiv(),
                  _SummaryItem(label: 'Expense', value: summary!.totalExpense, color: const Color(0xFFEF4444)),
                  _vDiv(),
                  _SummaryItem(label: 'Net', value: summary!.totalIncome - summary!.totalExpense, color: primaryBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vDiv() => Container(height: 30, width: 1, color: const Color(0xFFE2E8F0));

  void _showMonthPicker(BuildContext context) {
    int y = year, m = month;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Select Period'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: y,
                decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                items: List.generate(10, (i) => DateTime.now().year - 5 + i).map((yr) => DropdownMenuItem(value: yr, child: Text('$yr'))).toList(),
                onChanged: (v) => setSt(() => y = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: m,
                decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                items: List.generate(12, (i) => i + 1).map((mo) => DropdownMenuItem(value: mo, child: Text(_months[mo]))).toList(),
                onChanged: (v) => setSt(() => m = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                onMonthChanged(y, m);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '₹${_fmt.format(value)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        backgroundColor: Colors.white,
        selectedColor: primaryBlue.withAlpha(26),
        checkmarkColor: primaryBlue,
        labelStyle: TextStyle(color: selected ? primaryBlue : const Color(0xFF64748B), fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? primaryBlue : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _TxnList extends StatelessWidget {
  final List<Transaction> transactions;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;
  const _TxnList({required this.transactions, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.withAlpha(77)),
            const SizedBox(height: 12),
            const Text('No transactions found', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final t = transactions[i];
        return _TxnCard(t: t, onEdit: onEdit, onDelete: onDelete);
      },
    );
  }
}

class _TxnCard extends StatelessWidget {
  final Transaction t;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;
  const _TxnCard({required this.t, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    String accountLabel = 'Cash';
    if (t.bankAccountId != null) {
      try {
        accountLabel = provider.bankAccounts.firstWhere((b) => b.id == t.bankAccountId).bankName;
      } catch (_) {
        accountLabel = 'Bank';
      }
    }

    if (t.type == TransactionType.bankToBank && t.toBankAccountId != null) {
      try {
        final toBank = provider.bankAccounts.firstWhere((b) => b.id == t.toBankAccountId).bankName;
        accountLabel = '$accountLabel → $toBank';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => onEdit(t),
        leading: _TxnIcon(type: t.type),
        title: Text(
          t.description.isEmpty ? (t.categoryName ?? 'Transaction') : t.description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${t.categoryName ?? _typeLabel(t.type)} • $accountLabel', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_isNegative(t.type) ? "-" : "+"}₹${_fmt.format(t.amount)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: _typeColor(t.type), fontSize: 15),
            ),
            Text(_dateFmt.format(t.date), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  bool _isNegative(TransactionType t) => t == TransactionType.expense || t == TransactionType.cashToBank || t == TransactionType.bankToCash || t == TransactionType.bankToBank;

  Color _typeColor(TransactionType t) {
    switch (t) {
      case TransactionType.income:
        return const Color(0xFF10B981);
      case TransactionType.expense:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF1565C0);
    }
  }

  String _typeLabel(TransactionType t) {
    switch (t) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.cashToBank:
        return 'Transfer';
      case TransactionType.bankToCash:
        return 'Transfer';
      case TransactionType.bankToBank:
        return 'Bank Transfer';
    }
  }
}

class _TxnIcon extends StatelessWidget {
  final TransactionType type;
  const _TxnIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    Color bg;
    IconData icon;
    Color iconColor;

    switch (type) {
      case TransactionType.income:
        bg = const Color(0xFF10B981).withAlpha(26);
        icon = Icons.arrow_downward;
        iconColor = const Color(0xFF059669);
        break;
      case TransactionType.expense:
        bg = const Color(0xFFEF4444).withAlpha(26);
        icon = Icons.arrow_upward;
        iconColor = const Color(0xFFDC2626);
        break;
      case TransactionType.cashToBank:
      case TransactionType.bankToCash:
      case TransactionType.bankToBank:
        bg = const Color(0xFF1565C0).withAlpha(26);
        icon = Icons.sync_alt;
        iconColor = const Color(0xFF1565C0);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
