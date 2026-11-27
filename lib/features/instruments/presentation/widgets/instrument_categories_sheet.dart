import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

/// Opens the instrument categories management page (Gruppen › Kategorien).
Future<void> showInstrumentCategoriesSheet(BuildContext context) async {
  await context.push(RedesignRoutes.groupCategories);
}
