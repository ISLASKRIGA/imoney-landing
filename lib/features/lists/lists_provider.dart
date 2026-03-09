import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Transaction;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/dependency_injection.dart';
import '../../data/database/app_database.dart';

/// Stream de todas las listas del usuario
final userListsProvider = StreamProvider<List<UserList>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUserLists();
});

// ── Lista activa (null = "Lista Privada" por defecto) ────────
class ActiveListNotifier extends StateNotifier<UserList?> {
  final SharedPreferences _prefs;
  final AppDatabase _db;
  static const _key = 'active_list_id';

  ActiveListNotifier(this._prefs, this._db) : super(null) {
    _restore();
  }

  Future<void> _restore() async {
    final savedId = _prefs.getInt(_key);
    if (savedId != null) {
      final lists = await _db.getAllUserLists();
      final match = lists.where((l) => l.id == savedId).toList();
      if (match.isNotEmpty) {
        state = match.first;
      }
    }
  }

  void select(UserList? list) {
    state = list;
    if (list == null) {
      _prefs.remove(_key);
    } else {
      _prefs.setInt(_key, list.id);
    }
  }

  void clearIfDeleted(int deletedId) {
    if (state?.id == deletedId) {
      state = null;
      _prefs.remove(_key);
    }
  }
}

final activeListProvider = StateNotifierProvider<ActiveListNotifier, UserList?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  return ActiveListNotifier(prefs, db);
});

// ── CRUD de listas ────────────────────────────────────────
class ListsNotifier extends StateNotifier<AsyncValue<List<UserList>>> {
  final AppDatabase _db;
  final Ref _ref;

  ListsNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final lists = await _db.getAllUserLists();
    state = AsyncValue.data(lists);
  }

  Future<void> add({required String name, required String emoji}) async {
    await _db.addUserList(UserListsCompanion(
      name: Value(name),
      emoji: Value(emoji),
    ));
    await _load();
  }

  Future<void> rename(UserList list, String newName) async {
    await _db.updateUserList(UserListsCompanion(
      id: Value(list.id),
      name: Value(newName),
      emoji: Value(list.emoji),
    ));
    await _load();
  }

  Future<void> delete(int id) async {
    await _db.deleteUserList(id);
    // Si era la lista activa, la limpiamos
    _ref.read(activeListProvider.notifier).clearIfDeleted(id);
    await _load();
  }
}

final listsNotifierProvider =
    StateNotifierProvider<ListsNotifier, AsyncValue<List<UserList>>>((ref) {
  final db = ref.watch(databaseProvider);
  return ListsNotifier(db, ref);
});
