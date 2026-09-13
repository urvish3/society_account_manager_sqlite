// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import 'bank/bank_accounts_screen.dart';
import 'maintenance/maintenance_screen.dart';
import 'reports/report_screen.dart';
import 'setup/society_setup_screen.dart';
import 'transactions/transactions_screen.dart';

final _fmt = NumberFormat('#,##0', 'en_IN');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Society> _allSocieties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  Future<void> _loadSocieties() async {
    setState(() => _isLoading = true);
    final db = DatabaseService();
    final societies = await db.getSocieties();
    if (mounted) {
      setState(() {
        _allSocieties = societies;
        _isLoading = false;
      });
    }
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.settings_outlined, color: Color(0xFF1565C0), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Settings & Database Backup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Manage complete database backups and restore.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.backup_outlined, color: Color(0xFF1565C0)),
              ),
              title: const Text(
                'Backup Database',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              subtitle: const Text('Export & share complete database backup file', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () async {
                Navigator.pop(ctx);
                await DatabaseService().exportDatabase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database backup export initiated!')));
                }
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.restore_outlined, color: Color(0xFFEF4444)),
              ),
              title: const Text(
                'Import Database',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
              ),
              subtitle: const Text('Replace current database completely with a backup file', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Replace Database?'),
                    content: const Text(
                      'Warning: Importing a database will completely replace your current database and all data with the selected backup file. This action cannot be undone.\n\nAre you sure you want to continue?',
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Replace & Import'),
                      ),
                    ],
                  ),
                );

                if (ok == true && mounted) {
                  try {
                    final success = await DatabaseService().importDatabase();
                    if (success && mounted) {
                      await _loadSocieties();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database imported and replaced successfully!')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import database: $e')));
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Societies',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF64748B).withAlpha(26), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.settings_outlined, size: 24, color: Color(0xFF64748B)),
            ),
            tooltip: 'Settings & Backup',
            onPressed: () => _showSettingsModal(context),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.add, size: 24, color: Color(0xFF1565C0)),
              ),
              tooltip: 'Add New Society',
              onPressed: () {
                context.read<AppProvider>().resetForNewSociety();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SocietySetupScreen(isFirst: true))).then((_) => _loadSocieties());
              },
            ),
          ),
        ],
      ),
      body: _allSocieties.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadSocieties,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: _allSocieties.length,
                itemBuilder: (ctx, idx) {
                  final s = _allSocieties[idx];
                  return _SocietyListCard(
                    society: s,
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      await provider.setSociety(s);
                      if (mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SocietyDashboard(society: s)));
                      }
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(20), borderRadius: BorderRadius.circular(32)),
              child: const Icon(Icons.apartment_rounded, size: 64, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 32),
            const Text('No Societies Added', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text(
              'Manage your society maintenance, transactions, and reports with ease.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.blueGrey[600], height: 1.5),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                context.read<AppProvider>().resetForNewSociety();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SocietySetupScreen(isFirst: true))).then((_) => _loadSocieties());
              },
              child: const Text('Add Your First Society'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietyListCard extends StatelessWidget {
  final Society society;
  final VoidCallback onTap;

  const _SocietyListCard({required this.society, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withAlpha(10), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: const Color(0xFF1565C0).withAlpha(20), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.apartment_rounded, color: Color(0xFF1565C0), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      society.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            society.address,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 24, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Society Dashboard (The Screen shown after tapping a society) ────────────────

class SocietyDashboard extends StatefulWidget {
  final Society society;
  const SocietyDashboard({super.key, required this.society});

  @override
  State<SocietyDashboard> createState() => _SocietyDashboardState();
}

class _SocietyDashboardState extends State<SocietyDashboard> {
  int _refreshKey = 0;

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.society.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SocietySetupScreen(isFirst: false, society: widget.society))).then((_) => provider.init()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            Row(
              children: [
                _StatTile(label: 'Total Wings', value: '${provider.wings.length}', icon: Icons.layers_outlined, color: const Color(0xFF6366F1)),
                const SizedBox(width: 12),
                _StatTile(label: 'Total Flats', value: '${provider.allFlats.length}', icon: Icons.meeting_room_outlined, color: const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 24),

            // Balance Cards
            const Text(
              'Current Balance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            _BalanceCards(key: ValueKey(_refreshKey), year: now.year, month: now.month),
            const SizedBox(height: 28),

            // Module Grid
            const Text(
              'Management Hub',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: [
                _ModuleTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Maintenance',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MaintenanceScreen())).then((_) => _refresh()),
                ),
                _ModuleTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transactions',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())).then((_) => _refresh()),
                ),
                _ModuleTile(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank Accounts',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())).then((_) {
                    provider.init();
                    _refresh();
                  }),
                ),
                _ModuleTile(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  color: const Color(0xFF06B6D4),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())).then((_) => _refresh()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LargeModuleTile(
              icon: Icons.people_alt_rounded,
              label: 'Residents & Occupancy',
              subtitle: 'Manage owner details and vacancy',
              color: const Color(0xFF1565C0),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResidentsScreen())).then((_) {
                provider.refreshFlats();
                _refresh();
              }),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance Cards Widget ────────────────────────

class _BalanceCards extends StatefulWidget {
  final int year, month;
  const _BalanceCards({super.key, required this.year, required this.month});

  @override
  State<_BalanceCards> createState() => _BalanceCardsState();
}

class _BalanceCardsState extends State<_BalanceCards> {
  MonthlySummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    if (provider.society == null) return;
    final db = DatabaseService();
    final s = await db.computeMonthlySummary(widget.year, widget.month, societyId: provider.society!.id);
    if (mounted) setState(() => _summary = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null) {
      return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
    }
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(label: 'Cash In Hand', amount: _summary!.closingCashBalance, icon: Icons.wallet_rounded, color: const Color(0xFF2E7D32), bgColor: const Color(0xFFE8F5E9)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceCard(label: 'Bank Balance', amount: _summary!.closingBankBalance, icon: Icons.account_balance_rounded, color: const Color(0xFF1565C0), bgColor: const Color(0xFFE3F2FD)),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _BalanceCard({required this.label, required this.amount, required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹ ${_fmt.format(amount)}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Module Tile ─────────────────────────────────

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LargeModuleTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Residents Screen ────────────────────────────

class ResidentsScreen extends StatefulWidget {
  const ResidentsScreen({super.key});

  @override
  State<ResidentsScreen> createState() => _ResidentsScreenState();
}

class _ResidentsScreenState extends State<ResidentsScreen> {
  final _db = DatabaseService();
  List<Flat> _flats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    if (provider.society == null) return;
    final f = await _db.getFlatsBySociety(provider.society!.id!);
    setState(() => _flats = f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Residents Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: _flats.isEmpty
          ? const Center(child: Text('No residents found'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _flats.length,
              itemBuilder: (_, i) {
                final flat = _flats[i];
                final bool isVacant = flat.isVacant;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: isVacant ? const Color(0xFFF1F5F9) : const Color(0xFF1565C0).withAlpha(26), borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: Text(
                        flat.flatNumber,
                        style: TextStyle(color: isVacant ? const Color(0xFF94A3B8) : const Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    title: Text(
                      isVacant ? 'Vacant ${flat.unitType}' : (flat.ownerName ?? 'Unknown Owner'),
                      style: TextStyle(fontWeight: FontWeight.bold, color: isVacant ? const Color(0xFF94A3B8) : const Color(0xFF1E293B), fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${flat.unitType} • Floor ${flat.floor} • ${flat.ownerPhone ?? "No Phone"}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => _editFlat(flat),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editFlat(Flat flat) async {
    final nameCtrl = TextEditingController(text: flat.ownerName);
    final phoneCtrl = TextEditingController(text: flat.ownerPhone);
    final numberCtrl = TextEditingController(text: flat.flatNumber);
    String unitType = flat.unitType;
    bool vacant = flat.isVacant;

    final List<String> unitTypes = ['Flat', 'Bunglow', 'Shop', 'Office', 'Other'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Edit ${flat.unitType} ${flat.flatNumber}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberCtrl,
                  decoration: const InputDecoration(labelText: 'Unit Number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unitTypes.contains(unitType) ? unitType : 'Other',
                  decoration: const InputDecoration(labelText: 'Unit Type'),
                  items: unitTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setSt(() => unitType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(title: const Text('Vacant'), value: vacant, onChanged: (v) => setSt(() => vacant = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final updated = Flat(
                  id: flat.id,
                  wingId: flat.wingId,
                  flatNumber: numberCtrl.text.trim(),
                  floor: flat.floor,
                  ownerName: nameCtrl.text.trim(),
                  ownerPhone: phoneCtrl.text.trim(),
                  isVacant: vacant,
                  unitType: unitType,
                );
                await _db.updateFlat(updated);
                if (ctx.mounted) {
                  context.read<AppProvider>().refreshFlats();
                  Navigator.pop(ctx);
                }
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
