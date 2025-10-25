/// Main processor that orchestrates the entire slang_it workflow.
///
/// This class is responsible for:
/// 1. Finding Dart files to process
/// 2. Extracting translations from those files
/// 3. Updating the JSON file with new translations
/// 4. Running the slang command to generate translation code
/// 5. Transforming source files to replace slang_it calls with t calls
///
/// It supports both one-time processing and watch mode for continuous development.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '/src/enums.dart';
import '/utils/logger/app_logger.dart';
import 'package:watcher/watcher.dart';
import 'config.dart';
import 'extractor.dart';
import 'transformer.dart';

/// The main processor class that coordinates all slang_it operations
class SlangItProcessor {
  static final _logger = MyAppLogger.getLogger('SlangItProcessor');

  final SlangItConfig config;

  /// If true, shows what would happen without actually modifying files
  final bool dryRun;

  /// If true, creates .bak backup files before modifying originals
  final bool backup;

  /// If true, prompts user for confirmation before making changes
  final bool interactive;

  SlangItProcessor({
    required this.config,
    this.dryRun = false,
    this.backup = false,
    this.interactive = false,
  });

  /// Process files once (non-watch mode)
  ///
  /// This is the main entry point for single-run processing.
  /// Takes a list of paths (files or directories) to process.
  Future<void> slangItProcess(List<String> paths) async {
    _logger.i('🔍 Timeee to slang_it, damn it!\n');
    final files = await _findDartFiles(paths);
    if (files.isEmpty) {
      _logger.w('✨ No Dart files found');
      return;
    }
    _logger.i('📝 Found ${files.length} Dart file(s)\n');

    // Extract translations from all files
    final extractor = TranslationExtractor(config);

    Map<String, dynamic> translations = <String, dynamic>{};

    // Track which files actually contain translations (for transformation step)
    final filesWithTranslations = <File>[];

    // Loop through each file and extract its translations
    for (final file in files) {
      // Extract returns a map of translations found in this specific file
      final extracted = await extractor.extractFromFile(file);
      // If this file has translations, track it for later transformation
      if (extracted.isNotEmpty) {
        filesWithTranslations.add(file);
        translations = _deepMerge(translations, extracted);
      }
    }

    if (translations.isEmpty) {
      _logger.w('There is nothing to slang_it, damn it!');
      return;
    }

    // Count total number of translation keys (including nested ones)
    final count = _countKeys(translations);
    _logger.i(
      'Found $count translation(s) in ${filesWithTranslations.length} file(s)\n',
    );

    // If dry-run mode, show what would happen and exit without modifying
    if (dryRun) {
      _showDryRun(translations, filesWithTranslations);
      return;
    }

    // If interactive mode, ask user for confirmation before proceeding
    if (interactive) {
      // Prompt user for yes/no response
      stdout.write('Continue with extraction and transformation? [y/n] ');
      final response = stdin.readLineSync();
      // If user doesn't explicitly say yes, cancel the operation
      if (response?.toLowerCase() != 'y') {
        _logger.f(' slang_it process cancelled by user');
        return;
      }
    }

    await _updateTranslationFile(translations);

    // Step 4: Run 'dart run slang' to generate translation code
    // This only runs if configured to do so (default: true)
    if (config.runSlangAfter) {
      await _runSlang();
    }

    final transformer = SourceTransformer(config);
    for (final file in filesWithTranslations) {
      // If backup mode, create a .bak file before modifying
      if (backup) {
        _logger.d('Creating backup for ${file.path}');
        await _backupFile(file);
      }

      // Transform the file (modify it in place)
      await transformer.transformFile(file);
    }

    // Print success message with count of transformed files
    _logger.i('\n✅ Done! Transformed ${filesWithTranslations.length} file(s)');
  }

