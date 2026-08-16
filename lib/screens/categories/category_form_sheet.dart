import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_category.dart';
import '../../providers/providers.dart';

const _kPrimary = Color(0xFFBF6080);

Future<void> showCategoryForm(BuildContext context,
    {AppCategory? existing}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CategoryFormSheet(existing: existing),
  );
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final AppCategory? existing;
  const _CategoryFormSheet({this.existing});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _nameCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  String _bucket = 'discretionary';
  String _iconKey = 'other';
  bool _isRecurring = false;
  bool _isPinned = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _bucket = e.bucket;
      _iconKey = e.iconKey;
      _isRecurring = e.isRecurring;
      _isPinned = e.isPinned;
      if (e.defaultAmount != null) _amtCtrl.text = e.defaultAmount!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a category name')));
      return;
    }
    setState(() => _saving = true);

    final defaultAmt =
        _isRecurring && _amtCtrl.text.trim().isNotEmpty
            ? double.tryParse(_amtCtrl.text.trim())
            : null;

    final fs = ref.read(firestoreServiceProvider);

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name: name,
        bucket: _bucket,
        iconKey: _iconKey,
        isRecurring: _isRecurring,
        defaultAmount: defaultAmt,
        isPinned: _isPinned,
      );
      await fs.updateCategory(updated);
    } else {
      final cat = AppCategory(
        id: '',
        name: name,
        bucket: _bucket,
        iconKey: _iconKey,
        isRecurring: _isRecurring,
        defaultAmount: defaultAmt,
        isPinned: _isPinned,
        sortOrder: 99,
      );
      await fs.addCategory(cat);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete category?'),
        content: Text(
            'Delete "${widget.existing!.name}"? Existing transactions will not be removed.'),
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
    if (ok == true && mounted) {
      await ref.read(firestoreServiceProvider).deleteCategory(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.98,
      minChildSize: 0.6,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle + title
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
                Text(
                  _isEdit ? '✏️ Edit Category' : '➕ New Category',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF3D1A24)),
                ),
                const Spacer(),
                if (_isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _delete,
                  ),
              ]),
            ]),
          ),

          // Form body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                // Name
                _Label('Category Name'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('e.g. Metro, Groceries…', Icons.label_outline),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),

                // Bucket
                _Label('Bucket'),
                const SizedBox(height: 8),
                _BucketPicker(
                  selected: _bucket,
                  onSelect: (b) => setState(() => _bucket = b),
                ),
                const SizedBox(height: 20),

                // Icon
                _Label('Icon'),
                const SizedBox(height: 8),
                _IconPicker(
                  selected: _iconKey,
                  bucketColor: bucketColors[_bucket] ?? _kPrimary,
                  onSelect: (k) => setState(() => _iconKey = k),
                ),
                const SizedBox(height: 20),

                // Recurring toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF2D0D8)),
                  ),
                  child: Row(children: [
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Recurring',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Auto-fills every month (rent, SIP, EMI…)',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                    ),
                    Switch(
                      value: _isRecurring,
                      activeThumbColor: _kPrimary,
                      onChanged: (v) => setState(() => _isRecurring = v),
                    ),
                  ]),
                ),

                if (_isRecurring) ...[
                  const SizedBox(height: 12),
                  _Label('Default Amount (₹)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration('e.g. 7000', Icons.currency_rupee),
                  ),
                ],
                const SizedBox(height: 16),

                // Pinned toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF2D0D8)),
                  ),
                  child: Row(children: [
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Pin to Quick Add',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Shows on the home screen strip for fast logging',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ]),
                    ),
                    Switch(
                      value: _isPinned,
                      activeThumbColor: _kPrimary,
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: Container(
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
                              _isEdit ? '✅  Save Changes' : '✨  Add Category',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
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
      );
}

// ── Bucket picker ─────────────────────────────────────────────────────────────

class _BucketPicker extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _BucketPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: bucketOrder.map((key) {
        final color = bucketColors[key]!;
        final isSelected = selected == key;
        return GestureDetector(
          onTap: () => onSelect(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: isSelected ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isSelected) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                bucketNames[key] ?? key,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : color),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── Icon picker ───────────────────────────────────────────────────────────────

class _IconPicker extends StatelessWidget {
  final String selected;
  final Color bucketColor;
  final void Function(String) onSelect;
  const _IconPicker(
      {required this.selected, required this.bucketColor, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final keys = categoryIcons.keys.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keys.map((k) {
        final isSelected = selected == k;
        return GestureDetector(
          onTap: () => onSelect(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isSelected ? bucketColor : bucketColor.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: bucketColor,
                  width: isSelected ? 2 : 0.5),
            ),
            child: Icon(
              categoryIcons[k]!,
              color: isSelected ? Colors.white : bucketColor,
              size: 22,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Label widget ──────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF3D1A24)),
      );
}
