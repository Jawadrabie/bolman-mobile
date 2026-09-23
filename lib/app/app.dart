import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/fcm_service.dart';
import '../features/cubits.dart';
import 'i18n/l10n.dart';
import 'router.dart';
import 'settings_cubit.dart';
import 'splash_screen.dart';
import 'theme.dart';

class BolmanApp extends StatefulWidget {
  const BolmanApp({super.key});

  @override
  State<BolmanApp> createState() => _BolmanAppState();
}

class _BolmanAppState extends State<BolmanApp> {
  GoRouter? _router;
  AuthRouterRefresh? _refresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router != null) return;
    final auth = context.read<AuthCubit>();
    _refresh = AuthRouterRefresh(auth.stream);
    final router = createAppRouter(auth, _refresh!);
    _router = router;

    // Tapping a push notification opens the notifications screen. Pushed, not
    // go()'d, so the back arrow returns to the screen underneath.
    FcmService.instance.onNotificationTap = () {
      if (!auth.state.authed) return;
      final location = router.routerDelegate.currentConfiguration.uri.path;
      if (location == '/notifications') return;
      router.push('/notifications');
    };
  }

  @override
  void dispose() {
    FcmService.instance.onNotificationTap = null;
    _refresh?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: SplashBootstrap()),
      );
    }
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, s) {
        final light = AppTheme.forLocale(s.locale, Brightness.light);
        final dark = AppTheme.forLocale(s.locale, Brightness.dark);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: s.themeMode,
          locale: Locale(s.locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: s.locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
