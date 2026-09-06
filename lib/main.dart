import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/auth_state.dart' as app_auth;
import 'app/config.dart';

export 'app/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var hasSession = false;
  if (!AppConfig.useMock) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    // Sessão persistida (ex.: F5 na web) já começa logada — sem isso o
    // roteador chutaria para /login mesmo com sessão válida.
    hasSession = Supabase.instance.client.auth.currentSession != null;
  }

  runApp(ProviderScope(
    overrides: [
      app_auth.authStateProvider
          .overrideWith((ref) => app_auth.AuthState(loggedIn: hasSession)),
    ],
    child: const ProjetoAutoralApp(),
  ));
}
