import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/app_category.dart';
import '../../providers/providers.dart';
import '../add/quick_add_sheet.dart';
import 'category_form_sheet.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
const _kPrimary = Color(0xFFBF6080);

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);
    final catTotals = ref.watch(monthCategoryTotalsProvider);
    final income = ref.watch(monthlyIncomeProvider).valueOrNull ?? 79120.0;
    final selected = ref.watch(selectedMonthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Category'),
        onPressed: () => showCategoryForm(context),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cats) {
          final grouped = <String, List<AppCategory>>{};
          for (final cat in cats) {
            grouped.putIfAbsent(cat.bucket, () => []).add(cat);
          }

          return CustomScrollView(
            slivers: [
              // Curved header
              SliverToBoxAdapter(
                child: _CurvedCatHeader(selected: selected),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ...bucketOrder.map((bucket) {
                      final bucketCats = grouped[bucket];
                      if (bucketCats == null || bucketCats.isEmpty) return const SizedBox();
                      final bucketTotal = bucketCats.fold(
                          0.0, (s, c) => s + (catTotals[c.id] ?? 0));
                      final incomePct = income > 0 ? bucketTotal / income * 100 : 0.0;
                      final color = bucketColors[bucket]!;
                      return _BucketSection(
                        bucket: bucket,
                        color: color,
                        total: bucketTotal,
                        incomePct: incomePct,
                        categories: bucketCats,
                        catTotals: catTotals,
                      );
                    }),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CurvedCatHeader extends ConsumerWidget {
  final DateTime selected;
  const _CurvedCatHeader({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isCurrentMonth = selected.year == now.year && selected.month == now.month;

    return ClipPath(
      clipper: _SmallCurveClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD4748E), _kPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -15, right: -15, child: _DC(70, 15)),
            Positioned(top: 20, right: 60, child: _DC(30, 12)),
            Positioned(bottom: 20, left: 10, child: _DC(45, 10)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 44),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Categories',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3)),
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
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
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 30)
      ..quadraticBezierTo(size.width * 0.5, size.height + 14, size.width, size.height - 30)
      ..lineTo(size.width, 0)
      ..close();
  }

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

class _BucketSection extends ConsumerStatefulWidget {
  final String bucket;
  final Color color;
  final double total, incomePct;
  final List<AppCategory> categories;
  final Map<String, double> catTotals;

  const _BucketSection({
    required this.bucket, required this.color, required this.total,
    required this.incomePct, required this.categories, required this.catTotals,
  });

  @override
  ConsumerState<_BucketSection> createState() => _BucketSectionState();
}

class _BucketSectionState extends ConsumerState<_BucketSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.color.withAlpha(40)),
          boxShadow: [
            BoxShadow(color: widget.color.withAlpha(18), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          // Bucket header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: widget.color.withAlpha(18),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: _expanded ? Radius.zero : const Radius.circular(18),
                ),
              ),
              child: Row(children: [
                // Color dot + name
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(bucketNames[widget.bucket] ?? widget.bucket,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: widget.color)),
                ),
                if (widget.total > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${_fmt.format(widget.total)}  ${widget.incomePct.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 10, color: widget.color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.color, size: 20),
              ]),
            ),
          ),

          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.95,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: widget.categories.length,
                itemBuilder: (ctx, i) {
                  final cat = widget.categories[i];
                  final total = widget.catTotals[cat.id] ?? 0;
                  return _CategoryCard(cat: cat, total: total);
                },
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final AppCategory cat;
  final double total;
  const _CategoryCard({required this.cat, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = cat.color;
    return GestureDetector(
      onTap: () => showQuickAdd(context, category: cat),
      onLongPress: () => _showOptions(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
          boxShadow: [
            BoxShadow(color: color.withAlpha(18), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Gradient circle icon
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(70), color.withAlpha(25)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(alignment: Alignment.center, children: [
              Icon(cat.icon, color: color, size: 20),
              if (cat.isRecurring)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.repeat, size: 7, color: Colors.white),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 5),
          Text(cat.name,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          if (total > 0) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('₹${_fmt.format(total)}',
                  style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold)),
            ),
          ],
          if (cat.isPinned)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.push_pin, size: 8, color: color.withAlpha(150)),
            ),
        ]),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Category name header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cat.color.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: cat.color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Log spend
          _OptionTile(
            icon: Icons.add_circle_outline,
            color: _kPrimary,
            label: 'Log a Spend',
            onTap: () {
              Navigator.pop(context);
              showQuickAdd(context, category: cat);
            },
          ),
          // Pin/Unpin
          _OptionTile(
            icon: cat.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            color: const Color(0xFF9E81C4),
            label: cat.isPinned ? 'Remove from Quick Add' : 'Pin to Quick Add',
            onTap: () {
              ref.read(firestoreServiceProvider).togglePin(cat.id, cat.isPinned);
              Navigator.pop(context);
            },
          ),
          // Edit
          _OptionTile(
            icon: Icons.edit_outlined,
            color: const Color(0xFF7B9CC4),
            label: 'Edit Category',
            onTap: () {
              Navigator.pop(context);
              showCategoryForm(context, existing: cat);
            },
          ),
          // Delete
          _OptionTile(
            icon: Icons.delete_outline,
            color: Colors.red.shade400,
            label: 'Delete Category',
            onTap: () async {
              Navigator.pop(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: const Text('Delete category?'),
                  content: Text(
                      'Delete "${cat.name}"? Existing transactions won\'t be removed.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                ref.read(firestoreServiceProvider).deleteCategory(cat.id);
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        onTap: onTap,
      );
}
