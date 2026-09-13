// lib/services/database_service.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
    } catch (e) {
      print('Share error: $e');
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
    } catch (e) {
      print('Import error: $e');
      rethrow;
    }
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'society.db');

    // await exportDatabase();

    return openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Ensure all records have a societyId if at least one society exists
        final societies = await db.query('societies', limit: 1);
        if (societies.isNotEmpty) {
          final id = societies.first['id'];
          await db.update('bank_accounts', {'societyId': id}, where: 'societyId IS NULL');
          await db.update('transactions', {'societyId': id}, where: 'societyId IS NULL');
          await db.update('maintenance_months', {'societyId': id}, where: 'societyId IS NULL');
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE societies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        defaultMaintenance REAL DEFAULT 1000,
        openingCashBalance REAL DEFAULT 0
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
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        defaultAmount REAL NOT NULL,
        notes TEXT,
        UNIQUE(societyId, year, month)
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
        year INTEGER NOT NULL,
        month INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        societyId INTEGER,
        bankName TEXT NOT NULL,
        accountNumber TEXT NOT NULL,
        accountHolder TEXT NOT NULL,
        openingBalance REAL DEFAULT 0,
        openingDate TEXT NOT NULL,
        isActive INTEGER DEFAULT 1
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

  Future<MaintenanceMonth?> getMaintenanceMonth(int year, int month, {int? societyId}) async {
    final d = await db;
    final rows = await d.query('maintenance_months', where: 'year = ? AND month = ?${societyId != null ? " AND societyId = ?" : ""}', whereArgs: [year, month, if (societyId != null) societyId]);
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
    final societies = await getSocieties();
    final society = societies.firstWhere(
      (s) => s.id == societyId,
      orElse: () => societies.isNotEmpty ? societies.first : Society(name: '', address: '', defaultMaintenance: 0),
    );
    double openingCash = society.openingCashBalance;

    // Maintenance collected (paid flat maintenances)
    final mm = await getMaintenanceMonth(year, month, societyId: societyId);
    double cashMaintenanceCollected = 0;
    double bankMaintenanceCollected = 0;
    if (mm != null) {
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

    // Transactions
    final txns = await getTransactions(year, month, societyId: societyId);
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

    // Bank Opening Balance
    final accounts = await getBankAccounts(societyId: societyId);
    double openingBank = accounts.fold(0, (sum, acc) => sum + acc.openingBalance);

    // Compute balances from previous months
    final allPrevTxns = await getAllTransactions(societyId: societyId);
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

    // Previous maintenance collections
    final allMms = await getAllMaintenanceMonths(societyId: societyId);
    for (final m in allMms) {
      if (m.year < year || (m.year == year && m.month < month)) {
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
}
