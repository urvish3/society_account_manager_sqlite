// lib/screens/setup/society_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/database_service.dart';
import '../home_screen.dart';

class SocietySetupScreen extends StatefulWidget {
  final bool isFirst;
  final Society? society;
  const SocietySetupScreen({super.key, required this.isFirst, this.society});

  @override
  State<SocietySetupScreen> createState() => _SocietySetupScreenState();
}

class _SocietySetupScreenState extends State<SocietySetupScreen> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _maintCtrl = TextEditingController(text: '1000');
  final _openingCashCtrl = TextEditingController(text: '0');
  bool _isSavingBasic = false;

  static const primaryBlue = Color(0xFF1565C0);
  static const bgBlue = Color(0xFFF8FAFC);
  static const textColor = Color(0xFF1E293B);
  static const subTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (widget.society != null) {
      _nameCtrl.text = widget.society!.name;
      _addrCtrl.text = widget.society!.address;
      _maintCtrl.text = widget.society!.defaultMaintenance.toString();
      _openingCashCtrl.text = widget.society!.openingCashBalance.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final society = provider.society;

    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: Text(
          widget.isFirst ? 'Setup Society' : 'Society Settings',
          style: const TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        automaticallyImplyLeading: !widget.isFirst,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Basic Information', Icons.info_outline),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Society Name'),
                  TextField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration('e.g. Gokuldham Society'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  _buildFieldLabel('Address'),
                  TextField(
                    controller: _addrCtrl,
                    maxLines: 2,
                    decoration: _inputDecoration('Full address of the society'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Monthly Maint.'),
                            TextField(
                              controller: _maintCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('1000').copyWith(prefixText: '₹ '),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Opening Cash'),
                            TextField(
                              controller: _openingCashCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('0').copyWith(prefixText: '₹ '),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSavingBasic ? null : _saveBasicInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSavingBasic
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(society == null ? 'Save Society Info' : 'Update Info', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('2. Structure Setup', Icons.domain),
            if (society == null)
              _buildEmptyPlaceholder('Please save basic information first to add structures.')
            else ...[
              if (provider.wings.isEmpty)
                _buildEmptyPlaceholder(
                  'No structures added yet. Add at least one to complete the setup.',
                  icon: Icons.domain_add,
                  action: ElevatedButton.icon(
                    onPressed: () => _showAddWing(context, society),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add First Structure'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                )
              else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.wings.length,
                  itemBuilder: (_, i) {
                    final wing = provider.wings[i];
                    return _WingCard(
                      wing: wing,
                      onEdit: () => _showAddWing(context, society, wing: wing),
                      onDelete: () => _deleteWing(context, wing),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 20, color: primaryBlue),
                    label: const Text(
                      'Add Another Structure',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                    onPressed: () => _showAddWing(context, society),
                  ),
                ),
              ],
            ],
            // const SizedBox(height: 32),
            // _buildSectionTitle('3. Database Backup & Restore', Icons.storage),
            // Container(
            //   padding: const EdgeInsets.all(20),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     borderRadius: BorderRadius.circular(20),
            //     boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       const Text(
            //         'Backup your current database completely and save/share it, or import a backup file to replace your database completely.',
            //         style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4),
            //       ),
            //       const SizedBox(height: 16),
            //       Row(
            //         children: [
            //           Expanded(
            //             child: OutlinedButton.icon(
            //               onPressed: () async {
            //                 await DatabaseService().exportDatabase();
            //                 if (context.mounted) {
            //                   ScaffoldMessenger.of(context).showSnackBar(
            //                     const SnackBar(content: Text('Database backup export initiated!')),
            //                   );
            //                 }
            //               },
            //               icon: const Icon(Icons.backup_outlined, size: 18),
            //               label: const Text('Backup DB'),
            //               style: OutlinedButton.styleFrom(
            //                 foregroundColor: primaryBlue,
            //                 side: const BorderSide(color: primaryBlue),
            //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //                 padding: const EdgeInsets.symmetric(vertical: 12),
            //               ),
            //             ),
            //           ),
            //           const SizedBox(width: 12),
            //           Expanded(
            //             child: ElevatedButton.icon(
            //               onPressed: () => _importDatabase(context, provider),
            //               icon: const Icon(Icons.restore_outlined, size: 18),
            //               label: const Text('Import DB'),
            //               style: ElevatedButton.styleFrom(
            //                 backgroundColor: const Color(0xFFEF4444),
            //                 foregroundColor: Colors.white,
            //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //                 elevation: 0,
            //                 padding: const EdgeInsets.symmetric(vertical: 12),
            //               ),
            //             ),
            //           ),
            //         ],
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 48),
            if (society != null && provider.wings.isNotEmpty)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF10B981).withAlpha(51), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    provider.finishSetup();
                    if (widget.isFirst) {
                      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('FINISH & GO TO DASHBOARD', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryBlue.withAlpha(26), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 18, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
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
      fillColor: bgBlue.withAlpha(128),
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

  Widget _buildEmptyPlaceholder(String message, {IconData? icon, Widget? action}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          if (icon != null) ...[Icon(icon, size: 48, color: const Color(0xFFCBD5E1)), const SizedBox(height: 16)],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action],
        ],
      ),
    );
  }

  Future<void> _importDatabase(BuildContext context, AppProvider provider) async {
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

    if (ok == true && context.mounted) {
      try {
        final success = await DatabaseService().importDatabase();
        if (success && context.mounted) {
          await provider.init();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database imported and replaced successfully!')));
          if (widget.isFirst) {
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
          } else {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import database: $e')));
        }
      }
    }
  }

  Future<void> _saveBasicInfo() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Society name is required')));
      return;
    }
    setState(() => _isSavingBasic = true);
    final provider = context.read<AppProvider>();
    final s = Society(
      id: provider.society?.id,
      name: _nameCtrl.text.trim(),
      address: _addrCtrl.text.trim(),
      defaultMaintenance: double.tryParse(_maintCtrl.text) ?? 1000,
      openingCashBalance: double.tryParse(_openingCashCtrl.text) ?? 0,
    );
    await provider.saveSociety(s);
    setState(() => _isSavingBasic = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Society info saved! Now add structures.')));
    }
  }

  Future<void> _showAddWing(BuildContext context, Society society, {Wing? wing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWingSheet(society: society, wing: wing),
    );
    if (context.mounted) context.read<AppProvider>().init();
  }

  Future<void> _deleteWing(BuildContext context, Wing wing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Structure?'),
        content: Text('This will also delete all units in ${wing.name}'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().deleteWing(wing.id!);
    }
  }
}

class _WingCard extends StatelessWidget {
  final Wing wing;
  final VoidCallback onEdit, onDelete;
  const _WingCard({required this.wing, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);
    const textColor = Color(0xFF1E293B);
    const subTextColor = Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: primaryBlue.withAlpha(26), borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(
            wing.name[0].toUpperCase(),
            style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        title: Text(
          wing.structureType.contains('Bunglow') || wing.structureType.contains('Raw House') ? '${wing.name}' : 'Wing ${wing.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wing.structureType,
              style: const TextStyle(fontSize: 12, color: primaryBlue, fontWeight: FontWeight.w500),
            ),
            Text('${wing.floors} floors  •  ${wing.defaultHousesPerFloor} units/floor', style: const TextStyle(fontSize: 13, color: subTextColor)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: subTextColor),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWingSheet extends StatefulWidget {
  final Society society;
  final Wing? wing;
  const _AddWingSheet({required this.society, this.wing});

  @override
  State<_AddWingSheet> createState() => _AddWingSheetState();
}

class _AddWingSheetState extends State<_AddWingSheet> {
  final _nameCtrl = TextEditingController();
  final _floorsCtrl = TextEditingController(text: '1');
  final _hpfCtrl = TextEditingController(text: '4');
  String _structureType = 'Residential Apartment';
  bool _isSaving = false;

  // For Raw House / Bungalows / Single Floor Shops
  List<BlockConfig> _blocks = [BlockConfig()];

  // For Multi-floor (Fixed vs Different counts)
  bool _isDifferentCounts = false;
  List<FloorUnitRange> _floorRanges = [];

  // For Mixed (Residential + Shops, Commercial + Shops)
  final _shopFloorCountCtrl = TextEditingController(text: '1');
  final _upperFloorCountCtrl = TextEditingController(text: '5');
  List<FloorUnitRange> _mixedFloorRanges = [];

  final List<String> _structureTypes = [
    'Residential Apartment',
    'Raw House / Bunglows',
    'Residential + Shops',
    'Commercial Complex',
    'Commercial + Shops',
    'Shops (Multi-floor)',
    'Shops (Single floor)',
    'Other',
  ];

  static const primaryBlue = Color(0xFF1565C0);
  static const textColor = Color(0xFF1E293B);
  static const subTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (widget.wing != null) {
      _nameCtrl.text = widget.wing!.name;
      _floorsCtrl.text = widget.wing!.floors.toString();
      _hpfCtrl.text = widget.wing!.defaultHousesPerFloor.toString();
      _structureType = widget.wing!.structureType;
      // Note: Legacy data might not perfectly map to new complex modes,
      // but we'll default to the standard view for editing.
    }
  }

  void _updateFloorRanges() {
    final floors = int.tryParse(_floorsCtrl.text) ?? 0;
    setState(() {
      if (_floorRanges.length < floors) {
        for (int i = _floorRanges.length; i < floors; i++) {
          _floorRanges.add(FloorUnitRange(floor: i + 1, start: 1, end: 4));
        }
      } else if (_floorRanges.length > floors) {
        _floorRanges = _floorRanges.sublist(0, floors);
      }
    });
  }

  void _updateMixedFloorRanges() {
    final shopFloors = int.tryParse(_shopFloorCountCtrl.text) ?? 0;
    final upperFloors = int.tryParse(_upperFloorCountCtrl.text) ?? 0;

    setState(() {
      _mixedFloorRanges.clear();
      String upperType = _structureType.contains('Residential') ? 'Flat' : 'Office';

      // Shops start from Ground (0)
      for (int i = 0; i < shopFloors; i++) {
        _mixedFloorRanges.add(FloorUnitRange(floor: i, start: 1, end: 4, type: 'Shop'));
      }
      // Upper floors start after shops
      for (int i = 0; i < upperFloors; i++) {
        _mixedFloorRanges.add(FloorUnitRange(floor: shopFloors + i, start: 1, end: 4, type: upperType));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSimple = _structureType == 'Raw House / Bunglows' || _structureType == 'Shops (Single floor)';
    bool isMulti = _structureType == 'Residential Apartment' || _structureType == 'Commercial Complex' || _structureType == 'Shops (Multi-floor)' || _structureType == 'Other';
    bool isMixed = _structureType == 'Residential + Shops' || _structureType == 'Commercial + Shops';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.wing == null ? 'Add Structure' : 'Edit Structure',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: subTextColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFieldLabel('Structure Type'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _structureType,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: _structureTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _structureType = val;
                      if (val.contains('+ Shops')) {
                        _updateMixedFloorRanges();
                      } else if (_isDifferentCounts) {
                        _updateFloorRanges();
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildFieldLabel(isSimple ? 'Area / Phase Name' : 'Wing / Block Name'),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDecoration('e.g. Wing A, Phase 1'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),

            if (isSimple) ..._buildSimpleLayout(),
            if (isMulti) ..._buildMultiLayout(),
            if (isMixed) ..._buildMixedLayout(),

            if (_isSaving) ...[const SizedBox(height: 24), const Center(child: CircularProgressIndicator(color: primaryBlue))],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(widget.wing == null ? 'Add Structure' : 'Update Structure', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSimpleLayout() {
    return [
      Row(
        children: [
          Expanded(child: _buildFieldLabel('Blocks / Rows')),
          TextButton.icon(onPressed: () => setState(() => _blocks.add(BlockConfig())), icon: const Icon(Icons.add, size: 16), label: const Text('Add Block')),
        ],
      ),
      ..._blocks.asMap().entries.map((entry) {
        int i = entry.key;
        BlockConfig b = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(controller: b.prefix, decoration: _inputDecoration('Prefix'), style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(controller: b.start, keyboardType: TextInputType.number, decoration: _inputDecoration('Start'), style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(controller: b.end, keyboardType: TextInputType.number, decoration: _inputDecoration('End'), style: const TextStyle(fontSize: 14)),
              ),
              if (_blocks.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => setState(() => _blocks.removeAt(i)),
                ),
            ],
          ),
        );
      }),
    ];
  }

  List<Widget> _buildMultiLayout() {
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('No. of Floors'),
                TextField(
                  controller: _floorsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('1'),
                  onChanged: (_) {
                    if (_isDifferentCounts) _updateFloorRanges();
                  },
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (!_isDifferentCounts)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Units per Floor'),
                  TextField(
                    controller: _hpfCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('4'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Different counts per floor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        value: _isDifferentCounts,
        onChanged: (val) {
          setState(() => _isDifferentCounts = val);
          if (val) _updateFloorRanges();
        },
      ),
      if (_isDifferentCounts) ...[const SizedBox(height: 8), _buildFloorRangesList(_floorRanges)],
    ];
  }

  List<Widget> _buildMixedLayout() {
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Shop Floors'),
                TextField(
                  controller: _shopFloorCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('1'),
                  onChanged: (_) => _updateMixedFloorRanges(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel(_structureType.contains('Residential') ? 'Resi. Floors' : 'Comm. Floors'),
                TextField(
                  controller: _upperFloorCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('5'),
                  onChanged: (_) => _updateMixedFloorRanges(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildFloorRangesList(_mixedFloorRanges, showType: true),
    ];
  }

  Widget _buildFloorRangesList(List<FloorUnitRange> ranges, {bool showType = false}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: ranges.length,
        itemBuilder: (ctx, i) {
          final r = ranges[i];
          // Floor selection logic:
          // For mixed, shops start from 0 (Ground), then upper floors start from shopCount.
          // We'll allow selecting floor number but default it.
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: r.floor,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                      items: List.generate(100, (index) => index).map((f) => DropdownMenuItem(value: f, child: Text(f == 0 ? 'G' : '$f'))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => ranges[i] = r.copyWith(floor: val));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: r.startCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Start').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: r.endCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('End').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (showType) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(color: r.type == 'Shop' ? Colors.orange.shade100 : Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      r.type,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: r.type == 'Shop' ? Colors.orange.shade800 : Colors.blue.shade800),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
      fillColor: const Color(0xFFF8FAFC),
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      int floors = 1;
      int hpf = 1;

      if (_structureType == 'Raw House / Bunglows' || _structureType == 'Shops (Single floor)') {
        floors = 1;
      } else if (_structureType == 'Residential + Shops' || _structureType == 'Commercial + Shops') {
        floors = (int.tryParse(_shopFloorCountCtrl.text) ?? 0) + (int.tryParse(_upperFloorCountCtrl.text) ?? 0);
      } else {
        floors = int.tryParse(_floorsCtrl.text) ?? 1;
        hpf = int.tryParse(_hpfCtrl.text) ?? 4;
      }

      final wing = Wing(id: widget.wing?.id, societyId: widget.society.id!, name: _nameCtrl.text.trim(), floors: floors, defaultHousesPerFloor: hpf, structureType: _structureType);

      if (wing.id == null) {
        final wingId = await db.insertWing(wing);
        final List<Flat> flats = [];

        if (_structureType == 'Raw House / Bunglows' || _structureType == 'Shops (Single floor)') {
          String unitType = _structureType == 'Raw House / Bunglows' ? 'Bunglow' : 'Shop';
          for (var b in _blocks) {
            int start = int.tryParse(b.start.text) ?? 1;
            int end = int.tryParse(b.end.text) ?? 1;
            String prefix = b.prefix.text.trim();
            for (int i = start; i <= end; i++) {
              flats.add(Flat(wingId: wingId, flatNumber: prefix.isEmpty ? '$i' : '$prefix-$i', floor: 1, unitType: unitType));
            }
          }
        } else if (_structureType == 'Residential + Shops' || _structureType == 'Commercial + Shops') {
          for (var r in _mixedFloorRanges) {
            int start = int.tryParse(r.startCtrl.text) ?? 1;
            int end = int.tryParse(r.endCtrl.text) ?? 1;
            for (int i = start; i <= end; i++) {
              String flatNumber = r.type == 'Shop' ? 'S-${r.floor}$i' : (r.type == 'Office' ? 'C-${r.floor}$i' : '${r.floor}${i.toString().padLeft(2, '0')}');
              flats.add(Flat(wingId: wingId, flatNumber: flatNumber, floor: r.floor, unitType: r.type));
            }
          }
        } else if (_isDifferentCounts) {
          String unitType = _structureType.contains('Shop') ? 'Shop' : (_structureType.contains('Commercial') ? 'Office' : 'Flat');
          for (var r in _floorRanges) {
            int start = int.tryParse(r.startCtrl.text) ?? 1;
            int end = int.tryParse(r.endCtrl.text) ?? 1;
            for (int i = start; i <= end; i++) {
              String flatNumber = unitType == 'Shop' ? 'S-${r.floor}$i' : (unitType == 'Office' ? 'C-${r.floor}$i' : '${r.floor}${i.toString().padLeft(2, '0')}');
              flats.add(Flat(wingId: wingId, flatNumber: flatNumber, floor: r.floor, unitType: unitType));
            }
          }
        } else {
          // Fixed count (Original logic)
          for (int floor = 1; floor <= floors; floor++) {
            for (int h = 1; h <= hpf; h++) {
              String flatNumber;
              String unitType = 'Flat';
              if (_structureType.contains('Shop')) {
                flatNumber = 'S-$floor${h.toString().padLeft(2, '0')}';
                unitType = 'Shop';
              } else if (_structureType.contains('Commercial')) {
                flatNumber = 'C-$floor${h.toString().padLeft(2, '0')}';
                unitType = 'Office';
              } else {
                flatNumber = '$floor${h.toString().padLeft(2, '0')}';
                unitType = 'Flat';
              }
              flats.add(Flat(wingId: wingId, flatNumber: flatNumber, floor: floor, unitType: unitType));
            }
          }
        }
        await db.insertFlats(flats);
      } else {
        await db.updateWing(wing);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class BlockConfig {
  final prefix = TextEditingController();
  final start = TextEditingController(text: '1');
  final end = TextEditingController(text: '10');
}

class FloorUnitRange {
  final int floor;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;
  final String type;

  FloorUnitRange({required this.floor, int start = 1, int end = 4, this.type = 'Flat', TextEditingController? startCtrl, TextEditingController? endCtrl})
    : startCtrl = startCtrl ?? TextEditingController(text: start.toString()),
      endCtrl = endCtrl ?? TextEditingController(text: end.toString());

  FloorUnitRange copyWith({int? floor, String? type}) {
    return FloorUnitRange(floor: floor ?? this.floor, type: type ?? this.type, startCtrl: startCtrl, endCtrl: endCtrl);
  }
}
