import 'dart:io';
import '../utils/logger/app_logger.dart';
import '/src/enums.dart';
import 'package:yaml/yaml.dart';

/// Configuration object containing all user settings (paths, patterns, etc.)
class SlangItConfig {
  final String i18nDir, translationFile, pattern;
  final List<String> locales, include, exclude;
  final bool runSlangAfter, preserveFormatting, useAbsolutePath;
  late TranslationFileType translationFileType;

  SlangItConfig({
    this.i18nDir = 'lib/i18n',
    this.locales = const ['en'],
    this.translationFile = 'strings.g.dart',
    this.pattern = 'slang_it',
    List<String>? include,
    List<String>? exclude,
    this.runSlangAfter = true,
    this.preserveFormatting = true,
    this.useAbsolutePath = true,
    String translationFilename = 'json',
  })  : include = include ?? <String>['lib/**/*.dart'],
        exclude = exclude ??
            <String>[
              'lib/generated/**',
              '**/*.g.dart',
              '**/*.freezed.dart',
              '**/*.gr.dart',
            ] {
    translationFileType =
        TranslationFileTypeConverter.fromString(translationFilename);
  }

  // Build the regex pattern that matches our slang_it syntax
  //
  // The pattern is built dynamically using config.pattern to support
  // custom prefixes (users might want t_ or tr instead of slang_it)
  //
  // Pattern breakdown:
  // ─────────────────────────────────────────────────────────────
  // ${config.pattern}\.   → Matches "slang_it." (or custom pattern)
  //                          The backslash escapes the dot so it's literal
  //
  // ([\w.]+)             → CAPTURE GROUP 1: The key path
  //                         \w = word characters (a-z, A-Z, 0-9, _)
  //                         . = literal dot (for nested keys)
  //                         + = one or more characters
  //                         Examples: "home", "home.title", "settings.profile.name"
  //
  // \s*                  → Optional whitespace (spaces, tabs, newlines)
  //                         Allows slang_it.key 'value' or slang_it.key'value'
  //
  // ['"]                 → Match either single quote ' or double quote "
  //                         This is the opening quote of the string
  //
  // ([^'"\\]*            → CAPTURE GROUP 2: The translation value (start)
  //                         [^'"\\] = match any char EXCEPT quotes and backslash
  //                         * = zero or more times
  //                         This handles the main content of the string
  //
  // (?:\\.               → Match escaped characters (non-capturing group)
  //                         ?: makes it non-capturing (we don't need it separately)
  //                         \\ matches a backslash
  //                         . matches any character after the backslash
  //                         This handles \', \", \\, \n, etc.
  //
  // [^'"\\]*)*           → Continue matching non-special characters
  //                         After each escaped char, continue matching normal chars
  //                         )* = zero or more repetitions of the escape sequence
  //
  // ['"]                 → Match closing quote (single or double)
  //                         Should match the type of opening quote
  // ─────────────────────────────────────────────────────────────
  //
  // Examples that match:
  // - slang_it.home.title'Home'
  // - slang_it.message"Hello World"
  // - slang_it.text'It\'s working!'
  // - slang_it.key 'Value with spaces'
  // - slang_it.multi.line.key'Value'
  //
  // multiLine: true allows the pattern to work across multiple lines
  // This is important for code formatted across multiple lines

  RegExp get regxPattern {
    return RegExp(
      pattern + r'''\.([\w.]+)\s*['"]([^'"\\]*(?:\\.[^'"\\]*)*)['"]''',
      multiLine: true,
    );
  }

  /// Load configuration from YAML file
  factory SlangItConfig.load(String configPath) {
    final File file = File(configPath);

    // Use defaults if config file doesn't exist
    if (!file.existsSync()) {
      return SlangItConfig();
    }

    try {
      final YamlMap yaml = loadYaml(file.readAsStringSync()) as YamlMap;

      return SlangItConfig(
        i18nDir: yaml['i18n_dir'] as String? ?? 'lib/i18n',
        locales:
            (yaml['locales'] as YamlList?)?.map((e) => e.toString()).toList() ??
                ['en'],
        translationFile:
            yaml['translation_file'] as String? ?? 'strings.g.dart',
        pattern: yaml['pattern'] as String? ?? 'slang_it',
        include:
            (yaml['include'] as YamlList?)?.map((e) => e.toString()).toList(),
        exclude:
            (yaml['exclude'] as YamlList?)?.map((e) => e.toString()).toList(),
        runSlangAfter: yaml['run_slang_after'] as bool? ?? true,
        preserveFormatting: yaml['preserve_formatting'] as bool? ?? true,
        useAbsolutePath: yaml['use_absolute_path'] as bool? ?? true,
      );
    } catch (e) {
      ('⚠️  Warning: Failed to parse config file, using defaults: $e');
      return SlangItConfig();
    }
  }

  /// Create default config file
  static Future<void> createDefaultConfig(String path) async {
    final File file = File(path);
    await file.writeAsString(_defaultConfigYaml);
    MyAppLogger.getLogger('SlangIt').i('✅ Created default config at $path');
  }

  static const String _defaultConfigYaml = '''
# slang_it configuration

# Directory where i18n files are located
i18n_dir: lib/i18n

# Base locale
locales:
  - en
  - es

# Generated translation file name (created by slang)
translation_file: strings.g.dart

# Pattern to match (use this prefix in your code)
pattern: slang_it

# Files to scan (glob patterns)
include:
  - lib/**/*.dart

# Files to exclude
exclude:
  - lib/generated/**
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.gr.dart"

# Run 'dart run slang' after extraction
run_slang_after: true

# Preserve code formatting and comments
preserve_formatting: true
''';
}
