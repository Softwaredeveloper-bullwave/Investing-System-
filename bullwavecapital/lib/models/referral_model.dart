class ReferralModel {
  final String code;
  final int totalReferrals;
  final int pendingReferrals;
  final double totalRewards;
  final double rewardPerReferral;
  final String shareMessage;
  final bool hasAppliedReferral;
  final String appliedReferralCode;
  final List<ReferralReward> rewardsHistory;
  final List<ReferredFriend> referredFriends;

  const ReferralModel({
    required this.code,
    required this.totalReferrals,
    required this.pendingReferrals,
    required this.totalRewards,
    required this.rewardPerReferral,
    required this.shareMessage,
    required this.hasAppliedReferral,
    required this.appliedReferralCode,
    required this.rewardsHistory,
    required this.referredFriends,
  });
}

class ReferralReward {
  final String friendName;
  final double amount;
  final DateTime date;

  const ReferralReward({
    required this.friendName,
    required this.amount,
    required this.date,
  });
}

class ReferredFriend {
  final String name;
  final DateTime joinedAt;
  final String status;

  const ReferredFriend({
    required this.name,
    required this.joinedAt,
    required this.status,
  });

  bool get isRewarded => status == 'rewarded';
  bool get isPending => status == 'pending';
}

class ApplyReferralResult {
  final bool success;
  final String message;
  final bool rewardCreditedToFriend;

  const ApplyReferralResult({
    required this.success,
    required this.message,
    this.rewardCreditedToFriend = false,
  });
}
