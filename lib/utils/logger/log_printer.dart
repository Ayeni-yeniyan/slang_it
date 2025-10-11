import 'package:logger/logger.dart';

class AppLogPrinter extends LogPrinter {
  final String className;

  AppLogPrinter({required this.className});

  static final levelColors = {
    Level.trace: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.debug: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.info: const AnsiColor.fg(12), // Blue
    Level.warning: const AnsiColor.fg(208), // Orange
    Level.error: const AnsiColor.fg(196), // Red
    Level.fatal: const AnsiColor.fg(199), // Magenta
  };

  static final levelEmojis = {
    Level.trace: '💬',
    Level.debug: '🐛',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '🚨',
  };

  @override
  List<String> log(LogEvent event) {
    final color = levelColors[event.level] ?? const AnsiColor.none();
    final emoji = levelEmojis[event.level] ?? '';
    final message = event.message;
    final time = DateTime.now();
    return [
      color(
        '[${time.hour}:${time.minute}:${time.second}] '
        '[$className/${event.level.name.toUpperCase()}]$emoji: $message',
      ),
    ];
  }
}