  /// Watch mode - continuously monitor file changes and process them
  ///
  /// This is useful during development so translations are automatically
  /// extracted and code is transformed as you work.
  Future<void> slangItWatch(List<String> paths) async {
    // Do an initial full processing run before starting to watch
    await slangItProcess(paths);

    // Inform user that watch mode is active
    _logger.i('\n👀 Watching for changes...\n');
    if (paths.isEmpty) {
      paths = ['lib'];
    }
    final path = paths.first;
    final dir = Directory(path.split(p.normalize(path)).first);

    // Create a watcher for this directory that monitors all changes recursively
    final watcher = DirectoryWatcher(dir.path);

    // Listen to file change events
    watcher.events.listen((event) async {
      if (event.type == ChangeType.MODIFY || event.type == ChangeType.ADD) {
        // Only process Dart files that aren't excluded
        if (event.path.endsWith('.dart') && !_shouldExclude(event.path)) {
          // Show which file changed
          _logger.i('\n📄 Change detected: ${p.relative(event.path)}');

          try {
            await _processFile(File(event.path));
          } catch (e) {
            // Don't crash watch mode on errors - just log and continue
            _logger.e('❌ Error processing file: $e');
          }
        }
      }
    });
    // This prevents the watch mode from exiting
    await Future.delayed(const Duration(days: 1));
  }

  /// Process a single file (used in watch mode)
  ///
  /// This is a lighter version of process() that only handles one file
  /// instead of scanning everything.
  Future<void> _processFile(File file) async {
    // Extract translations from just this one file
    final extractor = TranslationExtractor(config);
    final translations = await extractor.extractFromFile(file);

    // If no translations found in this file, nothing to do
    if (translations.isEmpty) return;

    // Update the JSON file with the new translations
    await _updateTranslationFile(translations);

    // Run slang to regenerate translation code
    if (config.runSlangAfter) {
      await _runSlang();
    }

    // Transform the file to replace slang_it with t
    final transformer = SourceTransformer(config);
    await transformer.transformFile(file);

    // Simple success message (less verbose than full processing)
    _logger.d('✅ slang_it processed ${p.relative(file.path)}');
  }

  /// Find all Dart files in the given [paths]
  ///
  /// Recursively searches directories and returns a list of all Dart files
  /// that aren't excluded by the configuration.
  Future<List<File>> _findDartFiles(List<String> paths) async {
    // List to accumulate all found files
    final files = <File>[];

    // Process each path (could be file or directory)
    for (final path in paths) {
      // Check what type of file system entity this path is
      final entity = FileSystemEntity.typeSync(path);

      // If it's a single file
      if (entity == FileSystemEntityType.file) {
        // Only add if it's a Dart file and not excluded
        if (path.endsWith('.dart') && !_shouldExclude(path)) {
          files.add(File(path));
        }
      }
      // If it's a directory
      else if (entity == FileSystemEntityType.directory) {
        // Recursively list all files in the directory
        await for (final file in Directory(path).list(recursive: true)) {
          // Only process File entities (not directories or links)
          if (file is File &&
              file.path.endsWith('.dart') &&
              !_shouldExclude(file.path)) {
            files.add(file);
          }
        }
      }
    }

    return files;
  }

  Future<void> processFile(File file) => _processFile(file);

  /// Check if a file path should be excluded from processing
  ///
  /// Returns true if the path matches any of the exclude patterns
  /// from the configuration (like *.g.dart files).
  bool _shouldExclude(String path) {
    return config.exclude.any(
      (p) => path.contains(
        p.replaceAll('**/', '').replaceAll('*', ''),
      ),
    );
  }

  /// Update the JSON translation file with new translations
  ///
  /// This merges new translations with existing ones, preserving any
  /// manual edits users may have made to the JSON file.
  Future<void> _updateJsonFile(
    Map<String, dynamic> newTranslations,
    String locale,
  ) async {
    // Build the full path to the JSON file
    // Example: lib/i18n/en.i18n.json
    final jsonPath = p.join(config.i18nDir, '$locale.i18n.json');
    final jsonFile = File(jsonPath);

    // Load existing translations if the file already exists
    Map<String, dynamic> existing = {};
    if (jsonFile.existsSync()) {
      try {
        // Read and parse the existing JSON file
        existing =
            jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
      } catch (e) {
        _logger.w('⚠️  Warning: Invalid JSON in $jsonPath, recreating file');
      }
    }

    // Merge existing and new translations
    // This preserves existing values and only adds new keys
    final merged = _deepMerge(existing, newTranslations);

    // Create directory if it doesn't exist
    // recursive: true creates parent directories too
    jsonFile.parent.createSync(recursive: true);

    // Write the merged translations back to the file
    // Use indented JSON for readability (2 spaces)
    const encoder = JsonEncoder.withIndent('  ');
    jsonFile.writeAsStringSync(encoder.convert(merged));

    // Inform user that JSON was updated
    _logger.i('📝 Updated translation $jsonPath');
  }

