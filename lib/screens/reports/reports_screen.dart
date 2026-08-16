import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/app_category.dart';
import '../../providers/providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
const _kPrimary = Color(0xFFBF6080);

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final income = ref.watch(monthlyIncomeProvider).valueOrNull ?? 79120.0;
    final expense = ref.watch(monthExpenseTotalProvider);
    final buckets = ref.watch(monthBucketTotalsProvider);
    final txnsAsync = ref.watch(monthTransactionsProvider);

    final balance = income - expense;
    final savingsTotal = (buckets['savings'] ?? 0) + (buckets['debt'] ?? 0);
    final savingsRate = income > 0 ? savingsTotal / income * 100 : 0.0;
    final familyRate = income > 0 ? (buckets['family'] ?? 0) / income * 100 : 0.0;
    final now = DateTime.now();
    final isCurrentMonth = selected.year == now.year && selected.month == now.month;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: CustomScrollView(
        slivers: [
          // ── Curved header with month nav ─────────────────────────────────
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _CurveClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD4748E), _kPrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  Positioned(top: -15, right: -15,
                      child: _DC(70, 15)),
                  Positioned(top: 30, right: 70,
                      child: _DC(30, 10)),
                  Positioned(bottom: 30, left: 20,
                      child: _DC(50, 10)),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 52),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Text('Reports',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        // ← month nav →
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.white, size: 26),
                            onPressed: () {
                              final m = ref.read(selectedMonthProvider);
                              ref.read(selectedMonthProvider.notifier).state =
                                  DateTime(m.year, m.month - 1, 1);
                            },
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormat('MMMM yyyy').format(selected),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right,
                                color: isCurrentMonth
                                    ? Colors.white30
                                    : Colors.white,
                                size: 26),
                            onPressed: isCurrentMonth
                                ? null
                                : () {
                                    final m = ref.read(selectedMonthProvider);
                                    ref
                                        .read(selectedMonthProvider.notifier)
                                        .state =
                                        DateTime(m.year, m.month + 1, 1);
                                  },
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Balance hero card ───────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBF6080), Color(0xFF9C3A58)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: _kPrimary.withAlpha(60),
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Text(DateFormat('MMMM yyyy').format(selected),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('₹${_fmt.format(balance)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold)),
                    const Text('Remaining Balance',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatPill('Income', income, Colors.greenAccent),
                          Container(
                              width: 1, height: 32, color: Colors.white24),
                          _StatPill('Spent', expense, Colors.redAccent.shade100),
                        ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Insight chips ───────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: _InsightCard(
                      label: '💰 Savings Rate',
                      value: '${savingsRate.toStringAsFixed(0)}%',
                      sub: 'Savings + Debt repaid',
                      highlight: savingsRate >= 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightCard(
                      label: '👨‍👩‍👧 Family Support',
                      value: '${familyRate.toStringAsFixed(0)}%',
                      sub: 'of monthly income',
                      highlight: true,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── By Bucket ───────────────────────────────────────────────
                _SectionTitle('📊 Spending by Bucket'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2D0D8)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: bucketOrder.map((key) {
                      final amount = buckets[key] ?? 0;
                      if (amount == 0) return const SizedBox();
                      final color = bucketColors[key]!;
                      final pct = expense > 0
                          ? (amount / expense).clamp(0.0, 1.0)
                          : 0.0;
                      final incomePct =
                          income > 0 ? amount / income * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(bucketNames[key] ?? key,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: color)),
                                    ]),
                                    Row(children: [
                                      Text('₹${_fmt.format(amount)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: color)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: color.withAlpha(18),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text(
                                            '${incomePct.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                                fontSize: 9, color: color,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ]),
                                  ]),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 10,
                                  backgroundColor: color.withAlpha(18),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ]),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // ── By Category ─────────────────────────────────────────────
                _SectionTitle('🏷️ Spending by Category'),
                const SizedBox(height: 10),
                txnsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (txns) {
                    if (txns.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFF2D0D8)),
                        ),
                        child: const Center(
                          child: Text('No transactions this month 🌸',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }
                    final Map<String, double> catTotals = {};
                    final Map<String, String> catBucket = {};
                    for (final t in txns) {
                      catTotals[t.categoryName] =
                          (catTotals[t.categoryName] ?? 0) + t.amount;
                      catBucket[t.categoryName] = t.bucket;
                    }
                    final sorted = catTotals.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF2D0D8)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: sorted.map((e) {
                          final color =
                              bucketColors[catBucket[e.key]] ?? Colors.grey;
                          final pct = expense > 0
                              ? (e.value / expense).clamp(0.0, 1.0)
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(e.key,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('₹${_fmt.format(e.value)}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: color)),
                                  ]),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 7,
                                      backgroundColor: color.withAlpha(18),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(color),
                                    ),
                                  ),
                                ]),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 30)
    ..quadraticBezierTo(size.width * 0.5, size.height + 14, size.width, size.height - 30)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_) => false;
}

class _DC extends StatelessWidget {
  final double size;
  final int alpha;
  const _DC(this.size, this.alpha);
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withAlpha(alpha)));
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF3D1A24))),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kPrimary, Color(0xFFF2D0D8)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ]);
}

class _StatPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text('₹${_fmt.format(value)}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]);
}

class _InsightCard extends StatelessWidget {
  final String label, value, sub;
  final bool highlight;
  const _InsightCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? _kPrimary : Colors.orange.shade600;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(sub,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }
}
