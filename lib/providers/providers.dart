import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/app_category.dart';
import '../models/goal.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

// Selected month (1st day of month)
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// ── Categories ────────────────────────────────────────────────────────────────

final categoriesProvider = StreamProvider<List<AppCategory>>(
    (ref) => ref.read(firestoreServiceProvider).categoriesStream());

final pinnedCategoriesProvider = Provider<List<AppCategory>>((ref) {
  final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
  return cats.where((c) => c.isPinned).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

// ── Transactions for selected month ──────────────────────────────────────────

final monthTransactionsProvider =
    StreamProvider.autoDispose<List<MoneyTransaction>>((ref) {
  final m = ref.watch(selectedMonthProvider);
  return ref
      .read(firestoreServiceProvider)
      .monthTransactionsStream(m.year, m.month);
});

// Derived from stream (client-side, no extra queries)

final monthExpenseTotalProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(monthTransactionsProvider).maybeWhen(
        data: (txns) => txns.fold(0.0, (s, t) => s + t.amount),
        orElse: () => 0.0,
      );
});

final monthBucketTotalsProvider =
    Provider.autoDispose<Map<String, double>>((ref) {
  return ref.watch(monthTransactionsProvider).maybeWhen(
        data: (txns) {
          final Map<String, double> m = {};
          for (final t in txns) {
            m[t.bucket] = (m[t.bucket] ?? 0) + t.amount;
          }
          return m;
        },
        orElse: () => {},
      );
});

final monthCategoryTotalsProvider =
    Provider.autoDispose<Map<String, double>>((ref) {
  return ref.watch(monthTransactionsProvider).maybeWhen(
        data: (txns) {
          final Map<String, double> m = {};
          for (final t in txns) {
            m[t.categoryId] = (m[t.categoryId] ?? 0) + t.amount;
          }
          return m;
        },
        orElse: () => {},
      );
});

// ── Monthly income ────────────────────────────────────────────────────────────

final monthlyIncomeProvider = FutureProvider.autoDispose<double>((ref) {
  final m = ref.watch(selectedMonthProvider);
  return ref.read(firestoreServiceProvider).getMonthlyIncome(m.year, m.month);
});

// ── Goals ─────────────────────────────────────────────────────────────────────

final goalsProvider = StreamProvider<List<Goal>>(
    (ref) => ref.read(firestoreServiceProvider).goalsStream());
