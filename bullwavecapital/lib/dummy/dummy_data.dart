import '../models/user_model.dart';
import '../models/portfolio_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/investment_model.dart';
import '../models/notification_model.dart';
import '../models/support_model.dart';
import '../models/referral_model.dart';
import '../models/market_index_model.dart';

class DummyData {
  DummyData._();

  static const UserModel user = UserModel(
    id: 'USR001',
    name: 'Rahul Sharma',
    phone: '+91 98765 43210',
    email: 'rahul.sharma@email.com',
    panStatus: 'Verified',
    kycStatus: 'Completed',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
  );

  static const PortfolioModel portfolio = PortfolioModel(
    totalInvestment: 2500000,
    currentValue: 2875000,
    monthlyProfit: 42500,
    totalProfit: 375000,
    growthPercent: 15.0,
  );

  static const WalletModel wallet = WalletModel(
    balance: 125000,
    bankName: 'HDFC Bank',
    accountNumber: '****4521',
    ifsc: 'HDFC0001234',
  );

  static const InvestmentPlanModel defaultPlan = InvestmentPlanModel(
    id: 'PLAN001',
    name: 'BullWave Premium Plan',
    minimumInvestment: 1000000,
    monthlyReturnRate: 1.5,
    annualReturnRate: 18.0,
    description: 'High-yield investment plan with monthly returns',
    isFeatured: true,
  );

  static final List<InvestmentPlanModel> featuredPlans = [
    defaultPlan,
    const InvestmentPlanModel(
      id: 'PLAN002',
      name: 'BullWave Growth Plan',
      minimumInvestment: 500000,
      monthlyReturnRate: 1.2,
      annualReturnRate: 14.4,
      description: 'Balanced growth with moderate risk',
      isFeatured: true,
    ),
    const InvestmentPlanModel(
      id: 'PLAN003',
      name: 'BullWave Elite Plan',
      minimumInvestment: 5000000,
      monthlyReturnRate: 2.0,
      annualReturnRate: 24.0,
      description: 'Premium plan for high net worth investors',
      isFeatured: true,
    ),
  ];

  static final List<TransactionModel> transactions = [
    TransactionModel(
      id: 'TXN001',
      referenceId: 'BW-2024-001234',
      type: TransactionType.investment,
      status: TransactionStatus.completed,
      amount: 1000000,
      date: DateTime(2024, 11, 15),
      description: 'Premium Plan Investment',
    ),
    TransactionModel(
      id: 'TXN002',
      referenceId: 'BW-2024-001235',
      type: TransactionType.profit,
      status: TransactionStatus.completed,
      amount: 15000,
      date: DateTime(2024, 12, 1),
      description: 'Monthly Profit Credit',
    ),
    TransactionModel(
      id: 'TXN003',
      referenceId: 'BW-2024-001236',
      type: TransactionType.withdrawal,
      status: TransactionStatus.completed,
      amount: 50000,
      date: DateTime(2024, 12, 10),
      description: 'Wallet Withdrawal',
    ),
    TransactionModel(
      id: 'TXN004',
      referenceId: 'BW-2024-001237',
      type: TransactionType.investment,
      status: TransactionStatus.pending,
      amount: 500000,
      date: DateTime(2024, 12, 20),
      description: 'Growth Plan Investment',
    ),
    TransactionModel(
      id: 'TXN005',
      referenceId: 'BW-2024-001238',
      type: TransactionType.profit,
      status: TransactionStatus.completed,
      amount: 27500,
      date: DateTime(2025, 1, 1),
      description: 'Monthly Profit Credit',
    ),
    TransactionModel(
      id: 'TXN006',
      referenceId: 'BW-2024-001239',
      type: TransactionType.withdrawal,
      status: TransactionStatus.failed,
      amount: 100000,
      date: DateTime(2025, 1, 5),
      description: 'Withdrawal Failed - Bank Error',
    ),
  ];

