import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/app_category.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';

Future<void> showQuickAdd(
  BuildContext context, {
  AppCategory? category,
  MoneyTransaction? existing,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _QuickAddSheet(initialCategory: category, existing: existing),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  final AppCategory? initialCategory;
  final MoneyTransaction? existing;
  const _QuickAddSheet({this.initialCategory, this.existing});

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  String _amount = '';
  String _note = '';
  DateTime _date = DateTime.now();
  AppCategory? _category;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _amountCtrl;
  final FocusNode _amountFocus = FocusNode();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    final existing = widget.existing;
    if (existing != null) {
      // Edit mode: pre-fill from existing transaction
      _amount = existing.amount % 1 == 0
          ? existing.amount.toInt().toString()
          : existing.amount.toString();
      _note = existing.note;
      _noteCtrl = TextEditingController(text: _note);
      _date = existing.date;
      _amountCtrl.text = '₹ $_amount';
      _amountCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _amountCtrl.text.length));
      // Look up the full AppCategory from provider
      final cats = ref.read(categoriesProvider).valueOrNull ?? [];
      _category = cats.firstWhere(
        (c) => c.id == existing.categoryId,
        orElse: () => AppCategory(
          id: existing.categoryId,
          name: existing.categoryName,
          bucket: existing.bucket,
          iconKey: 'other',
          isRecurring: false,
          isPinned: false,
          sortOrder: 0,
        ),
      );
    } else {
      _noteCtrl = TextEditingController();
      _category = widget.initialCategory;
      if (_category?.defaultAmount != null) {
        _amount = _category!.defaultAmount!.toInt().toString();
        _amountCtrl.text = '₹ $_amount';
        _amountCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _amountCtrl.text.length));
      }
    }
    // Keep focus on amount field so cursor is always visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.isNotEmpty)
          _amount = _amount.substring(0, _amount.length - 1);
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount.length < 8) _amount += key;
      }
      _amountCtrl.text = _amount.isEmpty ? '' : '₹ $_amount';
      _amountCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _amountCtrl.text.length));
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category')));
      return;
    }
    final fs = ref.read(firestoreServiceProvider);
    final txn = MoneyTransaction(
      id: widget.existing?.id ?? '',
      categoryId: _category!.id,
      categoryName: _category!.name,
      bucket: _category!.bucket,
      amount: amount,
      note: _note,
      date: _date,
    );
    if (_isEdit) {
      await fs.updateTransaction(txn);
    } else {
      await fs.addTransaction(txn);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    final picked = await showModalBottomSheet<AppCategory>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryPickerSheet(categories: cats, current: _category),
    );
    if (picked != null) setState(() => _category = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _category?.color ?? const Color(0xFFBF6080);
    final isToday = _date.year == DateTime.now().year &&
        _date.month == DateTime.now().month &&
        _date.day == DateTime.now().day;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 12),
        // Sheet title
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_isEdit ? '✏️' : '💸', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(_isEdit ? 'Edit Expense' : 'Log Expense',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF3D1A24))),
        ]),
        const SizedBox(height: 16),

        // Category selector
        GestureDetector(
          onTap: _pickCategory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: catColor.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: catColor.withAlpha(60)),
            ),
            child: Row(children: [
              Icon(_category?.icon ?? Icons.category_outlined,
                  color: catColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _category?.name ?? 'Tap to select category',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _category == null ? Colors.grey : null),
                ),
              ),
              if (_category != null && _category!.isRecurring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: catColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.repeat, size: 10, color: catColor),
                    const SizedBox(width: 3),
                    Text('recurring',
                        style: TextStyle(fontSize: 9, color: catColor)),
                  ]),
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: catColor),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Amount display with blinking cursor
        GestureDetector(
          onTap: () => _amountFocus.requestFocus(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: catColor.withAlpha(80)),
            ),
            child: TextField(
              controller: _amountCtrl,
              focusNode: _amountFocus,
              readOnly: true,
              showCursor: true,
              cursorColor: catColor,
              cursorWidth: 2.5,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: _amount.isEmpty ? Colors.grey.shade400 : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: '₹ 0',
                hintStyle: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade300),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Note + date row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Note (optional)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => _note = v,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_outlined, size: 14),
                const SizedBox(width: 6),
                Text(
                  isToday ? 'Today' : DateFormat('dd MMM').format(_date),
                  style: const TextStyle(fontSize: 13),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Numpad
        _NumPad(onKey: _onKey),
        const SizedBox(height: 12),

        // Save button
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4748E), Color(0xFFBF6080)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBF6080).withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _save,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_isEdit ? '✅' : '💾', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(_isEdit ? 'UPDATE' : 'SAVE',
                    style: const TextStyle(fontSize: 16, letterSpacing: 1)),
              ]),
            ),
          ),
        ),
      ]),
    ));
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  final void Function(String) onKey;
  const _NumPad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) => Row(
        children: row.map((k) {
          final isBack = k == '⌫';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: isBack
                    ? Colors.red.shade50
                    : const Color(0xFFFFF0F3),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onKey(k),
                  child: SizedBox(
                    height: 56,
                    child: Center(
                      child: isBack
                          ? const Icon(Icons.backspace_outlined,
                              color: Colors.red, size: 20)
                          : Text(k,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }
}

// ── Category picker (grouped) ─────────────────────────────────────────────────

class _CategoryPickerSheet extends StatelessWidget {
  final List<AppCategory> categories;
  final AppCategory? current;
  const _CategoryPickerSheet({required this.categories, this.current});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<AppCategory>>{};
    for (final cat in categories) {
      grouped.putIfAbsent(cat.bucket, () => []).add(cat);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Expanded(
              child: Text('Select Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: ctrl,
            children: bucketOrder.map((bucket) {
              final cats = grouped[bucket];
              if (cats == null || cats.isEmpty) return const SizedBox();
              final color = bucketColors[bucket]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(bucketNames[bucket] ?? bucket,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: color)),
                  ),
                  ...cats.map((cat) => ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withAlpha(20),
                          child: Icon(cat.icon, size: 16, color: color),
                        ),
                        title: Text(cat.name,
                            style: const TextStyle(fontSize: 14)),
                        trailing: cat.id == current?.id
                            ? Icon(Icons.check, color: color)
                            : null,
                        onTap: () => Navigator.pop(context, cat),
                      )),
                ],
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
