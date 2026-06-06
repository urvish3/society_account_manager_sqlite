// lib/widgets/society_structure_view.dart
//
// Renders the building layout visually: wings as columns, floors as rows,
// flat tiles color-coded by maintenance payment status.

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';

class SocietyStructureView extends StatefulWidget {
  final int? maintenanceMonthId;
  const SocietyStructureView({super.key, this.maintenanceMonthId});

  @override
  State<SocietyStructureView> createState() => _SocietyStructureViewState();
}

class _SocietyStructureViewState extends State<SocietyStructureView> {
  final _db = DatabaseService();
  List<Wing> _wings = [];
  Map<int, List<Flat>> _wingFlats = {}; // wingId → flats
  Map<String, FlatMaintenance> _maintenanceMap = {}; // flatNumber → status
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SocietyStructureView old) {
    super.didUpdateWidget(old);
    if (old.maintenanceMonthId != widget.maintenanceMonthId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final society = await _db.getSociety();
    if (society == null) {
      setState(() => _loading = false);
      return;
    }
    _wings = await _db.getWings(society.id!);
    _wingFlats = {};
    for (final w in _wings) {
      _wingFlats[w.id!] = await _db.getFlats(w.id!);
    }

    _maintenanceMap = {};
    if (widget.maintenanceMonthId != null) {
      final fms = await _db.getFlatMaintenances(widget.maintenanceMonthId!);
      for (final fm in fms) {
        _maintenanceMap[fm.flatNumber] = fm;
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_wings.isEmpty) {
      return const Center(child: Text('No society structure defined'));
    }

    return Column(
      children: [
        // Legend
        _Legend(),
        const SizedBox(height: 8),
        // Wings as horizontal tabs
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _wings.map((w) => _WingColumn(wing: w, flats: _wingFlats[w.id!] ?? [], maintenanceMap: _maintenanceMap)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WingColumn extends StatelessWidget {
  final Wing wing;
  final List<Flat> flats;
  final Map<String, FlatMaintenance> maintenanceMap;

  const _WingColumn({required this.wing, required this.flats, required this.maintenanceMap});

  @override
  Widget build(BuildContext context) {
    // Group by floor descending
    final Map<int, List<Flat>> byFloor = {};
    for (final f in flats) {
      byFloor.putIfAbsent(f.floor, () => []).add(f);
    }
    final floors = byFloor.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          // Wing header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              'Wing ${wing.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          // Floors
          ...floors.map((floor) => _FloorRow(floor: floor, flats: byFloor[floor]!, maintenanceMap: maintenanceMap)),
        ],
      ),
    );
  }
}

class _FloorRow extends StatelessWidget {
  final int floor;
  final List<Flat> flats;
  final Map<String, FlatMaintenance> maintenanceMap;

  const _FloorRow({required this.floor, required this.flats, required this.maintenanceMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          // Floor label
          Container(
            width: 32,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            child: Text(
              '$floor',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 4),
          // Flat tiles
          ...flats.map((f) => _FlatTile(flat: f, maintenance: maintenanceMap[f.flatNumber])),
        ],
      ),
    );
  }
}

class _FlatTile extends StatelessWidget {
  final Flat flat;
  final FlatMaintenance? maintenance;

  const _FlatTile({required this.flat, this.maintenance});

  Color get _bgColor {
    if (flat.isVacant) return Colors.grey[300]!;
    if (maintenance == null) return Colors.white;
    switch (maintenance!.status) {
      case PaymentStatus.paid:
        return const Color(0xFFE8F5E9);
      case PaymentStatus.pending:
        return const Color(0xFFFFF3E0);
      case PaymentStatus.partial:
        return const Color(0xFFE3F2FD);
      case PaymentStatus.exempt:
        return Colors.grey[200]!;
    }
  }

  Color get _borderColor {
    if (flat.isVacant) return Colors.grey;
    if (maintenance == null) return Colors.grey[300]!;
    switch (maintenance!.status) {
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
    return GestureDetector(
      onTap: () => _showInfo(context),
      child: Container(
        width: 52,
        height: 48,
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: _bgColor,
          border: Border.all(color: _borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flat.flatNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            if (maintenance?.status == PaymentStatus.paid) const Icon(Icons.check, size: 12, color: Colors.green),
            if (maintenance?.status == PaymentStatus.pending) const Icon(Icons.hourglass_empty, size: 12, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Flat ${flat.flatNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner: ${flat.ownerName ?? "Unknown"}'),
            if (flat.ownerPhone != null) Text('Phone: ${flat.ownerPhone}'),
            if (flat.isVacant) const Text('Status: Vacant'),
            if (maintenance != null) ...[
              const Divider(),
              Text('Maintenance: ₹${maintenance!.totalAmount}'),
              Text('Status: ${maintenance!.status.name.toUpperCase()}'),
              if (maintenance!.extraNote != null) Text('Note: ${maintenance!.extraNote}'),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 12,
        children: const [
          _LegendItem(color: Color(0xFFE8F5E9), border: Colors.green, label: 'Paid'),
          _LegendItem(color: Color(0xFFFFF3E0), border: Colors.orange, label: 'Pending'),
          _LegendItem(color: Color(0xFFE3F2FD), border: Colors.blue, label: 'Partial'),
          _LegendItem(color: Colors.white, border: Color(0xFFBBBBBB), label: 'No data'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color, border;
  final String label;
  const _LegendItem({required this.color, required this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
