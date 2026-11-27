import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

/// Opens the song categories management page (Verwaltung › Werk-Kategorien).
Future<void> showSongCategoriesSheet(BuildContext context, {bool readOnly = false}) async {
  await context.push(RedesignRoutes.workCategories);
}
