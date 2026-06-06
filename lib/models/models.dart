// lib/models/models.dart
import 'dart:convert';

class Society {
  int? id;
  String name;
  String address;
  double defaultMaintenance;
  double openingCashBalance;

  Society({this.id, required this.name, required this.address, required this.defaultMaintenance, this.openingCashBalance = 0});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'address': address, 'defaultMaintenance': defaultMaintenance, 'openingCashBalance': openingCashBalance};

  factory Society.fromMap(Map<String, dynamic> m) => Society(
    id: m['id'],
    name: m['name'],
    address: m['address'],
    defaultMaintenance: (m['defaultMaintenance'] as num).toDouble(),
    openingCashBalance: (m['openingCashBalance'] as num? ?? 0).toDouble(),
  );
}

class Wing {
  int? id;
  int societyId;
  String name;
  int floors;
  int defaultHousesPerFloor;
  String structureType;

  Wing({
    this.id,
    required this.societyId,
    required this.name,
    required this.floors,
    required this.defaultHousesPerFloor,
    this.structureType = 'Residential Apartment',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'societyId': societyId,
    'name': name,
    'floors': floors,
    'defaultHousesPerFloor': defaultHousesPerFloor,
    'structureType': structureType,
  };

  factory Wing.fromMap(Map<String, dynamic> m) => Wing(
    id: m['id'],
    societyId: m['societyId'],
    name: m['name'],
    floors: m['floors'],
    defaultHousesPerFloor: m['defaultHousesPerFloor'],
    structureType: m['structureType'] ?? 'Residential Apartment',
  );
}

class Flat {
  int? id;
  int wingId;
  String flatNumber;
  int floor;
  String? ownerName;
  String? ownerPhone;
  bool isVacant;
  String unitType;

  Flat({
    this.id,
    required this.wingId,
    required this.flatNumber,
    required this.floor,
    this.ownerName,
    this.ownerPhone,
    this.isVacant = false,
    this.unitType = 'Flat',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'wingId': wingId,
    'flatNumber': flatNumber,
    'floor': floor,
    'ownerName': ownerName,
    'ownerPhone': ownerPhone,
    'isVacant': isVacant ? 1 : 0,
    'unitType': unitType,
  };

  factory Flat.fromMap(Map<String, dynamic> m) => Flat(
    id: m['id'],
    wingId: m['wingId'],
    flatNumber: m['flatNumber'],
    floor: m['floor'],
    ownerName: m['ownerName'],
    ownerPhone: m['ownerPhone'],
    isVacant: m['isVacant'] == 1,
    unitType: m['unitType'] ?? 'Flat',
  );
}

// ── Maintenance ────────────────────────────────

class MaintenanceMonth {
  int? id;
  int? societyId;
  int year;
  int month; // 1-12
  double defaultAmount;
  String? notes;

  MaintenanceMonth({this.id, this.societyId, required this.year, required this.month, required this.defaultAmount, this.notes});

  String get label {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[month]} $year';
  }

  Map<String, dynamic> toMap() => {'id': id, 'societyId': societyId, 'year': year, 'month': month, 'defaultAmount': defaultAmount, 'notes': notes};

  factory MaintenanceMonth.fromMap(Map<String, dynamic> m) =>
      MaintenanceMonth(id: m['id'], societyId: m['societyId'], year: m['year'], month: m['month'], defaultAmount: (m['defaultAmount'] as num).toDouble(), notes: m['notes']);
}

enum PaymentStatus { pending, paid, partial, exempt }

class ExtraAmount {
  double amount;
  String note;
  ExtraAmount({required this.amount, required this.note});
  Map<String, dynamic> toMap() => {'amount': amount, 'note': note};
  factory ExtraAmount.fromMap(Map<String, dynamic> m) => ExtraAmount(amount: (m['amount'] as num).toDouble(), note: m['note'] ?? '');
}

class FlatMaintenance {
  int? id;
  int maintenanceMonthId;
  int flatId;
  String flatNumber;
  double baseAmount;
  double extraAmount; // Sum of extraDetails
  String? extraNote; // Stores JSON list of ExtraAmount
  PaymentStatus status;
  DateTime? paidDate;
  String? remarks;
  String? wingName;
  int? bankAccountId;

