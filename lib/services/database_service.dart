// lib/services/database_service.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<void> exportDatabase() async {
    try {
      final path = join(await getDatabasesPath(), 'society.db');
      final dbFile = File(path);
      if (!await dbFile.exists()) return;

      await Share.shareXFiles([XFile(path)], text: 'Backup of society database');
    } catch (e, st) {
      debugPrint('Share error: $e\n$st');
    }
  }

  Future<bool> importDatabase() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isNotEmpty && files.first.path != null) {
        final pickedFile = File(files.first.path!);
        final path = join(await getDatabasesPath(), 'society.db');

        if (_db != null) {
          await _db!.close();
          _db = null;
        }

        await pickedFile.copy(path);
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      rethrow;
    }
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'society.db');

    // await exportDatabase();

    return openDatabase(
      path,
      version: 12,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        final societies = await db.query('societies', limit: 1);
        if (societies.isNotEmpty) {
          final id = societies.first['id'];
          await db.update('bank_accounts', {'societyId': id}, where: 'societyId IS NULL');
          await db.update('transactions', {'societyId': id}, where: 'societyId IS NULL');
          await db.update('maintenance_months', {'societyId': id}, where: 'societyId IS NULL');
        }
        // Bind all current financials (transactions, bank accounts, maintenance months) to Wing G for 'Lotus Campus - Rivanta Garden City'
        try {
          final socs = await db.query('societies', where: 'name LIKE ?', whereArgs: ['%Lotus Campus - Rivanta Garden City%']);
          if (socs.isNotEmpty) {
            final socId = socs.first['id'];
            final wings = await db.query('wings', where: 'societyId = ? AND (name LIKE ? OR name = ?)', whereArgs: [socId, '%Wing G%', 'G']);
            if (wings.isNotEmpty) {
              final wingGId = wings.first['id'];
              await db.update('transactions', {'wingId': wingGId}, where: 'societyId = ? AND (wingId IS NULL OR wingId = 0)', whereArgs: [socId]);
              await db.update('bank_accounts', {'wingId': wingGId}, where: 'societyId = ? AND (isCommon = 0 OR isCommon IS NULL)', whereArgs: [socId]);
              await db.update('bank_accounts', {'wingId': null}, where: 'isCommon = 1');
              await db.update('maintenance_months', {'wingId': wingGId}, where: 'societyId = ? AND (wingId IS NULL OR wingId = 0)', whereArgs: [socId]);
            }
          }
        } catch (e, st) {
          debugPrint('OnOpen binding error: $e\n$st');
        }
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add openingCashBalance to societies if missing
      await db.execute('ALTER TABLE societies ADD COLUMN openingCashBalance REAL DEFAULT 0');
    }
    if (oldVersion < 3) {
      // Add societyId to isolate data per society
      await db.execute('ALTER TABLE bank_accounts ADD COLUMN societyId INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN societyId INTEGER');
      await db.execute('ALTER TABLE maintenance_months ADD COLUMN societyId INTEGER');

      final societies = await db.query('societies', limit: 1);
      if (societies.isNotEmpty) {
        final id = societies.first['id'];
        await db.update('bank_accounts', {'societyId': id});
        await db.update('transactions', {'societyId': id});
        await db.update('maintenance_months', {'societyId': id});
      }
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE flat_maintenances ADD COLUMN bankAccountId INTEGER');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE transactions ADD COLUMN toBankAccountId INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE wings ADD COLUMN structureType TEXT DEFAULT "Residential Apartment"');
      await db.execute('ALTER TABLE flats ADD COLUMN unitType TEXT DEFAULT "Flat"');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE societies ADD COLUMN autoReflectCommonExpenses INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE societies ADD COLUMN expenseDistributionMode TEXT DEFAULT "equal"');
      await db.execute('ALTER TABLE wings ADD COLUMN allocationPercentage REAL DEFAULT 100.0');
      await db.execute('ALTER TABLE bank_accounts ADD COLUMN isCommon INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN wingId INTEGER');
      await db.execute('ALTER TABLE transactions ADD COLUMN isCommonExpense INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN distributionMode TEXT DEFAULT "equal"');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE bank_accounts ADD COLUMN wingId INTEGER');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE bank_accounts ADD COLUMN isCash INTEGER DEFAULT 0');
      try {
        final socs = await db.query('societies', where: 'name LIKE ?', whereArgs: ['%Lotus Campus - Rivanta Garden City%']);
        if (socs.isNotEmpty) {
          final socId = socs.first['id'];
          final wings = await db.query('wings', where: 'societyId = ? AND (name LIKE ? OR name = ?)', whereArgs: [socId, '%Wing G%', 'G']);
          if (wings.isNotEmpty) {
            final wingGId = wings.first['id'];
            await db.update('bank_accounts', {'wingId': wingGId}, where: 'societyId = ?', whereArgs: [socId]);
          }
        }
      } catch (e, st) {
        debugPrint('Upgrade migration error: $e\n$st');
      }
    }
    if (oldVersion < 11) {
      try {
        await db.transaction((txn) async {
          await txn.execute('''
            CREATE TABLE maintenance_months_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              societyId INTEGER,
              wingId INTEGER,
              year INTEGER NOT NULL,
              month INTEGER NOT NULL,
              defaultAmount REAL NOT NULL,
              notes TEXT,
              UNIQUE(societyId, wingId, year, month),
              FOREIGN KEY (societyId) REFERENCES societies(id),
              FOREIGN KEY (wingId) REFERENCES wings(id)
            )
          ''');
          await txn.execute('''
            INSERT OR IGNORE INTO maintenance_months_new (id, societyId, wingId, year, month, defaultAmount, notes)
            SELECT id, societyId, wingId, year, month, defaultAmount, notes FROM maintenance_months
          ''');
          await txn.execute('DROP TABLE maintenance_months');
          await txn.execute('ALTER TABLE maintenance_months_new RENAME TO maintenance_months');
        });
      } catch (e, st) {
        debugPrint('Migration 11 maintenance_months error: $e\n$st');
      }
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE wings ADD COLUMN defaultMaintenance REAL DEFAULT 1000.0');
      await db.execute('ALTER TABLE wings ADD COLUMN openingCashBalance REAL DEFAULT 0.0');
      try {
        final socs = await db.query('societies', limit: 1);
        if (socs.isNotEmpty) {
          final socId = socs.first['id'];
          final openingCash = (socs.first['openingCashBalance'] as num?)?.toDouble() ?? 0;
          final defMaint = (socs.first['defaultMaintenance'] as num?)?.toDouble() ?? 1000;

          final wings = await db.query('wings', where: 'societyId = ? AND (name LIKE ? OR name = ?)', whereArgs: [socId, '%Wing G%', 'G']);
          if (wings.isNotEmpty) {
            final wingGId = wings.first['id'];
            await db.update('wings', {'openingCashBalance': openingCash, 'defaultMaintenance': defMaint}, where: 'id = ?', whereArgs: [wingGId]);
            await db.update('wings', {'openingCashBalance': 0.0}, where: 'societyId = ? AND id != ?', whereArgs: [socId, wingGId]);
          } else {
            await db.update('wings', {'defaultMaintenance': defMaint});
          }
          await db.update('societies', {'openingCashBalance': 0.0, 'defaultMaintenance': 0.0}, where: 'id = ?', whereArgs: [socId]);
        }
      } catch (e, st) {
        debugPrint('Migration 12 wing-wise opening cash error: $e\n$st');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE societies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        defaultMaintenance REAL DEFAULT 1000,
        openingCashBalance REAL DEFAULT 0,
        autoReflectCommonExpenses INTEGER DEFAULT 1,
        expenseDistributionMode TEXT DEFAULT 'equal'
      )
    ''');

    await db.execute('''
      CREATE TABLE wings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        societyId INTEGER NOT NULL,
        name TEXT NOT NULL,
        floors INTEGER NOT NULL,
        defaultHousesPerFloor INTEGER DEFAULT 4,
        structureType TEXT DEFAULT 'Residential Apartment',
        allocationPercentage REAL DEFAULT 100.0,
        defaultMaintenance REAL DEFAULT 1000.0,
        openingCashBalance REAL DEFAULT 0.0,
        FOREIGN KEY (societyId) REFERENCES societies(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE flats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wingId INTEGER NOT NULL,
        flatNumber TEXT NOT NULL,
        floor INTEGER NOT NULL,
        ownerName TEXT,
        ownerPhone TEXT,
        isVacant INTEGER DEFAULT 0,
        unitType TEXT DEFAULT 'Flat',
        FOREIGN KEY (wingId) REFERENCES wings(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE maintenance_months (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        societyId INTEGER,
        wingId INTEGER,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        defaultAmount REAL NOT NULL,
        notes TEXT,
        UNIQUE(societyId, wingId, year, month),
        FOREIGN KEY (societyId) REFERENCES societies(id),
        FOREIGN KEY (wingId) REFERENCES wings(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE flat_maintenances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maintenanceMonthId INTEGER NOT NULL,
        flatId INTEGER NOT NULL,
        flatNumber TEXT NOT NULL,
        baseAmount REAL NOT NULL,
        extraAmount REAL DEFAULT 0,
        extraNote TEXT,
        status INTEGER DEFAULT 0,
        paidDate TEXT,
        remarks TEXT,
        bankAccountId INTEGER,
        FOREIGN KEY (maintenanceMonthId) REFERENCES maintenance_months(id),
        FOREIGN KEY (flatId) REFERENCES flats(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        societyId INTEGER,
        date TEXT NOT NULL,
        type INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        categoryId INTEGER,
        categoryName TEXT,
        bankAccountId INTEGER,
        toBankAccountId INTEGER,
        relatedFlatNumber TEXT,
        wingId INTEGER,
        isCommonExpense INTEGER DEFAULT 0,
        distributionMode TEXT DEFAULT 'equal',
        year INTEGER NOT NULL,
        month INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        societyId INTEGER,
        wingId INTEGER,
        bankName TEXT NOT NULL,
        accountNumber TEXT NOT NULL,
        accountHolder TEXT NOT NULL,
        openingBalance REAL DEFAULT 0,
        openingDate TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        isCommon INTEGER DEFAULT 0,
        isCash INTEGER DEFAULT 0,
        FOREIGN KEY (societyId) REFERENCES societies(id),
        FOREIGN KEY (wingId) REFERENCES wings(id)
      )
    ''');

    // Seed default categories
    await db.execute('''
      INSERT INTO transaction_categories (name, type) VALUES
        ('Maintenance Income', 0),
        ('Event / Occasion Income', 0),
        ('Other Income', 0),
        ('Cleaning / Sanitation', 1),
        ('Security', 1),
        ('Electricity', 1),
        ('Lift Maintenance', 1),
        ('Repairs & Maintenance', 1),
        ('Garden', 1),
        ('Administrative', 1),
        ('Other Expense', 1)
    ''');
  }

  // ── Society ────────────────────────────────

  Future<int> insertSociety(Society s) async {
    final d = await db;
    s.id = await d.insert('societies', s.toMap());
    await d.insert('bank_accounts', {
      'societyId': s.id,
      'wingId': null,
      'bankName': 'Cash',
      'accountNumber': 'CASH-SOC-${s.id}',
      'accountHolder': s.name,
      'openingBalance': s.openingCashBalance,
      'openingDate': DateTime.now().toIso8601String(),
      'isActive': 1,
      'isCommon': 1,
      'isCash': 1,
    });
    return s.id!;
  }

  Future<Society?> getSociety() async {
    final d = await db;
    final rows = await d.query('societies', limit: 1);
    if (rows.isEmpty) return null;
    return Society.fromMap(rows.first);
  }

  Future<List<Society>> getSocieties() async {
    final d = await db;
    final rows = await d.query('societies', orderBy: 'name');
    return rows.map(Society.fromMap).toList();
  }

  Future<void> updateSociety(Society s) async {
    final d = await db;
    await d.update('societies', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  // ── Wings ──────────────────────────────────

  Future<int> insertWing(Wing w) async {
    final d = await db;
    w.id = await d.insert('wings', w.toMap());
    await d.insert('bank_accounts', {
      'societyId': w.societyId,
      'wingId': w.id,
      'bankName': 'Cash',
      'accountNumber': 'CASH-WING-${w.id}',
      'accountHolder': w.name,
      'openingBalance': w.openingCashBalance,
      'openingDate': DateTime.now().toIso8601String(),
      'isActive': 1,
      'isCommon': 0,
      'isCash': 1,
    });
    return w.id!;
  }

  Future<List<Wing>> getWings(int societyId) async {
    final d = await db;
    final rows = await d.query('wings', where: 'societyId = ?', whereArgs: [societyId]);
    return rows.map(Wing.fromMap).toList();
  }

  Future<void> updateWing(Wing w) async {
    final d = await db;
    await d.update('wings', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
    await d.update(
      'bank_accounts',
      {'openingBalance': w.openingCashBalance, 'accountHolder': w.name},
      where: 'wingId = ? AND isCash = 1',
      whereArgs: [w.id],
    );
  }

  Future<void> deleteWing(int wingId) async {
    final d = await db;
    await d.delete('flats', where: 'wingId = ?', whereArgs: [wingId]);
    await d.delete('wings', where: 'id = ?', whereArgs: [wingId]);
  }

  // ── Flats ──────────────────────────────────

  Future<void> insertFlats(List<Flat> flats) async {
    final d = await db;
    final batch = d.batch();
    for (final f in flats) {
      batch.insert('flats', f.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<int> insertFlat(Flat f) async {
    final d = await db;
    f.id = await d.insert('flats', f.toMap());
    return f.id!;
  }

  Future<List<Flat>> getFlats(int wingId) async {
    final d = await db;
    final rows = await d.query('flats', where: 'wingId = ?', whereArgs: [wingId], orderBy: 'flatNumber');
    return rows.map(Flat.fromMap).toList();
  }

  Future<List<Flat>> getAllFlats() async {
    final d = await db;
    final rows = await d.query('flats', orderBy: 'flatNumber');
    return rows.map(Flat.fromMap).toList();
  }

  Future<List<Flat>> getFlatsBySociety(int societyId) async {
    final d = await db;
    final rows = await d.rawQuery(
      '''
      SELECT f.* FROM flats f
      JOIN wings w ON f.wingId = w.id
      WHERE w.societyId = ?
      ORDER BY f.flatNumber
    ''',
      [societyId],
    );
    return rows.map(Flat.fromMap).toList();
  }

  Future<void> updateFlat(Flat f) async {
    final d = await db;
    await d.update('flats', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
  }

  Future<void> deleteFlat(int flatId) async {
    final d = await db;
    await d.delete('flats', where: 'id = ?', whereArgs: [flatId]);
  }

  // ── Maintenance ──────────────────────────────

  Future<int> insertMaintenanceMonth(MaintenanceMonth mm) async {
    final d = await db;
    mm.id = await d.insert('maintenance_months', mm.toMap());
    return mm.id!;
  }

  Future<MaintenanceMonth?> getMaintenanceMonth(int year, int month, {int? societyId, int? wingId}) async {
    final d = await db;
    final rows = await d.query(
      'maintenance_months',
      where: 'year = ? AND month = ?${societyId != null ? " AND societyId = ?" : ""}${wingId != null ? " AND wingId = ?" : " AND wingId IS NULL"}',
      whereArgs: [year, month, if (societyId != null) societyId, if (wingId != null) wingId],
    );
    if (rows.isEmpty) return null;
    return MaintenanceMonth.fromMap(rows.first);
  }

  Future<List<MaintenanceMonth>> getAllMaintenanceMonths({int? societyId}) async {
    final d = await db;
    final rows = await d.query('maintenance_months', where: societyId != null ? 'societyId = ?' : null, whereArgs: societyId != null ? [societyId] : null, orderBy: 'year DESC, month DESC');
    return rows.map(MaintenanceMonth.fromMap).toList();
  }

  Future<void> updateMaintenanceMonth(MaintenanceMonth mm) async {
    final d = await db;
    await d.update('maintenance_months', mm.toMap(), where: 'id = ?', whereArgs: [mm.id]);
  }

  Future<void> deleteMaintenanceMonth(int id) async {
    final d = await db;
    await d.delete('flat_maintenances', where: 'maintenanceMonthId = ?', whereArgs: [id]);
    await d.delete('maintenance_months', where: 'id = ?', whereArgs: [id]);
  }

  // ── Flat Maintenance ───────────────────────

  Future<void> insertFlatMaintenances(List<FlatMaintenance> list) async {
    final d = await db;
    final batch = d.batch();
    for (final fm in list) {
      batch.insert('flat_maintenances', fm.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<FlatMaintenance>> getFlatMaintenances(int maintenanceMonthId) async {
    final d = await db;
    final rows = await d.rawQuery(
      '''
      SELECT fm.*, w.name as wingName
      FROM flat_maintenances fm
      JOIN flats f ON fm.flatId = f.id
      JOIN wings w ON f.wingId = w.id
      WHERE fm.maintenanceMonthId = ?
      ORDER BY fm.flatNumber
    ''',
      [maintenanceMonthId],
    );
    return rows.map(FlatMaintenance.fromMap).toList();
  }

  Future<void> updateFlatMaintenance(FlatMaintenance fm) async {
    final d = await db;
    await d.update('flat_maintenances', fm.toMap(), where: 'id = ?', whereArgs: [fm.id]);
  }

  // ── Transactions ───────────────────────────

  Future<int> insertTransaction(Transaction t) async {
    final d = await db;
    t.id = await d.insert('transactions', t.toMap());
    return t.id!;
  }

  Future<List<Transaction>> getTransactions(int year, int month, {int? societyId}) async {
    final d = await db;
    final rows = await d.query(
      'transactions',
      where: 'year = ? AND month = ?${societyId != null ? " AND societyId = ?" : ""}',
      whereArgs: [year, month, if (societyId != null) societyId],
      orderBy: 'date DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getAllTransactions({int? societyId}) async {
    final d = await db;
    final rows = await d.query('transactions', where: societyId != null ? 'societyId = ?' : null, whereArgs: societyId != null ? [societyId] : null, orderBy: 'date DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  Future<void> updateTransaction(Transaction t) async {
    final d = await db;
    await d.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTransaction(int id) async {
    final d = await db;
    await d.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Transaction Categories ─────────────────

  Future<List<TransactionCategory>> getCategories() async {
    final d = await db;
    final rows = await d.query('transaction_categories', orderBy: 'name');
    return rows.map(TransactionCategory.fromMap).toList();
  }

  Future<int> insertCategory(TransactionCategory c) async {
    final d = await db;
    c.id = await d.insert('transaction_categories', c.toMap());
    return c.id!;
  }

  // ── Bank Accounts ──────────────────────────

  Future<int> insertBankAccount(BankAccount b) async {
    final d = await db;
    b.id = await d.insert('bank_accounts', b.toMap());
    return b.id!;
  }

  Future<List<BankAccount>> getBankAccounts({int? societyId}) async {
    final d = await db;
    final rows = await d.query('bank_accounts', where: societyId != null ? 'societyId = ?' : null, whereArgs: societyId != null ? [societyId] : null, orderBy: 'bankName');
    return rows.map(BankAccount.fromMap).toList();
  }

  Future<void> updateBankAccount(BankAccount b) async {
    final d = await db;
    await d.update('bank_accounts', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  // ── Monthly Summary Computation ────────────

  Future<double> getAccountBalance(int? bankAccountId, int year, int month, {int? societyId}) async {
    final d = await db;
    if (bankAccountId == null) {
      final summary = await computeMonthlySummary(year, month, societyId: societyId);
      return double.parse(summary.closingCashBalance.toStringAsFixed(2));
    }

    final accs = await getBankAccounts(societyId: societyId);
    final acc = accs.firstWhere((a) => a.id == bankAccountId);
    double balance = acc.openingBalance;

    // From transactions
    final List<Map<String, dynamic>> maps = societyId != null
        ? await d.query('transactions', where: 'societyId = ? AND bankAccountId = ?', whereArgs: [societyId, bankAccountId])
        : await d.query('transactions', where: 'bankAccountId = ?', whereArgs: [bankAccountId]);

    for (final m in maps) {
      final t = Transaction.fromMap(m);
      if (t.year < year || (t.year == year && t.month <= month)) {
        if (t.type == TransactionType.income || t.type == TransactionType.cashToBank) {
          balance += t.amount;
        } else if (t.type == TransactionType.expense || t.type == TransactionType.bankToCash) {
          balance -= t.amount;
        } else if (t.type == TransactionType.bankToBank) {
          if (t.bankAccountId == bankAccountId) {
            balance -= t.amount; // Source
          } else if (t.toBankAccountId == bankAccountId) {
            balance += t.amount; // Destination
          }
        }
      }
    }

    // From maintenance payments
    final allMms = await getAllMaintenanceMonths(societyId: societyId);
    for (final m in allMms) {
      if (m.year < year || (m.year == year && m.month <= month)) {
        final fms = await getFlatMaintenances(m.id!);
        for (final fm in fms) {
          if (fm.status == PaymentStatus.paid && fm.bankAccountId == bankAccountId) {
            balance += fm.totalAmount;
          }
        }
      }
    }

    return double.parse(balance.toStringAsFixed(2));
  }

  Future<MonthlySummary> computeMonthlySummary(int year, int month, {int? societyId}) async {
    // Bank & Cash Opening Balance (wingId IS NULL)
    final accounts = await getBankAccounts(societyId: societyId);
    double openingCash = accounts.where((b) => b.wingId == null && b.isCash).fold(0, (sum, acc) => sum + acc.openingBalance);
    double openingBank = accounts.where((b) => b.wingId == null && !b.isCash).fold(0, (sum, acc) => sum + acc.openingBalance);

    // Maintenance collected (paid flat maintenances) for society level (wingId IS NULL)
    final allMms = await getAllMaintenanceMonths(societyId: societyId);
    double cashMaintenanceCollected = 0;
    double bankMaintenanceCollected = 0;
    for (final mm in allMms) {
      if (mm.year == year && mm.month == month && mm.wingId == null) {
        final fms = await getFlatMaintenances(mm.id!);
        for (final fm in fms) {
          if (fm.status == PaymentStatus.paid) {
            if (fm.bankAccountId != null) {
              bankMaintenanceCollected += fm.totalAmount;
            } else {
              cashMaintenanceCollected += fm.totalAmount;
            }
          }
        }
      }
    }

    // Transactions (wingId IS NULL)
    final txns = (await getTransactions(year, month, societyId: societyId)).where((t) => t.wingId == null).toList();
    double cashIncome = 0;
    double bankIncome = 0;
    double cashExpense = 0;
    double bankExpense = 0;
    double cashToBank = 0;
    double bankToCash = 0;

    for (final t in txns) {
      if (t.type == TransactionType.income) {
        if (t.bankAccountId != null) {
          bankIncome += t.amount;
        } else {
          cashIncome += t.amount;
        }
      } else if (t.type == TransactionType.expense) {
        if (t.bankAccountId != null) {
          bankExpense += t.amount;
        } else {
          cashExpense += t.amount;
        }
      } else if (t.type == TransactionType.cashToBank) {
        cashToBank += t.amount;
      } else if (t.type == TransactionType.bankToCash) {
        bankToCash += t.amount;
      }
    }

    // openingBank already computed from accounts where wingId == null

    // Compute balances from previous months (wingId IS NULL)
    final allPrevTxns = (await getAllTransactions(societyId: societyId)).where((t) => t.wingId == null);
    final prevMonthsTxns = allPrevTxns.where((t) => t.year < year || (t.year == year && t.month < month));

    double cashIn = 0;
    double cashOut = 0;
    double bankIn = 0;
    double bankOut = 0;

    for (final t in prevMonthsTxns) {
      if (t.type == TransactionType.income) {
        if (t.bankAccountId != null) {
          bankIn += t.amount;
        } else {
          cashIn += t.amount;
        }
      } else if (t.type == TransactionType.expense) {
        if (t.bankAccountId != null) {
          bankOut += t.amount;
        } else {
          cashOut += t.amount;
        }
      } else if (t.type == TransactionType.cashToBank) {
        cashOut += t.amount;
        bankIn += t.amount;
      } else if (t.type == TransactionType.bankToCash) {
        cashIn += t.amount;
        bankOut += t.amount;
      }
    }

    // Previous maintenance collections (wingId IS NULL)
    for (final m in allMms) {
      if ((m.year < year || (m.year == year && m.month < month)) && m.wingId == null) {
        final fms = await getFlatMaintenances(m.id!);
        for (final fm in fms) {
          if (fm.status == PaymentStatus.paid) {
            if (fm.bankAccountId != null) {
              bankIn += fm.totalAmount;
            } else {
              cashIn += fm.totalAmount;
            }
          }
        }
      }
    }

    openingCash += cashIn - cashOut;
    openingBank += bankIn - bankOut;

    return MonthlySummary(
      year: year,
      month: month,
      cashMaintenanceCollected: double.parse(cashMaintenanceCollected.toStringAsFixed(2)),
      bankMaintenanceCollected: double.parse(bankMaintenanceCollected.toStringAsFixed(2)),
      cashIncome: double.parse(cashIncome.toStringAsFixed(2)),
      bankIncome: double.parse(bankIncome.toStringAsFixed(2)),
      cashExpense: double.parse(cashExpense.toStringAsFixed(2)),
      bankExpense: double.parse(bankExpense.toStringAsFixed(2)),
      cashToBank: double.parse(cashToBank.toStringAsFixed(2)),
      bankToCash: double.parse(bankToCash.toStringAsFixed(2)),
      openingCashBalance: double.parse(openingCash.toStringAsFixed(2)),
      openingBankBalance: double.parse(openingBank.toStringAsFixed(2)),
    );
  }

  Future<Map<String, double>> computeAllTransactionsSummary({int? societyId, int? wingId}) async {
    final txns = await getAllTransactions(societyId: societyId);
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in txns) {
      if (wingId != null && t.wingId != wingId && t.wingId != null) continue;
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }

    return {
      'totalIncome': double.parse(totalIncome.toStringAsFixed(2)),
      'totalExpense': double.parse(totalExpense.toStringAsFixed(2)),
      'netAmount': double.parse((totalIncome - totalExpense).toStringAsFixed(2)),
    };
  }
}
