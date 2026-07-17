class SupportTicketModel {
  final String id;
  final String subject;
  final String status;
  final DateTime createdAt;

  const SupportTicketModel({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
  });
}

class SupportFaq {
  final String question;
  final String answer;

  const SupportFaq({required this.question, required this.answer});
}