  FlatMaintenance({
    this.id,
    required this.maintenanceMonthId,
    required this.flatId,
    required this.flatNumber,
    required this.baseAmount,
    this.extraAmount = 0,
    this.extraNote,
    this.status = PaymentStatus.pending,
    this.paidDate,
    this.remarks,
    this.wingName,
    this.bankAccountId,
  });

  double get totalAmount => baseAmount + extraAmount;

  List<ExtraAmount> get extraDetails {
    if (extraNote == null || extraNote!.isEmpty) return [];
    try {
      final List decoded = jsonDecode(extraNote!);
      return decoded.map((e) => ExtraAmount.fromMap(e)).toList();
    } catch (_) {
      // Fallback for legacy data (plain string in extraNote)
      if (extraAmount > 0) {
        return [ExtraAmount(amount: extraAmount, note: extraNote ?? 'Extra')];
      }
      return [];
    }
  }

  String get formattedExtraDetails {
    final details = extraDetails;
    if (details.isEmpty) return '';
    return details
        .map((e) {
          if (e.note.isEmpty) return e.amount.toString();
          if (e.amount == 0) return e.note;
          return '${e.note}: ${e.amount}';
        })
        .join(", ");
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'maintenanceMonthId': maintenanceMonthId,
    'flatId': flatId,
    'flatNumber': flatNumber,
    'baseAmount': baseAmount,
    'extraAmount': extraAmount,
    'extraNote': extraNote,
    'status': status.index,
    'paidDate': paidDate?.toIso8601String(),
    'remarks': remarks,
    'bankAccountId': bankAccountId,
  };

  factory FlatMaintenance.fromMap(Map<String, dynamic> m) => FlatMaintenance(
    id: m['id'],
    maintenanceMonthId: m['maintenanceMonthId'],
    flatId: m['flatId'],
    flatNumber: m['flatNumber'],
    baseAmount: (m['baseAmount'] as num).toDouble(),
    extraAmount: (m['extraAmount'] as num).toDouble(),
    extraNote: m['extraNote'],
    status: PaymentStatus.values[m['status'] as int],
    paidDate: m['paidDate'] != null ? DateTime.parse(m['paidDate']) : null,
    remarks: m['remarks'],
    wingName: m['wingName'],
    bankAccountId: m['bankAccountId'],
  );

  FlatMaintenance copyWith({double? baseAmount, double? extraAmount, String? extraNote, PaymentStatus? status, DateTime? paidDate, String? remarks, String? wingName, int? bankAccountId}) =>
      FlatMaintenance(
        id: id,
        maintenanceMonthId: maintenanceMonthId,
        flatId: flatId,
        flatNumber: flatNumber,
        baseAmount: baseAmount ?? this.baseAmount,
        extraAmount: extraAmount ?? this.extraAmount,
        extraNote: extraNote ?? this.extraNote,
        status: status ?? this.status,
        paidDate: paidDate ?? this.paidDate,
        remarks: remarks ?? this.remarks,
        wingName: wingName ?? this.wingName,
        bankAccountId: bankAccountId ?? this.bankAccountId,
      );
}

// ── Summary ───────────────────────────────────

class MonthlySummary {
  final int year;
  final int month;
  final double cashMaintenanceCollected;
  final double bankMaintenanceCollected;
  final double cashIncome;
  final double bankIncome;
  final double cashExpense;
  final double bankExpense;
  final double cashToBank;
  final double bankToCash;
  final double openingCashBalance;
  final double openingBankBalance;

  MonthlySummary({
    required this.year,
    required this.month,
    required this.cashMaintenanceCollected,
    required this.bankMaintenanceCollected,
    required this.cashIncome,
    required this.bankIncome,
    required this.cashExpense,
    required this.bankExpense,
    required this.cashToBank,
    required this.bankToCash,
    required this.openingCashBalance,
    required this.openingBankBalance,
  });

