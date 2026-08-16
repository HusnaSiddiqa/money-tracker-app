import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppCategory {
  final String id;
  final String name;
  final String bucket;
  final String iconKey;
  final bool isRecurring;
  final double? defaultAmount;
  final bool isPinned;
  final int sortOrder;

  const AppCategory({
    required this.id,
    required this.name,
    required this.bucket,
    required this.iconKey,
    required this.isRecurring,
    this.defaultAmount,
    required this.isPinned,
    required this.sortOrder,
  });

  IconData get icon => categoryIcons[iconKey] ?? Icons.circle_outlined;
  Color get color => bucketColors[bucket] ?? Colors.grey;

  factory AppCategory.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppCategory(
      id: doc.id,
      name: d['name'] ?? '',
      bucket: d['bucket'] ?? 'discretionary',
      iconKey: d['icon_key'] ?? 'other',
      isRecurring: d['is_recurring'] ?? false,
      defaultAmount: d['default_amount'] != null
          ? (d['default_amount'] as num).toDouble()
          : null,
      isPinned: d['is_pinned'] ?? false,
      sortOrder: (d['sort_order'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'bucket': bucket,
        'icon_key': iconKey,
        'is_recurring': isRecurring,
        'default_amount': defaultAmount,
        'is_pinned': isPinned,
        'sort_order': sortOrder,
      };

  AppCategory copyWith({
    String? name,
    String? bucket,
    String? iconKey,
    bool? isRecurring,
    Object? defaultAmount = _sentinel,
    bool? isPinned,
    int? sortOrder,
  }) =>
      AppCategory(
        id: id,
        name: name ?? this.name,
        bucket: bucket ?? this.bucket,
        iconKey: iconKey ?? this.iconKey,
        isRecurring: isRecurring ?? this.isRecurring,
        defaultAmount:
            defaultAmount == _sentinel ? this.defaultAmount : defaultAmount as double?,
        isPinned: isPinned ?? this.isPinned,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

const _sentinel = Object();

// ── Bucket definitions ────────────────────────────────────────────────────────

const List<String> bucketOrder = [
  'fixed_needs',
  'variable_needs',
  'family',
  'savings',
  'debt',
  'discretionary',
];

const Map<String, String> bucketNames = {
  'fixed_needs': '🏠 Fixed Needs',
  'variable_needs': '🛒 Daily Needs',
  'family': '👨‍👩‍👧 Family',
  'savings': '📈 Savings',
  'debt': '💳 Debt',
  'discretionary': '🎉 Discretionary',
};

const Map<String, Color> bucketColors = {
  'fixed_needs':    Color(0xFF6B9EC7), // soft blue
  'variable_needs': Color(0xFF5BA07A), // soft green
  'family':         Color(0xFFE07A5F), // soft coral
  'savings':        Color(0xFF3CAEA3), // soft teal
  'debt':           Color(0xFF9B89C4), // soft lavender
  'discretionary':  Color(0xFFF4A261), // soft amber
};

const Map<String, IconData> categoryIcons = {
  'home': Icons.home_outlined,
  'phone': Icons.phone_android_outlined,
  'basket': Icons.shopping_basket_outlined,
  'store': Icons.store_outlined,
  'egg': Icons.egg_outlined,
  'train': Icons.train_outlined,
  'scooter': Icons.electric_scooter_outlined,
  'restaurant': Icons.restaurant_outlined,
  'fish': Icons.set_meal_outlined,
  'school': Icons.school_outlined,
  'child': Icons.child_care_outlined,
  'assignment': Icons.assignment_outlined,
  'phone_family': Icons.phone_outlined,
  'docs': Icons.description_outlined,
  'flight': Icons.flight_outlined,
  'gift': Icons.card_giftcard_outlined,
  'savings': Icons.savings_outlined,
  'trending': Icons.trending_up_outlined,
  'flag': Icons.flag_outlined,
  'credit': Icons.credit_card_outlined,
  'dining': Icons.dinner_dining_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'movie': Icons.movie_outlined,
  'badge': Icons.badge_outlined,
  'other': Icons.circle_outlined,
};

// ── Seed categories ───────────────────────────────────────────────────────────

List<AppCategory> get seedCategories => [
      _s('Hostel Fee',          'fixed_needs',   'home',        rec: true, amt: 7000,  ord: 0),
      _s('Self Recharge',       'fixed_needs',   'phone',       rec: true,             ord: 1),
      _s('Groceries',           'variable_needs','basket',      pin: true,             ord: 0),
      _s('Market',              'variable_needs','store',       pin: true,             ord: 1),
      _s('Eggs',                'variable_needs','egg',         pin: true,             ord: 2),
      _s('Metro',               'variable_needs','train',       pin: true,             ord: 3),
      _s('Rapido',              'variable_needs','scooter',     pin: true,             ord: 4),
      _s('Food Combo',          'variable_needs','restaurant',  pin: true,             ord: 5),
      _s('Fish / Meat',         'variable_needs','fish',                               ord: 6),
      _s("Sibling's Fee",       'family',        'school',      rec: true, amt: 5000,  ord: 0),
      _s("Sibling's Pocket Money",'family',      'child',                              ord: 1),
      _s("Brother's Exam Fee",  'family',        'assignment',                         ord: 2),
      _s('Family Recharge',     'family',        'phone_family',rec: true,             ord: 3),
      _s('Passport / Visa Docs','family',        'docs',                               ord: 4),
      _s('Family Travel',       'family',        'flight',                             ord: 5),
      _s('Gifts & Lending',     'family',        'gift',                               ord: 6),
      _s('Chit Fund',           'savings',       'savings',     rec: true, amt: 30000, ord: 0),
      _s('Mutual Fund SIP',     'savings',       'trending',    rec: true, amt: 4000,  ord: 1),
      _s('Goal Contribution',   'savings',       'flag',                               ord: 2),
      _s('Debt EMI',            'debt',          'credit',      rec: true, amt: 1000,  ord: 0),
      _s('Dining Out',          'discretionary', 'dining',                             ord: 0),
      _s('Personal Shopping',   'discretionary', 'shopping',                           ord: 1),
      _s('Entertainment',       'discretionary', 'movie',                              ord: 2),
      _s('Personal Docs',       'discretionary', 'badge',                              ord: 3),
    ];

AppCategory _s(String name, String bucket, String iconKey,
    {bool rec = false, double? amt, bool pin = false, required int ord}) =>
    AppCategory(id: '', name: name, bucket: bucket, iconKey: iconKey,
        isRecurring: rec, defaultAmount: amt, isPinned: pin, sortOrder: ord);