  static final List<WalletTransaction> walletTransactions = [
    WalletTransaction(
      id: 'WTX001',
      type: 'Deposit',
      amount: 200000,
      date: DateTime(2024, 10, 1),
      status: 'Completed',
    ),
    WalletTransaction(
      id: 'WTX002',
      type: 'Withdrawal',
      amount: 50000,
      date: DateTime(2024, 12, 10),
      status: 'Completed',
    ),
    WalletTransaction(
      id: 'WTX003',
      type: 'Profit Credit',
      amount: 15000,
      date: DateTime(2024, 12, 1),
      status: 'Completed',
    ),
    WalletTransaction(
      id: 'WTX004',
      type: 'Deposit',
      amount: 75000,
      date: DateTime(2025, 1, 15),
      status: 'Pending',
    ),
  ];

  static final List<NotificationModel> notifications = [
    NotificationModel(
      id: 'NOT001',
      title: 'Monthly Profit Credited',
      message: '₹27,500 has been credited to your wallet as monthly profit.',
      date: DateTime(2025, 1, 1, 9, 0),
      isRead: false,
      type: 'profit',
    ),
    NotificationModel(
      id: 'NOT002',
      title: 'Investment Successful',
      message: 'Your investment of ₹10,00,000 in Premium Plan is confirmed.',
      date: DateTime(2024, 11, 15, 14, 30),
      isRead: true,
      type: 'investment',
    ),
    NotificationModel(
      id: 'NOT003',
      title: 'KYC Verified',
      message: 'Your KYC verification has been completed successfully.',
      date: DateTime(2024, 10, 20, 11, 0),
      isRead: true,
      type: 'kyc',
    ),
    NotificationModel(
      id: 'NOT004',
      title: 'Market Update',
      message: 'Nifty 50 gained 1.2% today. Check your portfolio performance.',
      date: DateTime(2025, 1, 20, 16, 0),
      isRead: false,
      type: 'market',
    ),
    NotificationModel(
      id: 'NOT005',
      title: 'Referral Reward',
      message: 'You earned ₹5,000 for referring Priya Mehta.',
      date: DateTime(2024, 12, 5, 10, 0),
      isRead: true,
      type: 'referral',
    ),
  ];

  static final List<SupportFaq> supportFaqs = [
    const SupportFaq(
      question: 'What is the minimum investment amount?',
      answer:
          'The minimum investment amount is ₹10,00,000 for our Premium Plan. Other plans may have different minimums.',
    ),
    const SupportFaq(
      question: 'How are returns calculated?',
      answer:
          'Returns are calculated monthly based on your investment amount and the plan\'s return rate. Profits are credited to your wallet.',
    ),
    const SupportFaq(
      question: 'How long does withdrawal take?',
      answer:
          'Withdrawals are processed within 2-3 business days and credited to your registered bank account.',
    ),
    const SupportFaq(
      question: 'Is my investment secure?',
      answer:
          'Yes, all investments are backed by regulated financial instruments and we follow strict compliance guidelines.',
    ),
  ];

  static final List<SupportTicketModel> supportTickets = [
    SupportTicketModel(
      id: 'TKT001',
      subject: 'Withdrawal delay inquiry',
      status: 'Resolved',
      createdAt: DateTime(2024, 12, 12),
    ),
    SupportTicketModel(
      id: 'TKT002',
      subject: 'KYC document update',
      status: 'Open',
      createdAt: DateTime(2025, 1, 10),
    ),
  ];