  String get monthLabel {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[month]} $year';
  }

  double get maintenanceCollected => double.parse((cashMaintenanceCollected + bankMaintenanceCollected).toStringAsFixed(2));
  double get totalIncome => double.parse((maintenanceCollected + cashIncome + bankIncome).toStringAsFixed(2));
  double get totalExpense => double.parse((cashExpense + bankExpense).toStringAsFixed(2));

  double get closingCashBalance => double.parse((openingCashBalance + cashMaintenanceCollected + cashIncome - cashExpense - cashToBank + bankToCash).toStringAsFixed(2));
  double get closingBankBalance => double.parse((openingBankBalance + bankMaintenanceCollected + bankIncome - bankExpense + cashToBank - bankToCash).toStringAsFixed(2));

  double get totalClosingBalance => double.parse((closingCashBalance + closingBankBalance).toStringAsFixed(2));
  double get totalOpeningBalance => double.parse((openingCashBalance + openingBankBalance).toStringAsFixed(2));
  double get netChange => double.parse((totalIncome - totalExpense).toStringAsFixed(2));
}

// ── Transactions ───────────────────────────────

enum TransactionType { income, expense, cashToBank, bankToCash, bankToBank }

class TransactionCategory {
  int? id;
  String name;
  TransactionType type;

  TransactionCategory({this.id, required this.name, required this.type});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type.index};

  factory TransactionCategory.fromMap(Map<String, dynamic> m) => TransactionCategory(id: m['id'], name: m['name'], type: TransactionType.values[m['type']]);
}

class Transaction {
  int? id;
  int? societyId;
  DateTime date;
  TransactionType type;
  double amount;
  String description;
  int? categoryId;
  String? categoryName;
  int? bankAccountId;
  int? toBankAccountId;
  String? relatedFlatNumber; // for flat-specific income
  int year;
  int month;

  Transaction({
    this.id,
    this.societyId,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    this.categoryName,
    this.bankAccountId,
    this.toBankAccountId,
    this.relatedFlatNumber,
    required this.year,
    required this.month,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'societyId': societyId,
    'date': date.toIso8601String(),
    'type': type.index,
    'amount': amount,
    'description': description,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'bankAccountId': bankAccountId,
    'toBankAccountId': toBankAccountId,
    'relatedFlatNumber': relatedFlatNumber,
    'year': year,
    'month': month,
  };

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
    id: m['id'],
    societyId: m['societyId'],
    date: DateTime.parse(m['date']),
    type: TransactionType.values[m['type']],
    amount: (m['amount'] as num).toDouble(),
    description: m['description'],
    categoryId: m['categoryId'],
    categoryName: m['categoryName'],
    bankAccountId: m['bankAccountId'],
    toBankAccountId: m['toBankAccountId'],
    relatedFlatNumber: m['relatedFlatNumber'],
    year: m['year'],
    month: m['month'],
  );
}

// ── Bank Accounts ──────────────────────────────

class BankAccount {
  int? id;
  int? societyId;
  String bankName;
  String accountNumber;
  String accountHolder;
  double openingBalance;
  DateTime openingDate;
  bool isActive;

  BankAccount({
    this.id,
    this.societyId,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.openingBalance,
    required this.openingDate,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'societyId': societyId,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'accountHolder': accountHolder,
    'openingBalance': openingBalance,
    'openingDate': openingDate.toIso8601String(),
    'isActive': isActive ? 1 : 0,
  };

  factory BankAccount.fromMap(Map<String, dynamic> m) => BankAccount(
    id: m['id'],
    societyId: m['societyId'],
    bankName: m['bankName'],
    accountNumber: m['accountNumber'],
    accountHolder: m['accountHolder'],
    openingBalance: (m['openingBalance'] as num).toDouble(),
    openingDate: DateTime.parse(m['openingDate']),
    isActive: m['isActive'] == 1,
  );
}
