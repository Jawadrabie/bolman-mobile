import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/settings_cubit.dart';
import 'core/config.dart';
import 'core/fcm_service.dart';
import 'features/cubits.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final url = AppConfig.supabaseUrl;
  final key = AppConfig.supabaseAnonKey;
  assert(() {
    // ignore: avoid_print
    print('Bolman Supabase URL: $url');
    return true;
  }());
  await Supabase.initialize(url: url, anonKey: key);
  final settingsCubit = await SettingsCubit.load();
  runApp(MultiBlocProvider(providers: [
    BlocProvider.value(value: settingsCubit),
    BlocProvider(create: (_) => AuthCubit()..bootstrap()),
    // Root-level: the appbar badge and the standalone /notifications page must
    // share one instance, and the page now lives outside both shells.
    BlocProvider(create: (_) => NotificationsCubit()..load()),
  ], child: const BolmanApp()));
  unawaited(FcmService.instance.ensureInitialized());
}
