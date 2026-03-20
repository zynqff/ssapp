import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline, width: 0.8),
            ),
            child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Конфиденциальность',
          style: GoogleFonts.playfairDisplay(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PolicySection(
              title: 'Какие данные мы собираем',
              body:
                  'Имя пользователя и пароль (в виде bcrypt-хэша) при регистрации. '
                  'Адрес электронной почты при входе через Google. '
                  'Список прочитанных стихотворений, закреплённое стихотворение, '
                  'заметки и настройки интерфейса. '
                  'Сообщения в AI-чате (хранятся последние 40 сообщений).',
            ),
            _PolicySection(
              title: 'Как мы используем данные',
              body:
                  'Данные используются исключительно для работы приложения: '
                  'авторизации, синхронизации прогресса и работы AI-ассистента. '
                  'Мы не продаём данные, не используем их для рекламы '
                  'и не передаём третьим лицам без необходимости.',
            ),
            _PolicySection(
              title: 'Третьи стороны',
              body:
                  '• Supabase — хранение аккаунтов и данных приложения.\n'
                  '• Groq API — обработка сообщений AI-чата '
                  '(ваши сообщения передаются для формирования ответа).\n'
                  '• Google Sign-In — вход через аккаунт Google.\n'
                  '• Google Fonts — загрузка шрифтов при первом запуске.',
            ),
            _PolicySection(
              title: 'Хранение данных',
              body:
                  'Данные хранятся на серверах Supabase до удаления аккаунта. '
                  'На устройстве: список стихов и история чата хранятся в локальной '
                  'базе данных SQLite. Токен авторизации — в защищённом хранилище '
                  'Android (Keystore). История чата удаляется при выходе из аккаунта.',
            ),
            _PolicySection(
              title: 'Безопасность',
              body:
                  'Пароли хранятся в виде bcrypt-хэша — восстановить их невозможно. '
                  'Соединение с сервером защищено HTTPS. '
                  'Токен авторизации действует 24 часа.',
            ),
            _PolicySection(
              title: 'Ваши права',
              body:
                  'Вы можете запросить удаление аккаунта и всех связанных данных. '
                  'Для этого напишите нам на контактный адрес — данные будут '
                  'удалены в течение 30 дней.',
            ),
            _PolicySection(
              title: 'Дети',
              body:
                  'Приложение не предназначено для детей до 13 лет. '
                  'Мы не собираем данные несовершеннолетних намеренно.',
            ),
            _PolicySection(
              title: 'Контакт',
              body: 'По вопросам конфиденциальности: [email@example.com]',
            ),
            const SizedBox(height: 8),
            Text(
              'Версия: 1.0 · Вступает в силу: [дата публикации]',
              style: GoogleFonts.notoSerif(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.notoSerif(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
