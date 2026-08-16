import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';

final _fmt = NumberFormat('#,##,##0', 'en_IN');

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _incomeCtrl = TextEditingController();
  bool _saved = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    final m = ref.read(selectedMonthProvider);
    ref
        .read(firestoreServiceProvider)
        .getMonthlyIncome(m.year, m.month)
        .then((v) {
      if (mounted && v > 0) _incomeCtrl.text = v.toInt().toString();
    });
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    final val = double.tryParse(_incomeCtrl.text.trim()) ?? 0;
    if (val <= 0) return;
    final m = ref.read(selectedMonthProvider);
    await ref
        .read(firestoreServiceProvider)
        .setMonthlyIncome(m.year, m.month, val);
    ref.invalidate(monthlyIncomeProvider);
    setState(() => _saved = true);
    Future.delayed(
        const Duration(seconds: 2),
        () => mounted ? setState(() => _saved = false) : null);
  }

  Future<void> _generateRecurring() async {
    setState(() => _generating = true);
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    final m = ref.read(selectedMonthProvider);
    await ref
        .read(firestoreServiceProvider)
        .generateRecurringEntries(cats, m.year, m.month);
    setState(() => _generating = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring entries created!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final selected = ref.watch(selectedMonthProvider);
    final income = ref.watch(monthlyIncomeProvider).valueOrNull ?? 0;
    final expense = ref.watch(monthExpenseTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFBF6080),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            title: Text(user?.displayName ?? 'Signed in'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Monthly income
          Text('Monthly Income — ${DateFormat('MMM yyyy').format(selected)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Salary / Income (₹)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBF6080)),
            onPressed: _saveIncome,
            icon: Icon(_saved ? Icons.check : Icons.save_outlined),
            label: Text(_saved ? 'Saved!' : 'Save Income'),
          ),
          const SizedBox(height: 20),

          // Summary card
          if (income > 0)
            Card(
              color: const Color(0xFFBF6080),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Income',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('₹${_fmt.format(income)}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ]),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expenses',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('₹${_fmt.format(expense)}',
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ]),
                  const Divider(color: Colors.white24),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('₹${_fmt.format(income - expense)}',
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold)),
                      ]),
                ]),
              ),
            ),
          const SizedBox(height: 20),

          // Recurring entries
          const Text('Recurring Entries',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
              'Auto-create entries for recurring categories (Chit Fund, Hostel Fee, etc.) for ${DateFormat('MMM yyyy').format(selected)}.',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _generating ? null : _generateRecurring,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.repeat),
            label: const Text('Generate Recurring Entries'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Sign out
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (ok == true) await AuthService().signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
