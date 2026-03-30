import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

// ── Accent color options ──────────────────────────────────────────────────────

class AccentOption {
  final String label;
  final Color color;
  const AccentOption(this.label, this.color);
}

const accentOptions = [
  AccentOption('Фиолетовый', Color(0xFF9B8EC4)),
  AccentOption('Синий',      Color(0xFF6B9FD4)),
  AccentOption('Бирюзовый',  Color(0xFF5BBFB5)),
  AccentOption('Розовый',    Color(0xFFD47FA6)),
  AccentOption('Оранжевый',  Color(0xFFD49B6B)),
  AccentOption('Зелёный',    Color(0xFF7BBD7A)),
  AccentOption('Красный',    Color(0xFFD46B6B)),
  AccentOption('Золотой',    Color(0xFFD4B86B)),
];

// ── State ─────────────────────────────────────────────────────────────────────

class ThemeState {
  final ThemeMode mode;
  final int accentIndex;
  
  const ThemeState({this.mode = ThemeMode.dark, this.accentIndex = 0});

  Color get accent => accentOptions[accentIndex].color;

  ThemeState copyWith({ThemeMode? mode, int? accentIndex}) => ThemeState(
        mode: mode ?? this.mode,
        accentIndex: accentIndex ?? this.accentIndex,
      );
}

// ── Notifier с @riverpod ─────────────────────────────────────────────────────
// ВАЖНО: класс называется ThemeNotifier, а не Theme
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeState build() {
    _load();
    return const ThemeState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? 1;
    final accentIndex = prefs.getInt('theme_accent') ?? 0;
    
    state = ThemeState(
      mode: ThemeMode.values[modeIndex.clamp(0, 2)],
      accentIndex: accentIndex.clamp(0, accentOptions.length - 1),
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setAccent(int index) async {
    state = state.copyWith(accentIndex: index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_accent', index);
  }
}
