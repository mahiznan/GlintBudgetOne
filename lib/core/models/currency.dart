import 'package:flutter/foundation.dart';

@immutable
class Currency {
  const Currency({
    required this.name,
    required this.code,
    required this.symbol,
  });

  final String name;
  final String code;
  final String symbol;

  static const Currency defaults =
      Currency(name: 'US Dollar', code: 'USD', symbol: '\$');

  factory Currency.fromMap(Map<String, dynamic> data) => Currency(
        name: data['name'] as String? ?? '',
        code: data['code'] as String? ?? '',
        symbol: data['symbol'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'code': code,
        'symbol': symbol,
      };

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code && other.name == name && other.symbol == symbol;

  @override
  int get hashCode => Object.hash(name, code, symbol);
}