  static final ReferralModel referral = ReferralModel(
    code: 'RAHUL2024',
    totalReferrals: 5,
    pendingReferrals: 1,
    totalRewards: 2500,
    rewardPerReferral: 500,
    shareMessage: 'Join me on BullWave Invest! Use code RAHUL2024',
    hasAppliedReferral: false,
    appliedReferralCode: '',
    rewardsHistory: [
      ReferralReward(
        friendName: 'Priya Mehta',
        amount: 500,
        date: DateTime(2024, 12, 5),
      ),
      ReferralReward(
        friendName: 'Amit Patel',
        amount: 500,
        date: DateTime(2024, 11, 20),
      ),
    ],
    referredFriends: [
      ReferredFriend(
        name: 'Priya Mehta',
        joinedAt: DateTime(2024, 12, 5),
        status: 'rewarded',
      ),
      ReferredFriend(
        name: 'Sneha Reddy',
        joinedAt: DateTime(2024, 10, 15),
        status: 'pending',
      ),
    ],
  );

  static final List<AllocationItem> allocations = [
    const AllocationItem(label: 'Premium Plan', percentage: 60, colorValue: 0xFF1B3A6B),
    const AllocationItem(label: 'Growth Plan', percentage: 25, colorValue: 0xFF10B981),
    const AllocationItem(label: 'Elite Plan', percentage: 15, colorValue: 0xFF2E5090),
  ];

  static final List<MonthlyEarning> monthlyEarnings = [
    const MonthlyEarning(month: 'Aug', amount: 35000),
    const MonthlyEarning(month: 'Sep', amount: 38000),
    const MonthlyEarning(month: 'Oct', amount: 40000),
    const MonthlyEarning(month: 'Nov', amount: 42000),
    const MonthlyEarning(month: 'Dec', amount: 42500),
    const MonthlyEarning(month: 'Jan', amount: 45000),
  ];

  static final List<FaqItem> investmentFaqs = [
    FaqItem(
      question: 'What returns can I expect?',
      answer:
          'Our Premium Plan offers up to 18% annual returns, credited monthly to your wallet.',
    ),
    FaqItem(
      question: 'Can I withdraw anytime?',
      answer:
          'Yes, you can withdraw your profits anytime. Principal withdrawal is subject to plan terms.',
    ),
    FaqItem(
      question: 'What documents are required?',
      answer: 'PAN, Aadhaar, bank details, and a selfie for KYC verification are required.',
    ),
  ];

  static final InvestmentDetailModel sampleInvestment = InvestmentDetailModel(
    id: 'INV001',
    amount: 1000000,
    date: DateTime(2024, 11, 15),
    monthlyReturn: 15000,
    status: 'Active',
    documents: ['Investment Agreement', 'Receipt', 'Terms & Conditions'],
  );

  static const List<MarketIndexModel> marketIndices = [
    MarketIndexModel(
      id: 'NIFTY50',
      name: 'Nifty 50',
      shortName: 'NIFTY',
      value: 24832.45,
      change: 156.30,
      changePercent: 0.63,
    ),
    MarketIndexModel(
      id: 'SENSEX',
      name: 'Sensex',
      shortName: 'SENSEX',
      value: 81524.78,
      change: 582.15,
      changePercent: 0.72,
    ),
    MarketIndexModel(
      id: 'BANKNIFTY',
      name: 'Bank Nifty',
      shortName: 'BANK NIFTY',
      value: 52318.60,
      change: -124.40,
      changePercent: -0.24,
    ),
  ];

  static const List<Map<String, String>> marketNews = [
    {
      'title': 'Nifty 50 hits new all-time high',
      'subtitle': 'Markets rally on strong FII inflows',
    },
    {
      'title': 'RBI keeps repo rate unchanged',
      'subtitle': 'Policy stance remains accommodative',
    },
    {
      'title': 'Gold prices surge 2%',
      'subtitle': 'Safe haven demand rises globally',
    },
  ];

  static const List<Map<String, String>> kycSteps = [
    {'title': 'Upload PAN', 'key': 'pan'},
    {'title': 'Upload Aadhaar Front', 'key': 'aadhaar_front'},
    {'title': 'Upload Aadhaar Back', 'key': 'aadhaar_back'},
    {'title': 'Selfie Upload', 'key': 'selfie'},
    {'title': 'Address Proof', 'key': 'address'},
  ];
}
