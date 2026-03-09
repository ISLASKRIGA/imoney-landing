import 'package:drift/drift.dart' hide Transaction;
import '../database/app_database.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  // ── Streams ───────────────────────────────────────────────

  /// Stream de TODAS las transacciones (sin filtro de lista)
  Stream<List<Transaction>> watchTransactions() => _db.watchAllTransactions();

  /// Stream filtrado por lista activa:
  ///   listId == null  → Lista Privada (sin lista asignada)
  ///   listId != null  → lista específica del usuario
  Stream<List<Transaction>> watchTransactionsByList(int? listId) =>
      _db.watchTransactionsByList(listId);

  Future<List<Transaction>> getAllTransactions() => _db.getAllTransactions();

  // ── Crear ─────────────────────────────────────────────────

  Future<void> addTransaction({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required bool isIncome,
    int? listId, // null = Lista Privada
  }) async {
    await _db.addTransaction(TransactionsCompanion(
      amount: Value(amount),
      categoryName: Value(category),
      description: Value(description),
      date: Value(date),
      type: Value(isIncome ? 1 : 0),
      listId: Value(listId),
    ));
  }

  // ── Actualizar ────────────────────────────────────────────

  Future<void> updateTransaction({
    required int id,
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required bool isIncome,
    int? listId,
  }) async {
    await _db.updateTransaction(TransactionsCompanion(
      id: Value(id),
      amount: Value(amount),
      categoryName: Value(category),
      description: Value(description),
      date: Value(date),
      type: Value(isIncome ? 1 : 0),
      listId: Value(listId),
    ));
  }

  // ── Eliminar ──────────────────────────────────────────────

  Future<void> deleteTransaction(int id) => _db.deleteTransaction(id);

  // ── Utilidades ────────────────────────────────────────────

  Future<bool> isCategoryInUse(String categoryName) =>
      _db.isCategoryInUse(categoryName);

  Stream<double> watchTotalIncome() => _db.watchTotalIncome();
  Stream<double> watchTotalExpense() => _db.watchTotalExpense();
}
