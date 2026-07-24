import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Returns true when KYC is fully verified (or user completes flow).
Future<bool> ensureBankVerified(BuildContext context) async {
  final kyc = context.read<KycFlowProvider>();
  await kyc.loadStatus();
  if (kyc.isFullyVerified) return true;
  if (!context.mounted) return false;
  final entryRoute = kyc.status.panVerified ? AppRoutes.kyc : AppRoutes.panVerification;
  // Starting a fresh wizard on top of this screen — depth 1. Every screen
  // further down the wizard (pan -> bank -> name-match, or the status
  // dashboard forwarding to whichever step is next) increments this before
  // pushing, so finishKycFlow() knows exactly how many screens to pop.
  kyc.kycPushDepth = 1;
  final done = await context.push<bool>(entryRoute);
  await kyc.loadStatus();
  return done == true || kyc.isFullyVerified;
}

/// Call this from the final screen of the KYC flow (name-match success /
/// kyc-success / the status dashboard's "Start Investing" button) once
/// verification is complete.
///
/// Every KYC screen (`ensureBankVerified`, the completion banner, the status
/// dashboard, PAN, bank) is reached via `context.push`, stacking one on top
/// of whatever screen the user was on when KYC was triggered — a Buy button,
/// a wallet action, the home banner, Profile, etc. Each of those pushes
/// increments `KycFlowProvider.kycPushDepth`. Popping exactly that many
/// times here returns control straight to that original screen (the trading
/// pad reopens, the wallet screen is still there, etc.) with
/// `kyc.isFullyVerified` already true, so any KYC-gated UI there unlocks
/// immediately — instead of the old `context.go(...)` behaviour, which wiped
/// the caller's screen entirely and never resolved the `push<bool>` Future
/// `ensureBankVerified` was waiting on.
///
/// If there's nothing to pop back to (KYC was reached via a direct router
/// redirect, e.g. deep-linking straight to a trade route while unverified,
/// so nothing was ever pushed), fall back to Home.
void finishKycFlow(BuildContext context) {
  // AuthProvider caches the logged-in user (including `kycStatus`) separately
  // from KycFlowProvider, and only ever refetches it when the Profile screen
  // is (re)built — so without this, the Profile tab's KYC badge and anything
  // else reading `user.kycStatus` would keep showing "not verified" for the
  // rest of the session even though verification just succeeded.
  final kyc = context.read<KycFlowProvider>();
  unawaited(context.read<AuthProvider>().refreshProfile());

  var remaining = kyc.kycPushDepth;
  kyc.kycPushDepth = 0;
  var poppedAny = false;
  while (remaining > 0 && context.canPop()) {
    context.pop(true);
    remaining--;
    poppedAny = true;
  }
  if (!poppedAny) {
    context.go(AppRoutes.home);
  }
}
