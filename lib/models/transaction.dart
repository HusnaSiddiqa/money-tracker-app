import 'package:cloud_firestore/cloud_firestore.dart';

class MoneyTransaction {
  final String id;
  final String categoryId;
  final String categoryName;
  final String bucket;
  final double amount;
  final String note;
  final DateTime date;
  final bool createdFromRecurring;

  const MoneyTransaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.bucket,
    required this.amount,
    required this.note,
    required this.date,
    this.createdFromRecurring = false,
  });

  factory MoneyTransaction.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MoneyTransaction(
      id: doc.id,
      categoryId: d['category_id'] ?? '',
      categoryName: d['category_name'] ?? '',
      bucket: d['bucket'] ?? 'discretionary',
      amount: (d['amount'] ?? 0).toDouble(),
      note: d['note'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdFromRecurring: d['created_from_recurring'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'category_id': categoryId,
        'category_name': categoryName,
        'bucket': bucket,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(date),
        'created_from_recurring': createdFromRecurring,
      };
}
