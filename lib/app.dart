import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gitty/core/router/app_router.dart';

class GittyApp extends ConsumerWidget {
  const GittyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Gitty',
      debugShowCheckedModeBanner: false,

      // ── Routing ─────────────────────────────────────────────────────────
      routerConfig: router,

      // ── Light Theme (Material 3) ─────────────────────────────────────────
      theme: FlexThemeData.light(
        scheme: FlexScheme.indigo,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 9,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorUnfocusedHasBorder: true,
          inputDecoratorRadius: 12,
          cardRadius: 12,
          chipRadius: 8,
          dialogRadius: 16,
          bottomSheetRadius: 20,
          navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface,
          navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurface,
          navigationBarSelectedIconSchemeColor: SchemeColor.onSurface,
          navigationBarUnselectedIconSchemeColor: SchemeColor.onSurface,
          navigationBarIndicatorSchemeColor: SchemeColor.secondary,
          navigationBarBackgroundSchemeColor: SchemeColor.surface,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        textTheme: _buildTextTheme(Brightness.light),
      ),

      // ── Dark Theme (Material 3) ──────────────────────────────────────────
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.indigo,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 15,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorUnfocusedHasBorder: true,
          inputDecoratorRadius: 12,
          cardRadius: 12,
          chipRadius: 8,
          dialogRadius: 16,
          bottomSheetRadius: 20,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        textTheme: _buildTextTheme(Brightness.dark),
      ),

      themeMode: ThemeMode.system,
    );
  }

  TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return GoogleFonts.interTextTheme(base);
  }
}
