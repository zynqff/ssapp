import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/poems_provider.dart';
import 'screens/poems_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: _App()));
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final accent = themeState.accent;

    return MaterialApp(
      title: 'Сборник Стихов',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light, accent),
      darkTheme: _buildTheme(Brightness.dark, accent),
      themeMode: themeState.mode,
      home: const _Root(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, Color accent) {
    final isDark = brightness == Brightness.dark;

    final bgColor      = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF4F2F8);
    final surfaceColor = isDark ? const Color(0xFF252538) : const Color(0xFFFFFFFF);
    final surfaceVar   = isDark ? const Color(0xFF2E2E45) : const Color(0xFFEDE9F4);
    final onBg         = isDark ? const Color(0xFFE8E0F0) : const Color(0xFF1A1A2E);
    final onSurfaceVar = isDark
        ? Color.lerp(accent, const Color(0xFFE8E0F0), 0.4)!
        : Color.lerp(accent, const Color(0xFF1A1A2E), 0.3)!;
    final outlineColor = isDark ? const Color(0xFF4A4A6A) : const Color(0xFFCCC8DC);

    final cs = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      secondary: Color.lerp(accent, isDark ? Colors.black : Colors.white, 0.25)!,
      onSecondary: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      tertiary: Color.lerp(accent, const Color(0xFFE8E0F0), 0.3)!,
      onTertiary: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      error: const Color(0xFFCF6679),
      onError: Colors.white,
      background: bgColor,
      onBackground: onBg,
      surface: surfaceColor,
      onSurface: onBg,
      surfaceVariant: surfaceVar,
      onSurfaceVariant: onSurfaceVar,
      outline: outlineColor,
    );

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: onBg,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: onBg, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.only(bottom: 10),
      ),
      textTheme: GoogleFonts.notoSerifTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        titleMedium: GoogleFonts.playfairDisplay(
          color: onBg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.notoSerif(
          color: accent,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        bodySmall: GoogleFonts.notoSerif(
          color: onSurfaceVar,
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.notoSerif(color: onSurfaceVar),
        border: InputBorder.none,
        labelStyle: GoogleFonts.notoSerif(color: onSurfaceVar),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      // Показываем loading только при реально первом входе (нет локальных данных)
      loading: () => const _ConnectingScreen(),
      error: (e, _) => _ServerErrorScreen(message: e.toString()),
      data: (user) =>
          user != null ? const PoemsScreen() : const LoginScreen(),
    );
  }
}

// Экран "Подключение к серверу..." — показывается только при первом входе
class _ConnectingScreen extends ConsumerWidget {
  const _ConnectingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.primary.withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              child: Icon(Icons.menu_book_outlined, size: 34, color: cs.primary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Подключение к серверу...',
              style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Первый запуск может занять до 30 секунд',
              style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Экран ошибки подключения — с кнопкой повтора
class _ServerErrorScreen extends ConsumerWidget {
  final String message;
  const _ServerErrorScreen({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 56, color: cs.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  // Переинициализируем провайдер
                  ref.invalidate(authProvider);
                  ref.invalidate(poemsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Повторить',
                  style: GoogleFonts.notoSerif(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Открыть экран входа без сервера — нельзя, но можно посмотреть стихи офлайн
                  // если уже были данные (этот экран не покажется в таком случае)
                },
                child: Text(
                  'Попробовать позже',
                  style: GoogleFonts.notoSerif(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
