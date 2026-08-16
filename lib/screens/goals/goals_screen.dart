import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/goal.dart';
import '../../providers/providers.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');
const _kPrimary = Color(0xFFBF6080);

const _goalEmojis = [
  '💍', '🏠', '🚗', '✈️', '💻', '📱', '👗', '🎓',
  '💰', '🏖️', '🎯', '🥇', '🎁', '🌟', '🛍️', '📚',
];

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
        onPressed: () => _showGoalForm(context, ref),
      ),
      body: CustomScrollView(
        slivers: [
          // Curved header
          SliverToBoxAdapter(child: _CurvedHeader()),

          goalsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e'))),
            data: (goals) {
              if (goals.isEmpty) {
                return SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('No goals yet',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Tap + New Goal to start saving for something',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                );
              }

              final active = goals.where((g) => !g.isCompleted).toList();
              final completed = goals.where((g) => g.isCompleted).toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (active.isNotEmpty) ...[
                      _SectionLabel('🎯 Active Goals'),
                      const SizedBox(height: 10),
                      ...active.map((g) => _GoalCard(
                            goal: g,
                            onAddMoney: () =>
                                _showAddMoney(context, ref, g),
                            onEdit: () =>
                                _showGoalForm(context, ref, existing: g),
                            onCorrect: () =>
                                _showCorrectAmount(context, ref, g),
                            onDelete: () =>
                                _confirmDelete(context, ref, g),
                          )),
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionLabel('🎉 Completed'),
                      const SizedBox(height: 10),
                      ...completed.map((g) => _GoalCard(
                            goal: g,
                            onAddMoney: null,
                            onEdit: () =>
                                _showGoalForm(context, ref, existing: g),
                            onCorrect: null,
                            onDelete: () =>
                                _confirmDelete(context, ref, g),
                          )),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Add / Edit goal form ─────────────────────────────────────────────────

  void _showGoalForm(BuildContext context, WidgetRef ref,
      {Goal? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _GoalFormSheet(existing: existing, ref: ref),
    );
  }

  // ── Add money ────────────────────────────────────────────────────────────

  void _showAddMoney(BuildContext context, WidgetRef ref, Goal goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add to ${goal.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount (₹)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              ref.read(firestoreServiceProvider).addToGoal(goal.id, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Correct saved amount ─────────────────────────────────────────────────

  void _showCorrectAmount(BuildContext context, WidgetRef ref, Goal goal) {
    final ctrl =
        TextEditingController(text: goal.savedAmount.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Correct Saved Amount'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Set the exact amount saved so far.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Saved Amount (₹)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim()) ?? 0;
              ref.read(firestoreServiceProvider).setSavedAmount(goal.id, amount);
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  // ── Delete confirmation ──────────────────────────────────────────────────

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Goal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete goal?'),
        content: Text('Delete "${goal.emoji} ${goal.name}"? This cannot be undone.'),
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
    if (ok == true) {
      ref.read(firestoreServiceProvider).deleteGoal(goal.id);
    }
  }
}

// ── Goal Form Sheet ───────────────────────────────────────────────────────────

class _GoalFormSheet extends StatefulWidget {
  final Goal? existing;
  final WidgetRef ref;
  const _GoalFormSheet({this.existing, required this.ref});

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _savedCtrl = TextEditingController();
  String _emoji = '🎯';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _targetCtrl.text = e.targetAmount.toInt().toString();
      _savedCtrl.text = e.savedAmount.toInt().toString();
      _emoji = e.emoji;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim()) ?? 0;
    if (name.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name and target amount')));
      return;
    }
    setState(() => _saving = true);
    final saved = double.tryParse(_savedCtrl.text.trim()) ?? 0;
    final fs = widget.ref.read(firestoreServiceProvider);

    if (_isEdit) {
      final updated = Goal(
        id: widget.existing!.id,
        name: name,
        emoji: _emoji,
        targetAmount: target,
        savedAmount: saved,
        targetDate: widget.existing!.targetDate,
      );
      await fs.updateGoal(updated);
    } else {
      await fs.addGoal(Goal(
        id: '',
        name: name,
        emoji: _emoji,
        targetAmount: target,
        savedAmount: saved,
      ));
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFFFF0F3), Color(0xFFFFF5F7)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text(_isEdit ? '✏️ Edit Goal' : '🎯 New Goal',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF3D1A24))),
            ]),
          ]),
        ),

        // Form
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Emoji picker
              const Text('Pick an emoji',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3D1A24))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _goalEmojis.map((e) {
                  final isSelected = e == _emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _kPrimary.withAlpha(20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _kPrimary : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Name
              const Text('Goal Name',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3D1A24))),
              const SizedBox(height: 6),
              _field(_nameCtrl, 'e.g. Gold Ring, Emergency Fund…',
                  Icons.label_outline),
              const SizedBox(height: 16),

              // Target
              const Text('Target Amount (₹)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3D1A24))),
              const SizedBox(height: 6),
              _field(_targetCtrl, 'e.g. 50000',
                  Icons.currency_rupee,
                  numeric: true),
              const SizedBox(height: 16),

              // Saved
              const Text('Already Saved (₹)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF3D1A24))),
              const SizedBox(height: 6),
              _field(_savedCtrl, '0', Icons.savings_outlined, numeric: true),
              const SizedBox(height: 28),

              // Save button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD4748E), _kPrimary]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isEdit ? '✅  Save Changes' : '✨  Add Goal',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool numeric = false}) =>
      TextField(
        controller: ctrl,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: numeric
            ? TextCapitalization.none
            : TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFFFFF0F3),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8C0CB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8C0CB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 2)),
        ),
      );
}

