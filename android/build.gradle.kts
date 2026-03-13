plugins {
    // Убираем версии здесь — Flutter подставит их сам
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
    // Если у тебя в проекте есть этот плагин, добавь и его (часто нужен для Flutter)
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
}
