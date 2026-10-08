enum MovementType { debit, credit }

class Movement {
  final MovementType type;
  final DateTime date;
  final double amount;

  // ✅ Only used for CREDIT (but can exist for any)
  final String? number;
  final String? description;

  Movement({
    required this.type,
    required this.date,
    required this.amount,
    this.number,
    this.description,
  });
}

class Person {
  final String name;
  double value;
  final List<Movement> movements;

  Person({
    required this.name,
    required this.value,
    List<Movement>? movements,
  }) : movements = movements ?? [];
}
