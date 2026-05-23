import 'package:flutter/foundation.dart';

@immutable
class BudgetData {
  const BudgetData({
    required this.name,
    required this.type,
    this.emoji,
    this.parent,
  });

  final String name;
  final String type; // "vendor" | "account" | "category" | "sub_category" | "payment"
  final String? emoji;
  final String? parent;

  factory BudgetData.fromMap(Map<String, dynamic> data) => BudgetData(
        name: data['name'] as String? ?? '',
        type: data['type'] as String? ?? '',
        emoji: data['emoji'] as String?,
        parent: data['parent'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        if (emoji != null) 'emoji': emoji,
        if (parent != null) 'parent': parent,
      };
}
