
class BudgetModel {
  final String id;
  final String category;
  final double monthlyLimit;

  const BudgetModel({
    required this.id,
    required this.category,
    required this.monthlyLimit,
  });

  BudgetModel copyWith({
    String? category,
    double? monthlyLimit,
  }) {
    return BudgetModel(
      id: id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
    );
  }
}
