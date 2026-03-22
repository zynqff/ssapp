class AppConfig {
  final DateTime? maintenanceUntil;
  final String forceUpdateVersion;
  final bool registrationEnabled;
  final bool aiEnabled;
  final bool googleSigninEnabled;
  final int aiDailyLimit;
  final String bannerText;
  final String bannerColor;

  const AppConfig({
    this.maintenanceUntil,
    this.forceUpdateVersion = '0.0.0',
    this.registrationEnabled = true,
    this.aiEnabled = true,
    this.googleSigninEnabled = true,
    this.aiDailyLimit = 0,
    this.bannerText = '',
    this.bannerColor = 'info',
  });

  /// Дефолтный конфиг — используется если сервер недоступен
  factory AppConfig.defaults() => const AppConfig();

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    DateTime? maintenanceUntil;
    final raw = map['maintenance_until'] as String? ?? '';
    if (raw.isNotEmpty) {
      maintenanceUntil = DateTime.tryParse(raw)?.toLocal();
    }

    return AppConfig(
      maintenanceUntil: maintenanceUntil,
      forceUpdateVersion: map['force_update_version'] as String? ?? '0.0.0',
      registrationEnabled: (map['registration_enabled'] as String?) != 'false',
      aiEnabled: (map['ai_enabled'] as String?) != 'false',
      googleSigninEnabled: (map['google_signin_enabled'] as String?) != 'false',
      aiDailyLimit: int.tryParse(map['ai_daily_limit'] as String? ?? '0') ?? 0,
      bannerText: map['banner_text'] as String? ?? '',
      bannerColor: map['banner_color'] as String? ?? 'info',
    );
  }

  /// Идёт ли сейчас тех. перерыв
  bool get isUnderMaintenance {
    if (maintenanceUntil == null) return false;
    return DateTime.now().isBefore(maintenanceUntil!);
  }

  /// Сколько осталось до конца тех. перерыва
  Duration get maintenanceRemaining {
    if (maintenanceUntil == null) return Duration.zero;
    final diff = maintenanceUntil!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}
