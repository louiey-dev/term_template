import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

import '../../features/home/home_screen.dart';
import '../../features/panels/common/not_found_panel.dart';
import '../../features/panels/panel_registry.dart';
import '../theme/app_theme.dart';

/// Global provider configuring declarative application routing via [GoRouter].
final appRouterProvider = Provider<GoRouter>((ref) {
  String lastRoute = '/home/panel/cm_general';
  if (Hive.isBoxOpen('app_settings')) {
    lastRoute =
        Hive.box<String>(
          'app_settings',
        ).get('last_route', defaultValue: '/home/panel/cm_general') ??
        '/home/panel/cm_general';
  }

  final router = GoRouter(
    initialLocation: lastRoute,
    routes: [
      GoRoute(path: '/', redirect: (_, __) => lastRoute),
      ShellRoute(
        builder: (ctx, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) => Center(
              child: Text(
                'Select a panel from the sidebar',
                style: TextStyle(color: ctx.colors.muted),
              ),
            ),
          ),
          GoRoute(
            path: '/home/panel/:panelId',
            builder: (ctx, state) {
              final id = state.pathParameters['panelId']!;
              return panelRegistry[id]?.call() ?? NotFoundPanel(panelId: id);
            },
          ),
        ],
      ),
    ],
  );

  var lastPersisted = lastRoute;
  router.routerDelegate.addListener(() {
    final uriStr = router.routerDelegate.currentConfiguration.uri.toString();
    if (uriStr.startsWith('/home') && uriStr != lastPersisted) {
      lastPersisted = uriStr;
      if (Hive.isBoxOpen('app_settings')) {
        Hive.box<String>('app_settings').put('last_route', uriStr);
      }
    }
  });

  ref.onDispose(router.dispose);
  return router;
});
