import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'screens/poems_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _App()));
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Сборник Стихов',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _Root(),
    );
  }

  ThemeData _theme(Brightness b) {
    final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4), brightness: b);
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      textTheme: GoogleFonts.notoSerifTextTheme(
          b == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const PoemsScreen(),
      data: (user) => user != null ? const PoemsScreen() : const LoginScreen(),
    );
  }
}
