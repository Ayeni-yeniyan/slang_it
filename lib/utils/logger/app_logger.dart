import 'package:logger/logger.dart';
import 'log_printer.dart';

/// MyAppLogger provides a convenient way to create a Logger instance for any class.
/// It uses a custom log printer to format logs with the class name.
///
/// Example usage:
/// ```dart
/// import 'package:your_project/common/utils/utils.dart';
///
/// class MyService {
///   final log = MyAppLogger.getLogger('MyService');
///
///   void doSomething() {
///     log.d('Debug message');
///     log.i('Info message');
///     log.e('Error message');
///   }
/// }
/// ```
///
/// The logger will prefix log messages with the class name and use the debug level by default.
///
abstract class MyAppLogger {
  /// Returns a Logger instance for the given class name.
  ///
  /// [className] is used to prefix log messages for easier tracing.
  static Logger getLogger(String className, {Level? level}) {
    return Logger(
      printer: AppLogPrinter(className: className),
      level: level ?? Level.debug,
    );
  }
}
