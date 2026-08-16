import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/app_category.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../add/quick_add_sheet.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
const _kPrimary = Color(0xFFBF6080);

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);
    final txnsAsync = ref.watch(monthTransactionsProvider);
    final total = ref.watch(monthExpenseTotalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _CurvedHeader(selected: selected, total: total),
          ),
          txnsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (txns) {
              if (txns.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('🌸', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('No transactions this month',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Use the + button to add one',
                          style: TextStyle(color: Colors.grey)),
                    ]),
                  ),
                );
              }

              final Map<String, List<MoneyTransaction>> grouped = {};
              for (final t in txns) {
                final key = DateFormat('EEE, dd MMM').format(t.date);
                grouped.putIfAbsent(key, () => []).add(t);
              }

              final keys = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final dateKey = keys[i];
                      final dayTxns = grouped[dateKey]!;
                      final dayTotal = dayTxns.fold(0.0, (s, t) => s + t.amount);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kPrimary.withAlpha(15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(dateKey,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: _kPrimary)),
                              ),
                              const Spacer(),
                              Text('−₹${_fmt.format(dayTotal)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          ...dayTxns.map((t) => _TxnCard(txn: t)),
                        ],
                      );
                    },
                    childCount: keys.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurvedHeader extends ConsumerWidget {
  final DateTime selected;
  final double total;
  const _CurvedHeader({required this.selected, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isCurrentMonth = selected.year == now.year && selected.month == now.month;

    return ClipPath(
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
          Positioned(top: -15, right: -15, child: _DC(70, 15)),
          Positioned(top: 30, right: 70, child: _DC(30, 10)),
          Positioned(bottom: 30, left: 20, child: _DC(50, 10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text('Transactions',
                      style: TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                // Month navigation
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                    onPressed: () {
                      final m = ref.read(selectedMonthProvider);
                      ref.read(selectedMonthProvider.notifier).state =
                          DateTime(m.year, m.month - 1, 1);
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy').format(selected),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: isCurrentMonth ? Colors.white30 : Colors.white, size: 26),
                    onPressed: isCurrentMonth
                        ? null
                        : () {
                            final m = ref.read(selectedMonthProvider);
                            ref.read(selectedMonthProvider.notifier).state =
                                DateTime(m.year, m.month + 1, 1);
                          },
                  ),
                ]),
                if (total > 0)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Total: ₹${_fmt.format(total)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

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
            shape: BoxShape.circle, color: Colors.white.withAlpha(alpha)),
      );
}

class _TxnCard extends ConsumerWidget {
  final MoneyTransaction txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = bucketColors[txn.bucket] ?? Colors.grey;
    return Dismissible(
      key: Key(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 24),
          SizedBox(height: 2),
          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10)),
        ]),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Delete transaction?'),
          content: Text('${txn.categoryName}  ₹${_fmt.format(txn.amount)}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(firestoreServiceProvider).deleteTransaction(txn.id),
      child: GestureDetector(
        onTap: () => showQuickAdd(context, existing: txn),
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withAlpha(18), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          // Left color accent bar
          Container(
            width: 5,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          // Circle icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha(60), color.withAlpha(20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_upward, size: 16, color: color),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(txn.categoryName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bucketNames[txn.bucket]?.replaceAll(RegExp(r'[^\x00-\x7F ]'), '').trim() ?? '',
                      style: TextStyle(fontSize: 9, color: color),
                    ),
                  ),
                  if (txn.note.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(txn.note,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ]),
            ),
          ),
          // Amount + date + menu
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('−₹${_fmt.format(txn.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM').format(txn.date),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (val) {
                  if (val == 'edit') {
                    showQuickAdd(context, existing: txn);
                  } else if (val == 'delete') {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        title: const Text('Delete transaction?'),
                        content: Text(
                            '${txn.categoryName}  ₹${_fmt.format(txn.amount)}'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    ).then((ok) {
                      if (ok == true) {
                        ref.read(firestoreServiceProvider).deleteTransaction(txn.id);
                      }
                    });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined,
                          color: Color(0xFF7B9CC4), size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ]),
          ),
        ]),
      ),
      ),
    );
  }
}