// ── Goal Card ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onAddMoney;
  final VoidCallback onEdit;
  final VoidCallback? onCorrect;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onAddMoney,
    required this.onEdit,
    required this.onCorrect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal.progress;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D0D8)),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // Top row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(children: [
            // Emoji in circle
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _kPrimary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(goal.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            // Name + saved
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(goal.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '₹${_fmt.format(goal.savedAmount)} saved  ·  ₹${_fmt.format(goal.remaining)} to go',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ]),
            ),
            // ⋮ menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'correct' && onCorrect != null) onCorrect!();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        color: Color(0xFF7B9CC4), size: 18),
                    SizedBox(width: 10),
                    Text('Edit Goal'),
                  ]),
                ),
                if (onCorrect != null)
                  const PopupMenuItem(
                    value: 'correct',
                    child: Row(children: [
                      Icon(Icons.tune, color: Color(0xFF9E81C4), size: 18),
                      SizedBox(width: 10),
                      Text('Correct Saved Amount'),
                    ]),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Goal',
                        style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ]),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Target: ₹${_fmt.format(goal.targetAmount)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: goal.isCompleted
                      ? Colors.amber.withAlpha(30)
                      : _kPrimary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  goal.isCompleted
                      ? '🎉 Done!'
                      : '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: goal.isCompleted ? Colors.amber.shade700 : _kPrimary,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 12,
                backgroundColor: const Color(0xFFF2D0D8),
                valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted ? Colors.amber : _kPrimary),
              ),
            ),
          ]),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(children: [
            if (onAddMoney != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kPrimary,
                    side: const BorderSide(color: _kPrimary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: onAddMoney,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Money', style: TextStyle(fontSize: 13)),
                ),
              ),
              if (onCorrect != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9E81C4),
                      side: const BorderSide(color: Color(0xFF9E81C4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: onCorrect,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Correct', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ],
            if (onAddMoney == null)
              const Expanded(
                child: Center(
                  child: Text('Goal reached! 🎉',
                      style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ── Curved header ─────────────────────────────────────────────────────────────

class _CurvedHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          Positioned(top: 20, right: 70, child: _DC(30, 12)),
          Positioned(bottom: 20, left: 10, child: _DC(45, 10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Goals 🎯',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('Track what you\'re saving for',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
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
    ..quadraticBezierTo(
        size.width * 0.5, size.height + 14, size.width, size.height - 30)
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
          color: Color(0xFF3D1A24)));
}
