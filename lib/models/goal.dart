import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String name;
  final String emoji;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;

  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.savedAmount,
    this.targetDate,
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remaining =>
      (targetAmount - savedAmount).clamp(0, double.infinity);
  bool get isCompleted => savedAmount >= targetAmount;

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Goal(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '🎯',
      targetAmount: (d['target_amount'] ?? 0).toDouble(),
      savedAmount: (d['saved_amount'] ?? 0).toDouble(),
      targetDate: (d['target_date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'target_date':
            targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      };

  Goal copyWith({double? savedAmount}) => Goal(
        id: id,
        name: name,
        emoji: emoji,
        targetAmount: targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        targetDate: targetDate,
      );
}
