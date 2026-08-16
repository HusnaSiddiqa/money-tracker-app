import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_category.dart';
import '../models/transaction.dart';
import '../models/goal.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference get _user => _db.collection('users').doc(_uid);
  CollectionReference get _cats => _user.collection('categories');
  CollectionReference get _txns => _user.collection('transactions');
  CollectionReference get _goals => _user.collection('goals');
  CollectionReference get _income => _user.collection('income');

  // ── Seed ──────────────────────────────────────────────────────

  Future<void> seedIfEmpty() async {
    final snap = await _cats.limit(1).get();
    if (snap.docs.isNotEmpty) return; // already seeded

    final batch = _db.batch();
    for (final cat in seedCategories) {
      batch.set(_cats.doc(), cat.toMap());
    }
    final now = DateTime.now();
    final key = _monthKey(now.year, now.month);
    batch.set(_income.doc(key), {'amount': 79120.0});
    batch.set(_income.doc('default'), {'amount': 79120.0});

    // Only seed the goal if none exist yet
    final goalSnap = await _goals.limit(1).get();
    if (goalSnap.docs.isEmpty) {
      batch.set(_goals.doc(), {
        'name': 'Gold Ring',
        'emoji': '💍',
        'target_amount': 50000.0,
        'saved_amount': 0.0,
        'target_date': null,
      });
    }
    await batch.commit();
  }

  // ── Categories ────────────────────────────────────────────────

  Stream<List<AppCategory>> categoriesStream() => _cats
      .orderBy('sort_order')
      .snapshots()
      .map((s) => s.docs.map(AppCategory.fromFirestore).toList());

  Future<void> addCategory(AppCategory cat) => _cats.add(cat.toMap());

  Future<void> updateCategory(AppCategory cat) =>
      _cats.doc(cat.id).update(cat.toMap());

  Future<void> togglePin(String catId, bool current) =>
      _cats.doc(catId).update({'is_pinned': !current});

  Future<void> deleteCategory(String id) => _cats.doc(id).delete();

  // ── Transactions ──────────────────────────────────────────────

  Stream<List<MoneyTransaction>> monthTransactionsStream(int year, int month) {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 1);
    return _txns
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map(MoneyTransaction.fromFirestore)
            .where((t) => t.categoryId.isNotEmpty)
            .toList());
  }

  Future<void> addTransaction(MoneyTransaction txn) => _txns.add(txn.toMap());

  Future<void> deleteTransaction(String id) => _txns.doc(id).delete();

  Future<void> updateTransaction(MoneyTransaction txn) =>
      _txns.doc(txn.id).update(txn.toMap());

  Future<void> generateRecurringEntries(
      List<AppCategory> cats, int year, int month) async {
    final batch = _db.batch();
    final date = DateTime(year, month, 1);
    for (final cat in cats) {
      if (!cat.isRecurring || cat.defaultAmount == null) continue;
      batch.set(_txns.doc(), {
        'category_id': cat.id,
        'category_name': cat.name,
        'bucket': cat.bucket,
        'amount': cat.defaultAmount,
        'note': '(recurring)',
        'date': Timestamp.fromDate(date),
        'created_from_recurring': true,
      });
    }
    await batch.commit();
  }

  // ── Monthly income ────────────────────────────────────────────

  Future<double> getMonthlyIncome(int year, int month) async {
    final doc = await _income.doc(_monthKey(year, month)).get();
    if (doc.exists) {
      return ((doc.data() as Map<String, dynamic>)['amount'] ?? 79120).toDouble();
    }
    final def = await _income.doc('default').get();
    if (def.exists) {
      return ((def.data() as Map<String, dynamic>)['amount'] ?? 79120).toDouble();
    }
    return 79120;
  }

  Future<void> setMonthlyIncome(int year, int month, double amount) async {
    await _income.doc(_monthKey(year, month)).set({'amount': amount});
    await _income.doc('default').set({'amount': amount});
  }

  // ── Goals ─────────────────────────────────────────────────────

  Stream<List<Goal>> goalsStream() =>
      _goals.snapshots().map((s) => s.docs.map(Goal.fromFirestore).toList());

  Future<void> addGoal(Goal goal) => _goals.add(goal.toMap());
  Future<void> updateGoal(Goal goal) =>
      _goals.doc(goal.id).update(goal.toMap());
  Future<void> deleteGoal(String id) => _goals.doc(id).delete();

  Future<void> addToGoal(String goalId, double amount) async {
    final doc = await _goals.doc(goalId).get();
    if (!doc.exists) return;
    final cur = ((doc.data() as Map<String, dynamic>)['saved_amount'] ?? 0).toDouble();
    await _goals.doc(goalId).update({'saved_amount': cur + amount});
  }

  Future<void> setSavedAmount(String goalId, double amount) =>
      _goals.doc(goalId).update({'saved_amount': amount});

  String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';
}
