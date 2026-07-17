class InvestmentPlanModel {
  final String id;
  final String name;
  final double minimumInvestment;
  final double monthlyReturnRate;
  final double monthlyReturnMin;
  final double monthlyReturnMax;
  final double annualReturnRate;
  final String description;
  final bool isFeatured;

  const InvestmentPlanModel({
    required this.id,
    required this.name,
    required this.minimumInvestment,
    required this.monthlyReturnRate,
    this.monthlyReturnMin = 0.2,
    this.monthlyReturnMax = 2.0,
    required this.annualReturnRate,
    required this.description,
    this.isFeatured = false,
  });

  String get monthlyReturnLabel {
    if (monthlyReturnMin > 0 && monthlyReturnMax > monthlyReturnMin) {
      return '${monthlyReturnMin.toStringAsFixed(2)}% – ${monthlyReturnMax.toStringAsFixed(2)}% monthly';
    }
    final rate = monthlyReturnRate > 0 ? monthlyReturnRate : monthlyReturnMin;
    return '${rate.toStringAsFixed(2)}% monthly';
  }

  bool get hasFixedMonthlyReturn =>
      monthlyReturnMin > 0 && (monthlyReturnMax <= monthlyReturnMin || monthlyReturnMax == monthlyReturnRate);
}

class InvestmentDetailModel {
  final String id;
  final double amount;
  final DateTime date;
  final double monthlyReturn;
  final String status;
  final List<String> documents;

  const InvestmentDetailModel({
    required this.id,
    required this.amount,
    required this.date,
    required this.monthlyReturn,
    required this.status,
    required this.documents,
  });
}

class FaqItem {
  final String question;
  final String answer;
  final bool isExpanded;

  FaqItem({
    required this.question,
    required this.answer,
    this.isExpanded = false,
  });

  FaqItem copyWith({bool? isExpanded}) => FaqItem(
        question: question,
        answer: answer,
        isExpanded: isExpanded ?? this.isExpanded,
      );
}
