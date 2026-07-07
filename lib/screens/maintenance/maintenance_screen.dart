// lib/screens/maintenance/maintenance_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/database_service.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');
const _monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _db = DatabaseService();
  List<MaintenanceMonth> _months = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final m = await _db.getAllMaintenanceMonths(societyId: provider.society?.id);
    setState(() => _months = m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGridView = !_isGridView), tooltip: _isGridView ? 'List View' : 'Grid View'),
          const SizedBox(width: 8),
        ],
      ),
      body: _months.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long, size: 60, color: Color(0xFF1565C0)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No maintenance months added',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Month'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _addMonth,
                  ),
                ],
              ),
            )
          : _isGridView
          ? GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85, crossAxisSpacing: 16, mainAxisSpacing: 16),
              itemCount: _months.length,
              itemBuilder: (_, i) => _MonthCard(
                key: ValueKey(_months[i].id),
                mm: _months[i],
                isGrid: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _MaintenanceDetailScreen(mm: _months[i]))).then((_) => _load()),
                onDelete: () => _deleteMonth(_months[i]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _months.length,
              itemBuilder: (_, i) => _MonthCard(
                key: ValueKey(_months[i].id),
                mm: _months[i],
                isGrid: false,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _MaintenanceDetailScreen(mm: _months[i]))).then((_) => _load()),
                onDelete: () => _deleteMonth(_months[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Month'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: _addMonth,
      ),
    );
  }

  Future<void> _deleteMonth(MaintenanceMonth mm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Maintenance Month?'),
        content: Text('Are you sure you want to delete ${mm.label}? This will permanently remove all payment records for this month.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteMaintenanceMonth(mm.id!);
      _load();
    }
  }

  Future<void> _addMonth() async {
    final provider = context.read<AppProvider>();
    if (provider.allFlats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add wings and flats first')));
      return;
    }

    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    final amtCtrl = TextEditingController(text: provider.society?.defaultMaintenance.toString() ?? '1000');

    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Maintenance Month'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: List.generate(5, (i) => DateTime.now().year - 1 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (v) => setSt(() => selectedYear = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_monthNames[m]))).toList(),
                onChanged: (v) => setSt(() => selectedMonth = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Default Maintenance Amount', prefixText: '₹ '),
              ),
              if (isCreating) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
            ],
          ),
          actions: [
            TextButton(onPressed: isCreating ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      setSt(() => isCreating = true);
                      try {
                        final existing = await _db.getMaintenanceMonth(selectedYear, selectedMonth, societyId: provider.society?.id);
                        if (existing != null) {
                          if (ctx.mounted) {
                            setSt(() => isCreating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This month already exists')));
                            }
                          }
                          return;
                        }

                        final mm = MaintenanceMonth(societyId: provider.society?.id, year: selectedYear, month: selectedMonth, defaultAmount: double.tryParse(amtCtrl.text) ?? 1000);
                        await _db.insertMaintenanceMonth(mm);

                        // Generate flat maintenances for all current flats from DB to ensure freshest occupancy status
                        final flats = await _db.getFlatsBySociety(provider.society!.id!);
                        final Map<int, Flat> uniqueFlats = {for (var f in flats) f.id!: f};

                        final fms = uniqueFlats.values
                            .map(
                              (f) => FlatMaintenance(
                                maintenanceMonthId: mm.id!,
                                flatId: f.id!,
                                flatNumber: f.flatNumber,
                                baseAmount: mm.defaultAmount,
                                status: f.isVacant ? PaymentStatus.exempt : PaymentStatus.pending,
                                wingName: provider.wings.firstWhere((w) => w.id == f.wingId, orElse: () => Wing(societyId: 0, name: '', floors: 0, defaultHousesPerFloor: 0)).name,
                              ),
                            )
                            .toList();
                        await _db.insertFlatMaintenances(fms);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          setSt(() => isCreating = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      }
                    },
              child: Text(isCreating ? 'Creating...' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatefulWidget {
  final MaintenanceMonth mm;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isGrid;

  const _MonthCard({super.key, required this.mm, required this.onTap, required this.onDelete, this.isGrid = false});

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  final _db = DatabaseService();
  int _paid = 0, _pending = 0, _total = 0;
  double _collected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MonthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final fms = await _db.getFlatMaintenances(widget.mm.id!);
    int paid = 0, pending = 0;
    double collected = 0;
    for (final fm in fms) {
      if (fm.status == PaymentStatus.paid) {
        paid++;
        collected += fm.totalAmount;
      } else if (fm.status == PaymentStatus.pending) {
        pending++;
      }
    }
    if (mounted) {
      setState(() {
        _paid = paid;
        _pending = pending;
        _total = fms.length;
        _collected = collected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGrid) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.calendar_month, color: Color(0xFF1565C0), size: 16),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B), size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (v) {
                          if (v == 'delete') widget.onDelete();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'delete',
                            height: 32,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.mm.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹ ${_fmt.format(_collected)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text('$_paid Paid · $_pending Pen.', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(value: _total > 0 ? _paid / _total : 0, backgroundColor: const Color(0xFFF1F5F9), color: const Color(0xFF2E7D32), minHeight: 6),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.calendar_month, color: Color(0xFF1565C0), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.mm.label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Color(0xFF64748B)),
                      onSelected: (v) {
                        if (v == 'delete') widget.onDelete();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatChip('₹ ${_fmt.format(_collected)}', 'Collected', const Color(0xFF2E7D32)),
                    const SizedBox(width: 12),
                    _StatChip('$_paid', 'Paid', const Color(0xFF1565C0)),
                    const SizedBox(width: 12),
                    _StatChip('$_pending', 'Pending', const Color(0xFFF59E0B)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(value: _total > 0 ? _paid / _total : 0, backgroundColor: const Color(0xFFF1F5F9), color: const Color(0xFF2E7D32), minHeight: 8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _StatChip(String value, String label, Color color) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withAlpha(13),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withAlpha(26)),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  ),
);

// ── Detail Screen ───────────────────────────────

class _MaintenanceDetailScreen extends StatefulWidget {
  final MaintenanceMonth mm;

  const _MaintenanceDetailScreen({required this.mm});

  @override
  State<_MaintenanceDetailScreen> createState() => _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<_MaintenanceDetailScreen> {
  final _db = DatabaseService();
  List<FlatMaintenance> _flats = [];
  String _filter = 'all';
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MaintenanceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mm.id != widget.mm.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final f = await _db.getFlatMaintenances(widget.mm.id!);
    setState(() => _flats = f);
  }

  Future<void> _markAllAsPaid() async {
    final pending = _flats.where((f) => f.status == PaymentStatus.pending).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pending payments to mark as paid')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All as Paid?'),
        content: Text('This will mark all ${pending.length} pending flats as paid with today\'s date.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark All Paid')),
        ],
      ),
    );

    if (confirm != true) return;

    final today = DateTime.now();
    for (var f in pending) {
      await _db.updateFlatMaintenance(f.copyWith(status: PaymentStatus.paid, paidDate: today));
    }
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked ${pending.length} flats as paid')));
    }
  }

  List<FlatMaintenance> get _filtered {
    List<FlatMaintenance> list;
    if (_filter == 'all') {
      list = List.from(_flats);
    } else if (_filter == 'paid') {
      list = _flats.where((f) => f.status == PaymentStatus.paid).toList();
    } else if (_filter == 'pending') {
      list = _flats.where((f) => f.status == PaymentStatus.pending).toList();
    } else {
      list = List.from(_flats);
    }

    // Sort by Wing then Flat Number numerically
    list.sort((a, b) {
      if (a.wingName != b.wingName && a.wingName != null && b.wingName != null) {
        return a.wingName!.compareTo(b.wingName!);
      }
      // Try to compare numerically if possible
      final aNum = int.tryParse(a.flatNumber.replaceAll(RegExp(r'\D'), ''));
      final bNum = int.tryParse(b.flatNumber.replaceAll(RegExp(r'\D'), ''));
      if (aNum != null && bNum != null && aNum != bNum) {
        return aNum.compareTo(bNum);
      }
      return a.flatNumber.compareTo(b.flatNumber);
    });
    return list;
  }

  double get _totalCollected => _flats.where((f) => f.status == PaymentStatus.paid).fold(0.0, (s, f) => s + f.totalAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.mm.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGridView = !_isGridView)),
          IconButton(icon: const Icon(Icons.done_all), tooltip: 'Mark All as Paid', onPressed: _markAllAsPaid),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterTab(label: 'All', count: _flats.length, isSelected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                      const SizedBox(width: 6),
                      _FilterTab(
                        label: 'Paid',
                        count: _flats.where((f) => f.status == PaymentStatus.paid).length,
                        isSelected: _filter == 'paid',
                        onTap: () => setState(() => _filter = 'paid'),
                        activeColor: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 6),
                      _FilterTab(
                        label: 'Pending',
                        count: _flats.where((f) => f.status == PaymentStatus.pending).length,
                        isSelected: _filter == 'pending',
                        onTap: () => setState(() => _filter = 'pending'),
                        activeColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(13), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF1565C0)),
                      const SizedBox(width: 6),
                      const Text(
                        'Total Collected: ',
                        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      Text(
                        '₹ ${_fmt.format(_totalCollected)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _FlatMaintenanceTile(fm: _filtered[i], onEdit: () => _editFlatMaintenance(_filtered[i]), isGrid: true),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _FlatMaintenanceTile(fm: _filtered[i], onEdit: () => _editFlatMaintenance(_filtered[i])),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editFlatMaintenance(FlatMaintenance fm) async {
    final provider = context.read<AppProvider>();
    final baseCtrl = TextEditingController(text: fm.baseAmount.toString());
    final remarksCtrl = TextEditingController(text: fm.remarks ?? '');
    PaymentStatus status = fm.status;
    DateTime? paidDate = fm.paidDate;
    BankAccount? selectedBank;

    if (fm.bankAccountId != null) {
      try {
        selectedBank = provider.bankAccounts.firstWhere((b) => b.id == fm.bankAccountId);
      } catch (_) {}
    }

    // Use the new extraDetails getter from the model
    List<ExtraAmount> extras = List.from(fm.extraDetails);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fm.wingName != null ? '${fm.wingName} - ${fm.flatNumber}' : 'Flat ${fm.flatNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: baseCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Base Amount', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                const Text('Extra Charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                ...extras.asMap().entries.map((entry) {
                  int idx = entry.key;
                  ExtraAmount e = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: e.amount == 0 ? '' : e.amount.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'Amount', prefixText: '₹ ', isDense: true),
                            onChanged: (v) => setSt(() => e.amount = double.tryParse(v) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: e.note,
                            decoration: const InputDecoration(hintText: 'Note (e.g. Lift, Penalty)', isDense: true),
                            onChanged: (v) => setSt(() => e.note = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setSt(() => extras.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setSt(() => extras.add(ExtraAmount(amount: 0, note: ''))),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Extra Charge'),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<PaymentStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: PaymentStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                  onChanged: (v) => setSt(() => status = v!),
                ),
                const SizedBox(height: 12),
                if (status == PaymentStatus.paid) ...[
                  DropdownButtonFormField<BankAccount?>(
                    initialValue: selectedBank,
                    decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder(), hintText: 'Cash'),
                    items: [
                      const DropdownMenuItem<BankAccount?>(value: null, child: Text('Cash')),
                      ...provider.bankAccounts.map((b) => DropdownMenuItem(value: b, child: Text(b.bankName))),
                    ],
                    onChanged: (v) => setSt(() => selectedBank = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment Date'),
                    subtitle: Text(paidDate != null ? DateFormat('dd/MM/yyyy').format(paidDate!) : 'Tap to select'),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: paidDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) setSt(() => paidDate = d);
                    },
                  ),
                ],
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'General Remarks', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Filter out empty extras
                      final validExtras = extras.where((e) => e.amount > 0).toList();
                      final totalExtra = validExtras.fold(0.0, (sum, e) => sum + e.amount);
                      final extraNoteJson = validExtras.isEmpty ? null : jsonEncode(validExtras.map((e) => e.toMap()).toList());

                      final updated = fm.copyWith(
                        baseAmount: double.tryParse(baseCtrl.text) ?? fm.baseAmount,
                        extraAmount: totalExtra,
                        extraNote: extraNoteJson,
                        status: status,
                        paidDate: status == PaymentStatus.paid ? paidDate : null,
                        remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                        bankAccountId: status == PaymentStatus.paid ? selectedBank?.id : null,
                      );
                      await _db.updateFlatMaintenance(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _FilterTab({required this.label, required this.count, required this.isSelected, required this.onTap, this.activeColor = const Color(0xFF1565C0)});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: isSelected ? Colors.white.withAlpha(50) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatMaintenanceTile extends StatelessWidget {
  final FlatMaintenance fm;
  final VoidCallback onEdit;
  final bool isGrid;

  const _FlatMaintenanceTile({required this.fm, required this.onEdit, this.isGrid = false});

  Color get _statusColor {
    switch (fm.status) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.partial:
        return Colors.blue;
      case PaymentStatus.exempt:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: _statusColor.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          fm.status.name.toUpperCase(),
                          style: TextStyle(color: _statusColor, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 14, color: const Color(0xFF64748B).withAlpha(150)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    fm.wingName != null ? '${fm.wingName} - ${fm.flatNumber}' : 'Flat ${fm.flatNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹ ${_fmt.format(fm.totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _statusColor.withAlpha(26), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(
              fm.flatNumber,
              style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  fm.wingName != null ? '${fm.wingName} - ${fm.flatNumber}' : 'Flat ${fm.flatNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _statusColor.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  fm.status.name.toUpperCase(),
                  style: TextStyle(color: _statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '₹ ${_fmt.format(fm.totalAmount)}${fm.formattedExtraDetails.isNotEmpty ? ' • ${fm.formattedExtraDetails}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.chevron_right, size: 18, color: const Color(0xFF64748B).withAlpha(100)),
          onTap: onEdit,
        ),
      ),
    );
  }
}
