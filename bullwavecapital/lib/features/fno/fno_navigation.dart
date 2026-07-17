import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import 'presentation/provider/fno_flow_provider.dart';

Future<void> openFnoFeature(BuildContext context, String route, {Map<String, String>? query}) async {
  final fno = context.read<FnoFlowProvider>();
  await fno.ensureLoaded();
  if (!context.mounted) return;
  if (fno.isVerified && fno.error == null) {
    if (query != null && query.isNotEmpty) {
      final uri = Uri(path: route, queryParameters: query);
      context.push(uri.toString());
    } else {
      context.push(route);
    }
  } else {
    context.push(AppRoutes.fnoVerification);
  }
}
