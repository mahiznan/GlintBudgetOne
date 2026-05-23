import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.category,
    required this.subCategory,
    required this.date,
    required this.account,
    required this.vendor,
    required this.payment,
    required this.currency,
    required this.notes,
    required this.amount,
    required this.icon,
  });

  final String id;
  final String userId;
  final String category;
  final String subCategory;
  final DateTime date;
  final String account;
  final String vendor;
  final String payment;
  final String currency;
  final String notes;
  final double amount;
  final String icon;

  factory Transaction.fromMap(String id, Map<String, dynamic> data) {
    final dateRaw = data['date'];
    final date = dateRaw is Timestamp
        ? dateRaw.toDate()
        : dateRaw is DateTime
            ? dateRaw
            : DateTime.now();

    return Transaction(
      id: id,
      userId: data['user_id'] as String? ?? '',
      category: data['category'] as String? ?? '',
      subCategory: data['sub_category'] as String? ?? '',
      date: date,
      account: data['account'] as String? ?? '',
      vendor: data['vendor'] as String? ?? '',
      payment: data['payment'] as String? ?? '',
      currency: data['currency'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      icon: data['icon'] as String? ?? '',
    );
  }

  factory Transaction.fromFirestore(DocumentSnapshot doc) =>
      Transaction.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  Map<String, dynamic> toFirestore() => {
        'user_id': userId,
        'category': category,
        'sub_category': subCategory,
        'date': Timestamp.fromDate(date),
        'account': account,
        'vendor': vendor,
        'payment': payment,
        'currency': currency,
        'notes': notes,
        'amount': amount,
        'icon': icon,
      };
}
