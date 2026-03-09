import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Transaction;
import '../../core/di/dependency_injection.dart';
import '../../data/database/app_database.dart';

/// Stream de todas las transacciones recurrentes
final recurringTransactionsProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecurringTransactions();
});

/// Notifier para operaciones CRUD de recurrentes
class RecurringNotifier extends StateNotifier<AsyncValue<List<RecurringTransaction>>> {
  final AppDatabase _db;

  RecurringNotifier(this._db) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getAllRecurringTransactions();
    state = AsyncValue.data(list);
  }

  Future<void> add({
    required double amount,
    required String description,
    required String? categoryName,
    required bool isIncome,
    required String frequency, // 'weekly' | 'monthly'
    required int dayOfPeriod,
  }) async {
    await _db.addRecurringTransaction(RecurringTransactionsCompanion(
      amount: Value(amount),
      description: Value(description),
      categoryName: Value(categoryName),
      type: Value(isIncome ? 1 : 0),
      frequency: Value(frequency),
      dayOfPeriod: Value(dayOfPeriod),
    ));
    await _load();
  }

  Future<void> toggleActive(RecurringTransaction r) async {
    await _db.updateRecurringTransaction(RecurringTransactionsCompanion(
      id: Value(r.id),
      amount: Value(r.amount),
      description: Value(r.description),
      categoryName: Value(r.categoryName),
      type: Value(r.type),
      frequency: Value(r.frequency),
      dayOfPeriod: Value(r.dayOfPeriod),
      isActive: Value(!r.isActive),
    ));
    await _load();
  }

  Future<void> delete(int id) async {
    await _db.deleteRecurringTransaction(id);
    await _load();
  }
}

final recurringNotifierProvider =
    StateNotifierProvider<RecurringNotifier, AsyncValue<List<RecurringTransaction>>>((ref) {
  final db = ref.watch(databaseProvider);
  return RecurringNotifier(db);
});
