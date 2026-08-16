import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/app_category.dart';
import '../../models/transaction.dart';
import '../../models/goal.dart';
import '../../providers/providers.dart';
import '../add/quick_add_sheet.dart';
import '../categories/categories_screen.dart';
import '../transactions/transactions_screen.dart';
import '../reports/reports_screen.dart';
import '../goals/goals_screen.dart';
import '../settings/settings_screen.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

// Forest green brand palette
const _kForest   = Color(0xFF1B4332);
const _kForestMd = Color(0xFF2D6A4F);
const _kForestLt = Color(0xFF52B788);
const _kRose     = Color(0xFFBF6080);

// ── Home shell ────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firestoreServiceProvider).seedIfEmpty();
    });
  }

  final _pages = const [
    _DashboardTab(),
    CategoriesScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFB7D9CC),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Categories'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Goals'),
        ],
      ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton(
              backgroundColor: _kForestMd,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => showQuickAdd(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected   = ref.watch(selectedMonthProvider);
    final txnsAsync  = ref.watch(monthTransactionsProvider);
    final income     = ref.watch(monthlyIncomeProvider).valueOrNull ?? 79120.0;
    final expense    = ref.watch(monthExpenseTotalProvider);
    final buckets    = ref.watch(monthBucketTotalsProvider);
    final catTotals  = ref.watch(monthCategoryTotalsProvider);
    final catsAsync  = ref.watch(categoriesProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    // Recurring category check
    final allCats      = catsAsync.valueOrNull ?? [];
    final recurringCats = allCats.where((c) => c.isRecurring).toList();
    final loggedIds    = txnsAsync.valueOrNull?.map((t) => t.categoryId).toSet() ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Forest-green hero (swipe left/right for month) ─────────────
          SliverToBoxAdapter(
            child: _ForestHero(
              selected: selected,
              income: income,
              expense: expense,
              isCurrentMonth: isCurrentMonth,
              ref: ref,
            ),
          ),

          // ── Floating income/expense chips ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _SummaryChips(income: income, expense: expense),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Quick Add ───────────────────────────────────────────
                _SectionLabel('✨ Quick Add', sub: 'tap to log instantly'),
                const SizedBox(height: 10),
                catsAsync.when(
                  loading: () => const SizedBox(height: 110),
                  error: (_, __) => const SizedBox(),
                  data: (cats) =>
                      _QuickAddStrip(cats: cats, catTotals: catTotals),
                ),
                const SizedBox(height: 22),

                // ── Bills checklist ─────────────────────────────────────
                if (recurringCats.isNotEmpty) ...[
                  _SectionLabel('📋 Monthly Bills',
                      sub: 'recurring commitments'),
                  const SizedBox(height: 10),
                  _BillsChecklist(
                    recurringCats: recurringCats,
                    loggedIds: loggedIds,
                  ),
                  const SizedBox(height: 22),
                ],

                // ── Spending donut ──────────────────────────────────────
                if (expense > 0) ...[
                  _SectionLabel('💸 Spending Breakdown',
                      sub: DateFormat('MMM yyyy').format(selected)),
                  const SizedBox(height: 10),
                  _SpendingDonutCard(buckets: buckets, total: expense, income: income),
                  const SizedBox(height: 22),
                ],

                // ── Goals ───────────────────────────────────────────────
                goalsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (goals) {
                    final active =
                        goals.where((g) => !g.isCompleted).take(2).toList();
                    if (active.isEmpty) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('🎯 Savings Goals'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 200,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: active.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) =>
                                _GoalJarCard(goal: active[i]),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    );
                  },
                ),

                // ── Reflection / mood ───────────────────────────────────
                _ReflectionCard(income: income, expense: expense),
                const SizedBox(height: 22),

                // ── Recent transactions ─────────────────────────────────
                _SectionLabel('🧾 Recent Transactions'),
                const SizedBox(height: 10),
                txnsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (txns) {
                    if (txns.isEmpty) return _EmptyState();
                    return Column(
                      children: txns
                          .take(6)
                          .map((t) => _TxnCard(txn: t))
                          .toList(),
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

// ── Forest-green hero ─────────────────────────────────────────────────────────

class _ForestHero extends StatelessWidget {
  final DateTime selected;
  final double income, expense;
  final bool isCurrentMonth;
  final WidgetRef ref;

  const _ForestHero({
    required this.selected,
    required this.income,
    required this.expense,
    required this.isCurrentMonth,
    required this.ref,
  });

  void _prevMonth() {
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(m.year, m.month - 1, 1);
    HapticFeedback.lightImpact();
  }

  void _nextMonth() {
    if (isCurrentMonth) return;
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(m.year, m.month + 1, 1);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final balance    = income - expense;
    final remainPct  =
        income > 0 ? (balance / income * 100).clamp(0.0, 100.0) : 0.0;

    return GestureDetector(
      // Swipe left/right to change month
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity == null) return;
        if (d.primaryVelocity! < -200) _nextMonth();
        if (d.primaryVelocity! > 200) _prevMonth();
      },
      child: ClipPath(
        clipper: _HeroCurveClipper(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kForest, _kForestMd, _kForestLt],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Decorative circles
            Positioned(top: -30, right: -30,
                child: _DC(110, Colors.white, 15)),
            Positioned(top: 30, right: 70,
                child: _DC(45, Colors.white, 10)),
            Positioned(bottom: 50, left: -20,
                child: _DC(80, Colors.white, 8)),
            Positioned(bottom: 90, right: 30,
                child: _DC(28, Colors.white, 18)),
            Positioned(top: 90, left: 50,
                child: _DC(22, Colors.white, 15)),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 64),
                child: Column(children: [
                  // Month navigation row
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                      onPressed: _prevMonth,
                    ),
                    Expanded(
                      child: Column(children: [
                        Text(
                          DateFormat('MMMM yyyy').format(selected),
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Swipe to change month',
                          style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 9),
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right,
                          color: isCurrentMonth
                              ? Colors.white30
                              : Colors.white,
                          size: 28),
                      onPressed: isCurrentMonth ? null : _nextMonth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Plan today, save tomorrow 🌿',
                    style: GoogleFonts.pacifico(
                        color: Colors.white.withAlpha(200), fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  // Balance
                  Text('REMAINING BALANCE',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_fmt.format(balance)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${remainPct.toStringAsFixed(0)}% of income remaining 🌸',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HeroCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 45)
    ..quadraticBezierTo(
        size.width * 0.5, size.height + 22, size.width, size.height - 45)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(_) => false;
}

class _DC extends StatelessWidget {
  final double size;
  final Color color;
  final int alpha;
  const _DC(this.size, this.color, this.alpha);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: color.withAlpha(alpha)));
}

// ── Summary chips ─────────────────────────────────────────────────────────────

class _SummaryChips extends StatelessWidget {
  final double income, expense;
  const _SummaryChips({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -34),
      child: Row(children: [
        Expanded(
            child: _Chip('Income', '₹${_fmt.format(income)}',
                Icons.arrow_downward, Colors.green.shade600)),
        const SizedBox(width: 10),
        Expanded(
            child: _Chip('Spent', '₹${_fmt.format(expense)}',
                Icons.arrow_upward, Colors.red.shade400)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Chip(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: _kForestMd.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
          border: Border.all(color: const Color(0xFFD4E8DF)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration:
                BoxDecoration(color: color.withAlpha(18), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? sub;
  const _SectionLabel(this.title, {this.sub});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: const Color(0xFF1B3A2F))),
            if (sub != null)
              Text(sub!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ),
        Container(
          height: 2, width: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_kForestMd, Color(0xFFB7D9CC)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]);
}

// ── Quick Add strip ───────────────────────────────────────────────────────────

class _QuickAddStrip extends StatelessWidget {
  final List<AppCategory> cats;
  final Map<String, double> catTotals;
  const _QuickAddStrip({required this.cats, required this.catTotals});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 8),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final cat = cats[i];
          return _QuickCard(cat: cat, total: catTotals[cat.id] ?? 0);
        },
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final AppCategory cat;
  final double total;
  const _QuickCard({required this.cat, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = cat.color;
    return SizedBox(
      width: 90,
      height: 110,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showQuickAdd(context, category: cat),
          splashColor: color.withAlpha(40),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(60)),
              boxShadow: [
                BoxShadow(
                    color: color.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Colored icon badge
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withAlpha(70), color.withAlpha(30)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, color: color, size: 22),
              ),
              const SizedBox(height: 5),
              Text(
                cat.name,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (total > 0)
                Text(
                  '₹${_fmt.format(total)}',
                  style: TextStyle(
                      fontSize: 9, color: color.withAlpha(160)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Bills checklist ───────────────────────────────────────────────────────────

class _BillsChecklist extends StatelessWidget {
  final List<AppCategory> recurringCats;
  final Set<String> loggedIds;
  const _BillsChecklist(
      {required this.recurringCats, required this.loggedIds});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E8DF)),
        boxShadow: [
          BoxShadow(
              color: _kForestMd.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: recurringCats.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final done = loggedIds.contains(cat.id);
          final color = cat.color;
          final isLast = i == recurringCats.length - 1;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showQuickAdd(context, category: cat),
              borderRadius: BorderRadius.only(
                topLeft: i == 0 ? const Radius.circular(18) : Radius.zero,
                topRight: i == 0 ? const Radius.circular(18) : Radius.zero,
                bottomLeft:
                    isLast ? const Radius.circular(18) : Radius.zero,
                bottomRight:
                    isLast ? const Radius.circular(18) : Radius.zero,
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(children: [
                    // Check circle
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: done
                            ? color.withAlpha(20)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: done ? color : Colors.grey.shade300,
                            width: 1.5),
                      ),
                      child: done
                          ? Icon(Icons.check, size: 16, color: color)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Icon badge
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(cat.name,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? Colors.grey
                                    : const Color(0xFF1B3A2F),
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null)),
                        if (cat.defaultAmount != null)
                          Text(
                            '₹${_fmt.format(cat.defaultAmount!)}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: done
                            ? color.withAlpha(18)
                            : Colors.orange.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        done ? 'Done ✓' : 'Log it',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                done ? color : Colors.orange.shade700),
                      ),
                    ),
                  ]),
                ),
                if (!isLast)
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey.shade100),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Spending Donut ────────────────────────────────────────────────────────────

class _SpendingDonutCard extends StatelessWidget {
  final Map<String, double> buckets;
  final double total, income;
  const _SpendingDonutCard(
      {required this.buckets, required this.total, required this.income});

  @override
  Widget build(BuildContext context) {
    final active =
        bucketOrder.where((k) => (buckets[k] ?? 0) > 0).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E8DF)),
        boxShadow: [
          BoxShadow(
              color: _kForestMd.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(children: [
        // Donut + legend row
        Row(children: [
          // Donut
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: const Size(150, 150),
                painter: _DonutPainter(buckets: buckets, total: total),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('₹${_fmt.format(total)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Text('spent',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: active.map((k) {
                final amt = buckets[k] ?? 0;
                final color = bucketColors[k]!;
                final pct = total > 0 ? amt / total * 100 : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bucketNames[k]
                                ?.replaceAll(RegExp(r'[^\x00-\x7F]'), '')
                                .trim() ??
                            k,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, double> buckets;
  final double total;
  const _DonutPainter({required this.buckets, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) / 2;
    const strokeW = 32.0;
    final rect = Rect.fromCircle(center: center, radius: r - strokeW / 2 - 2);

    double startAngle = -pi / 2;
    for (final key in bucketOrder) {
      final amt = buckets[key] ?? 0;
      if (amt <= 0) continue;
      final sweep = (amt / total) * 2 * pi;
      canvas.drawArc(
        rect,
        startAngle + 0.04,
        sweep - 0.08,
        false,
        Paint()
          ..color = bucketColors[key]!
          ..strokeWidth = strokeW
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
    // White center
    canvas.drawCircle(
        center, r - strokeW - 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.buckets != buckets || old.total != total;
}

// ── Goal Jar card ─────────────────────────────────────────────────────────────

class _GoalJarCard extends StatelessWidget {
  final Goal goal;
  const _GoalJarCard({required this.goal});

  String get _encouragement {
    final p = goal.progress;
    if (p == 0) return 'Every rupee counts! 💪';
    if (p < 0.25) return 'Great start! 🌱';
    if (p < 0.5) return 'Keep going! 🔥';
    if (p < 0.75) return 'Halfway there! ⭐';
    if (p < 1) return 'So close! 🎉';
    return 'Goal reached! 🏆';
  }

  @override
  Widget build(BuildContext context) {
    final color = _kForestMd;
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E8DF)),
        boxShadow: [
          BoxShadow(
              color: _kForestMd.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Jar visual
        SizedBox(
          width: 80, height: 90,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: const Size(80, 90),
              painter: _JarPainter(
                  progress: goal.progress, fillColor: color),
            ),
            Positioned(
              top: 16,
              child: Text(goal.emoji,
                  style: const TextStyle(fontSize: 28)),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(goal.name,
            style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: const Color(0xFF1B3A2F)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(
          '₹${_fmt.format(goal.savedAmount)} / ₹${_fmt.format(goal.targetAmount)}',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${(goal.progress * 100).toStringAsFixed(0)}%  $_encouragement',
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _JarPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  const _JarPainter({required this.progress, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Jar body
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.76, h * 0.74),
      Radius.circular(w * 0.14),
    );

    // Background
    canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = fillColor.withAlpha(18)
          ..style = PaintingStyle.fill);

    // Fill (clip to jar shape)
    if (progress > 0) {
      canvas.save();
      canvas.clipRRect(bodyRRect);
      final fillH = h * 0.74 * progress;
      final fillY = h * 0.22 + h * 0.74 * (1 - progress);

      // Solid fill
      canvas.drawRect(
        Rect.fromLTWH(w * 0.12, fillY, w * 0.76, fillH),
        Paint()
          ..color = fillColor.withAlpha(100)
          ..style = PaintingStyle.fill,
      );

      // Wave at top of fill
      final wavePath = Path();
      wavePath.moveTo(w * 0.12, fillY);
      final segments = 20;
      for (int i = 0; i <= segments; i++) {
        final x = w * 0.12 + (w * 0.76) * i / segments;
        final y = fillY + 3 * sin(i / segments * 2 * pi);
        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      wavePath.lineTo(w * 0.88, h);
      wavePath.lineTo(w * 0.12, h);
      wavePath.close();
      canvas.drawPath(
          wavePath,
          Paint()
            ..color = fillColor.withAlpha(160)
            ..style = PaintingStyle.fill);

      canvas.restore();
    }

    // Outline
    canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Lid (neck of jar)
    final lidRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.08, w * 0.64, h * 0.16),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        lidRRect,
        Paint()
          ..color = fillColor.withAlpha(35)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        lidRRect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_JarPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

// ── Reflection / mood card ────────────────────────────────────────────────────

class _ReflectionCard extends StatelessWidget {
  final double income, expense;
  const _ReflectionCard({required this.income, required this.expense});

  String get _message {
    final saved = income - expense;
    final pct = income > 0 ? saved / income * 100 : 0.0;
    if (pct >= 50) return 'Amazing! You saved over half your income this month 🌟';
    if (pct >= 30) return 'Great going! You\'re building solid financial habits 💪';
    if (pct >= 10) return 'Good progress! Keep tracking every spend 🌸';
    return 'Every rupee logged is a step toward your goals 💕';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kForestMd.withAlpha(18),
            _kForestLt.withAlpha(12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E8DF)),
      ),
      child: Row(children: [
        const Text('🌿', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Monthly Note',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _kForestMd)),
            const SizedBox(height: 3),
            Text(_message,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2D4A3A),
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── Transaction card (dashboard) ──────────────────────────────────────────────

class _TxnCard extends StatelessWidget {
  final MoneyTransaction txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final color = bucketColors[txn.bucket] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E8DF)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showQuickAdd(context, existing: txn),
          child: Row(children: [
            // Left color bar
            Container(
              width: 5, height: 58,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            // Icon badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20), shape: BoxShape.circle),
                child: Icon(Icons.arrow_upward, size: 14, color: color),
              ),
            ),
            // Text
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(txn.categoryName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  txn.note.isNotEmpty
                      ? '${txn.note}  ·  ${DateFormat('dd MMM').format(txn.date)}'
                      : DateFormat('dd MMM').format(txn.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ]),
            ),
            // Amount
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                Text('−₹${_fmt.format(txn.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bucketNames[txn.bucket]
                            ?.replaceAll(RegExp(r'[^\x00-\x7F ]'), '')
                            .trim() ??
                        '',
                    style: TextStyle(fontSize: 8, color: color),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD4E8DF)),
        ),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Text('🌿', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text('No transactions yet',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 4),
          Text(
              'Tap a Quick Add card above to log your first spend',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      );
}