  Future<void> _updateAllJsonFiles(
    Map<String, dynamic> newTranslations,
  ) async {
    if (config.locales.isNotEmpty) {
      for (final locale in config.locales) {
        _updateJsonFile(newTranslations, locale);
      }
    }
  }

  /// Run the 'dart run slang' command to generate translation code
  ///
  /// Slang reads the JSON file and generates Dart code with type-safe
  /// translation access (the t.key syntax).
  Future<void> _runSlang() async {
    _logger.d('🚀 Running dart run slang...');

    // Execute the slang command as a subprocess
    // This is equivalent to running 'dart run slang' in terminal
    final result = await Process.run('dart', ['run', 'slang']);

    // Check if slang command succeeded
    if (result.exitCode != 0) {
      // Slang failed - show error but don't crash
      // User might not have slang configured yet
      _logger.w('⚠️  Warning: slang command failed');
      _logger.w(result.stderr);
    } else {
      // Slang succeeded - translation files generated
      _logger.i('✅ Generated translation files');
    }
  }

  /// Create a backup copy of a file before modifying it
  ///
  /// Creates a .bak file so users can recover if something goes wrong.
  Future<void> _backupFile(File file) async {
    // Simply copy the file with .bak extension
    final backupPath = '${file.path}.bak';
    await file.copy(backupPath);
  }

  /// Show what would change in dry-run mode without actually modifying files
  ///
  /// This lets users preview the changes before committing to them.
  void _showDryRun(Map<String, dynamic> translations, List<File> files) {
    _logger.i('🔍 DRY RUN - No files will be modified\n');

    // Show what would be added to the JSON file
    _logger.d('Would update JSON with:');
    const encoder = JsonEncoder.withIndent('  ');
    _logger.d(encoder.convert(translations));

    // Show which files would be transformed
    _logger.d('\nWould transform ${files.length} file(s):');
    for (final file in files) {
      // Use relative paths for cleaner output
      _logger.d('  • ${p.relative(file.path)}');
    }
  }

  /// Deep merge two maps, preserving existing values
  ///
  /// When the same key exists in both maps:
  /// - If both values are maps, recursively merge them
  /// - Otherwise, keep the target (existing) value
  ///
  /// This ensures we don't overwrite manual edits in the JSON file.
  Map<String, dynamic> _deepMerge(
    Map<String, dynamic> existingMap,
    Map<String, dynamic> newValuesMap,
  ) {
    _logger.i('Starting deep merge of $newValuesMap into $existingMap');
    // Create a copy of target to avoid modifying the original
    final result = Map<String, dynamic>.from(existingMap);
    if (existingMap.isEmpty) {
      return newValuesMap;
    }
    // Process each key-value pair in the source map
    newValuesMap.forEach((key, value) {
      // If both target and source have this key and both are maps,
      // recursively merge them
      if (value is Map<String, dynamic> &&
          result[key] is Map<String, dynamic>) {
        result[key] = _deepMerge(result[key] as Map<String, dynamic>, value);
      }
      // If the key doesn't exist in target, add it
      // This is why existing values are preserved - we only add NEW keys
      else if (!result.containsKey(key)) {
        result[key] = value;
      }
      // If key exists but isn't a map, we keep the existing value (target)
      // This preserves manual edits
    });

    return result;
  }

  /// Count total number of keys in a nested map structure
  ///
  /// Recursively counts all leaf values (strings) in the translation map.
  /// This gives us the total number of translations.
  int _countKeys(Map<String, dynamic> map) {
    var count = 0;

    // Iterate through each value in the map
    map.forEach((key, value) {
      // If value is a map, recursively count its keys
      if (value is Map<String, dynamic>) {
        count += _countKeys(value);
      }
      // If it's a leaf value (string), count it
      else {
        count++;
      }
    });

    return count;
  }

  Future<void> _updateTranslationFile(Map<String, dynamic> newTranslations) {
    switch (config.translationFileType) {
      case TranslationFileType.json:
        return _updateAllJsonFiles(newTranslations);
      // Add other cases here for different file types (csv, arb, etc.)
      // case TranslationFileType.csv:
      //   return _updateCsvFile(newTranslations);
      // case TranslationFileType.arb:
      //   return _updateArbFile(newTranslations);
    }
  }
}
