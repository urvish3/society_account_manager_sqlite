// lib/screens/maintenance/maintenance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/database_service.dart';

final _fmt = NumberFormat('#,##0.00', 'en_IN');
const _monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final wings = provider.wings;
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Maintenance (Wings)',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
      ),
      body: wings.isEmpty
          ? const Center(
              child: Text('Please add wings and flats first in Society Setup.', style: TextStyle(color: subTextColor)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: wings.length,
              itemBuilder: (_, i) {
                final wing = wings[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(color: primaryBlue.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Text(
                        wing.name[0].toUpperCase(),
                        style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    title: Text(
                      'Wing / Block: ${wing.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${wing.floors} floors • ${wing.defaultHousesPerFloor} units/floor • Share: ${wing.allocationPercentage}%',
                        style: const TextStyle(color: subTextColor, fontSize: 13),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _WingMaintenanceMonthsScreen(wing: wing)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _WingMaintenanceMonthsScreen extends StatefulWidget {
  final Wing wing;
  const _WingMaintenanceMonthsScreen({required this.wing});

  @override
  State<_WingMaintenanceMonthsScreen> createState() => _WingMaintenanceMonthsScreenState();
}

class _WingMaintenanceMonthsScreenState extends State<_WingMaintenanceMonthsScreen> {
  final _db = DatabaseService();
  List<MaintenanceMonth> _months = [];
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final allMms = await _db.getAllMaintenanceMonths(societyId: widget.wing.societyId);
    final wingMms = allMms.where((mm) => mm.wingId == widget.wing.id || mm.wingId == null || mm.wingId == 0).toList();
    setState(() => _months = wingMms);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Maintenance — ${widget.wing.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        actions: [
          IconButton(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGridView = !_isGridView)),
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
                    decoration: BoxDecoration(color: primaryBlue.withAlpha(26), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long, size: 60, color: primaryBlue),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No maintenance months added for this wing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Month'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _addMonthForWing(context, widget.wing),
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
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () => _addMonthForWing(context, widget.wing),
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

  Future<void> _addMonthForWing(BuildContext context, Wing wing) async {
    final provider = context.read<AppProvider>();
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    final amtCtrl = TextEditingController(text: provider.society?.defaultMaintenance.toString() ?? '1000');
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Add Maintenance — ${wing.name}'),
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
                        final existing = await _db.getMaintenanceMonth(selectedYear, selectedMonth, societyId: provider.society?.id, wingId: wing.id);
                        if (existing != null) {
                          if (ctx.mounted) {
                            setSt(() => isCreating = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This month already exists for this wing')));
                            }
                          }
                          return;
                        }

                        final mm = MaintenanceMonth(
                          societyId: provider.society?.id,
                          wingId: wing.id,
                          year: selectedYear,
                          month: selectedMonth,
                          defaultAmount: double.tryParse(amtCtrl.text) ?? 1000,
                        );
                        await _db.insertMaintenanceMonth(mm);

                        final flats = await _db.getFlats(wing.id!);
                        final fms = flats
                            .map(
                              (f) => FlatMaintenance(
                                maintenanceMonthId: mm.id!,
                                flatId: f.id!,
                                flatNumber: f.flatNumber,
                                baseAmount: mm.defaultAmount,
                                status: f.isVacant ? PaymentStatus.exempt : PaymentStatus.pending,
                                wingName: wing.name,
                              ),
                            )
                            .toList();
                        await _db.insertFlatMaintenances(fms);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e, st) {
                        debugPrint('Maintenance creation error: $e\n$st');
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
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No maintenance records found', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : _isGridView
                ? GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 16, mainAxisSpacing: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _FlatCard(
                      key: ValueKey(_filtered[i].id),
                      fm: _filtered[i],
                      isGrid: true,
                      onUpdate: _load,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _FlatCard(
                      key: ValueKey(_filtered[i].id),
                      fm: _filtered[i],
                      isGrid: false,
                      onUpdate: _load,
                    ),
                  ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withAlpha(50) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatCard extends StatefulWidget {
  final FlatMaintenance fm;
  final bool isGrid;
  final VoidCallback onUpdate;

  const _FlatCard({super.key, required this.fm, required this.isGrid, required this.onUpdate});

  @override
  State<_FlatCard> createState() => _FlatCardState();
}

class _FlatCardState extends State<_FlatCard> {
  final _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final fm = widget.fm;
    final isPaid = fm.status == PaymentStatus.paid;
    final isExempt = fm.status == PaymentStatus.exempt;
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPaid ? const Color(0xFFBBF7D0) : (isExempt ? const Color(0xFFE2E8F0) : const Color(0xFFFEF08A)), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showEditDialog(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fm.wingName != null ? '${fm.wingName} - ${fm.flatNumber}' : fm.flatNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFDCFCE7) : (isExempt ? const Color(0xFFF1F5F9) : const Color(0xFFFEF9C3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : (isExempt ? 'Exempt' : 'Pending'),
                        style: TextStyle(color: isPaid ? const Color(0xFF166534) : (isExempt ? subTextColor : const Color(0xFF854D0E)), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Amount', style: TextStyle(color: subTextColor, fontSize: 12)),
                    Text(
                      '₹ ${_fmt.format(fm.baseAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                    ),
                  ],
                ),
                if (fm.extraAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fm.formattedExtraDetails.isNotEmpty ? fm.formattedExtraDetails : 'Extra', style: const TextStyle(color: subTextColor, fontSize: 12)),
                      Text(
                        '+ ₹ ${_fmt.format(fm.extraAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                    ),
                    Text(
                      '₹ ${_fmt.format(fm.totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    PaymentStatus status = widget.fm.status;
    final extraCtrl = TextEditingController(text: widget.fm.extraAmount > 0 ? widget.fm.extraAmount.toString() : '');
    final noteCtrl = TextEditingController(text: widget.fm.extraNote ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Flat ${widget.fm.flatNumber} (${widget.fm.wingName ?? ""})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PaymentStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: PaymentStatus.pending, child: Text('Pending')),
                  DropdownMenuItem(value: PaymentStatus.paid, child: Text('Paid')),
                  DropdownMenuItem(value: PaymentStatus.exempt, child: Text('Exempt')),
                ],
                onChanged: (v) => setSt(() => status = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extraCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extra Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Extra Note / Remarks'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final extra = double.tryParse(extraCtrl.text) ?? 0;
                final updated = widget.fm.copyWith(
                  status: status,
                  extraAmount: extra,
                  extraNote: noteCtrl.text.trim(),
                  paidDate: status == PaymentStatus.paid ? (widget.fm.paidDate ?? DateTime.now()) : null,
                );
                await _db.updateFlatMaintenance(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onUpdate();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
