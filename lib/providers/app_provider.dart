// lib/providers/app_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/database_service.dart';

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService();
  static const String _keySocietyId = 'selected_society_id';
  static const String _keyOnboardingCompleted = 'onboarding_completed';

  Society? society;
  List<Wing> wings = [];
  List<Flat> allFlats = [];
  List<BankAccount> bankAccounts = [];
  List<TransactionCategory> categories = [];
  bool loading = true;
  bool isSetupFinished = false;
  bool isOnboardingCompleted = false;

  Future<void> init() async {
    loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    isOnboardingCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;

    final allSocieties = await _db.getSocieties();
    if (allSocieties.isNotEmpty) {
      if (society == null) {
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getInt(_keySocietyId);
        if (savedId != null) {
          try {
            society = allSocieties.firstWhere((s) => s.id == savedId);
          } catch (_) {
            society = allSocieties.first;
          }
        } else {
          society = allSocieties.first;
        }
      } else {
        // Try to keep currently selected society
        try {
          society = allSocieties.firstWhere((s) => s.id == society!.id);
        } catch (_) {
          society = allSocieties.first;
        }
      }

      wings = await _db.getWings(society!.id!);
      allFlats = await _db.getFlatsBySociety(society!.id!);
      bankAccounts = await _db.getBankAccounts(societyId: society!.id);
    } else {
      society = null;
      wings = [];
      allFlats = [];
      bankAccounts = [];
    }

    isSetupFinished = society != null && allFlats.isNotEmpty;
    categories = await _db.getCategories();
    loading = false;
    notifyListeners();
  }

  Future<void> setSociety(Society s) async {
    society = s;
    final prefs = await SharedPreferences.getInstance();
    if (s.id != null) {
      await prefs.setInt(_keySocietyId, s.id!);
    }
    await init();
  }

  void resetForNewSociety() {
    society = null;
    wings = [];
    allFlats = [];
    bankAccounts = [];
    isSetupFinished = false;
    notifyListeners();
  }

  Future<void> saveSociety(Society s) async {
    if (s.id == null) {
      final id = await _db.insertSociety(s);
      s.id = id;
    } else {
      await _db.updateSociety(s);
    }
    await setSociety(s);
  }

  Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
    isOnboardingCompleted = true;
    notifyListeners();
  }

  void finishSetup() {
    isSetupFinished = true;
    notifyListeners();
  }

  Future<void> saveWingWithFlats(Wing wing, List<Flat> flats) async {
    if (wing.id == null) {
      await _db.insertWing(wing);
      for (final f in flats) {
        f.wingId = wing.id!;
      }
      await _db.insertFlats(flats);
    } else {
      await _db.updateWing(wing);
    }
    wings = await _db.getWings(society!.id!);
    allFlats = await _db.getFlatsBySociety(society!.id!);
    notifyListeners();
  }

  Future<void> deleteWing(int wingId) async {
    await _db.deleteWing(wingId);
    wings = await _db.getWings(society!.id!);
    allFlats = await _db.getFlatsBySociety(society!.id!);
    notifyListeners();
  }

  Future<void> saveBankAccount(BankAccount b) async {
    if (b.id == null) {
      b.societyId = society?.id;
      await _db.insertBankAccount(b);
    } else {
      await _db.updateBankAccount(b);
    }
    bankAccounts = await _db.getBankAccounts(societyId: society?.id);
    notifyListeners();
  }

  Future<void> refreshFlats() async {
    if (society != null) {
      allFlats = await _db.getFlatsBySociety(society!.id!);
      notifyListeners();
    }
  }

  Future<double> getAccountBalance(int? bankAccountId, int year, int month, {int? wingId}) async {
    return await _db.getAccountBalance(bankAccountId, year, month, societyId: society?.id, wingId: wingId);
  }

  Future<double> computeBankBalance(int year, int month) async {
    final summary = await _db.computeMonthlySummary(year, month, societyId: society?.id);
    return summary.closingBankBalance;
  }

  Future<double> computeCashBalance(int year, int month) async {
    final summary = await _db.computeMonthlySummary(year, month, societyId: society?.id);
    return summary.closingCashBalance;
  }
}
