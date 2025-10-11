/// Transforms source files by replacing pattern (e.g slang_it) calls with t calls
///
/// This class is responsible for modifying Dart source files in place:
/// 1. Replacing slang_it.key'text' with t.key
/// 2. Adding the necessary import for the translations file
///
/// Example transformation:
///   Before: Text(slang_it.home.title'Home')
///   After:  Text(t.home.title)
///   Also adds if not included: import '../i18n/strings.g.dart';
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import '/utils/logger/app_logger.dart';
import 'config.dart';

/// Handles transformation of Dart source files
class SourceTransformer {
  static final _logger = MyAppLogger.getLogger('SourceTransformer');

  final SlangItConfig config;

  SourceTransformer(this.config);

  /// Transform a single file in place
  ///
  /// This is the main entry point. It reads the file, transforms the content,
  /// and writes it back to the same location.
  Future<void> transformFile(File file) async {
    _logger.i('Transforming file: ${file.path}');
    final content = await file.readAsString();

    if (!content.contains('${config.pattern}.')) {
      return;
    }

    String transformed = _transformContent(content);

    transformed = _addImportIfNeeded(transformed, file.path);

    if (transformed == content) {
      _logger.d('  ...No changes needed, skipping write');
      return;
    }
    await file.writeAsString(transformed);

    // Print a checkmark next to the relative path so user knows it was processed
    // p.relative makes the path shorter and cleaner (e.g., lib/screens/home.dart)
    _logger.d('  ✓ ${p.relative(file.path)}');
  }

  /// Transform the content by replacing slang_it patterns with t patterns
  ///
  /// Uses regex to find and replace all occurrences of the pattern.
  /// This is where slang_it.home.title'Home' becomes t.home.title
  String _transformContent(String content) {
    // Replace all matches with t.{keyPath}
    // replaceAllMapped allows us to use the captured groups from the regex
    return content.replaceAllMapped(config.regxPattern, (match) {
      // Extract the key path from capture group 1
      // For example, if the match is slang_it.home.title'Home',
      // keyPath will be "home.title"
      final keyPath = match.group(1)!;

      // Return the replacement string: t.{keyPath}
      // The entire matched string (including 'text' part) gets replaced
      // Example: slang_it.home.title'Home' → t.home.title
      return 't.$keyPath';
    });
  }

  /// Add import statement if it's not already present in the file
  ///
  /// This ensures the 't' variable is available by importing the
  /// generated translations file.
  String _addImportIfNeeded(String content, String filePath) {
    final importPath = _calculateImportPath(filePath);

    // Build the complete import statement
    final importStatement = "import '$importPath';";

    // Check if this exact import already exists in the file
    // If it does, we don't need to add it again
    if (content.contains(importStatement)) {
      // Import already exists - return content unchanged
      return content;
    }

    // Split the content into lines so we can insert the import at the right place
    final lines = content.split('\n');

    // Find the best location to insert the import
    // (after existing imports, before the code)
    final int insertIndex = _findImportInsertionPoint(lines);

    // Insert the import statement at the determined position
    lines.insert(insertIndex, importStatement);

    // Join the lines back together with newlines
    return lines.join('\n');
  }

  /// Calculate the relative import path from a file to the translations file
  ///
  /// This ensures the import path is correct regardless of how deep
  /// in the directory structure the file is.
  ///
  /// Examples:
  ///   lib/main.dart          → 'i18n/strings.g.dart'
  ///   lib/screens/home.dart  → '../i18n/strings.g.dart'
  ///   lib/features/auth/login.dart → '../../i18n/strings.g.dart'
  String _calculateImportPath(String filePath) {
    // Get the directory containing this file
    // Example: for lib/screens/home.dart, fileDir = lib/screens
    final fileDir = p.dirname(filePath);

    // Build the full path to the translation file
    // Example: lib/i18n/strings.g.dart
    final i18nPath = p.join(config.i18nDir, config.translationFile);

    // Calculate the relative path from the file's directory to the i18n file
    // The 'from' parameter specifies the starting point for the relative path
    // Example: from lib/screens to lib/i18n/strings.g.dart = ../i18n/strings.g.dart
    final relativePath = p.relative(i18nPath, from: fileDir);

    // Normalize path separators for imports
    return relativePath.replaceAll(r'\', '/');
  }

  /// Find the best location to insert an import statement
  ///
  /// Tries to place the import after existing imports but before
  /// any actual code. This keeps imports grouped together.
  ///
  /// Returns the line index where the import should be inserted.
  int _findImportInsertionPoint(List<String> lines) {
    // Track the last import we've seen (we'll insert after it)
    var lastImportIndex = -1;

    // Track whether we're currently inside a multi-line comment
    // This prevents us from thinking /* import */ is a real import
    var inComment = false;

    // Iterate through each line of the file
    for (var i = 0; i < lines.length; i++) {
      // Get trimmed version of line for easier checking
      final line = lines[i].trim();

      // Track multi-line comments (/* ... */)
      // We need to skip these because they might contain the word "import"
      if (line.startsWith('/*')) inComment = true;

      // End of multi-line comment - resume normal processing
      if (line.endsWith('*/')) {
        inComment = false;
        continue; // Skip this line and move to next
      }

      // If we're inside a comment, skip this line entirely
      if (inComment) continue;

      // Skip single-line comments (//) and empty lines at the top of the file
      // These often appear before imports (copyright headers, file docs, etc.)
      if (line.startsWith('//') || line.isEmpty) continue;

      // Check if this line is an import or export statement
      // These are the lines we want to group our new import with
      if (line.startsWith('import ') || line.startsWith('export ')) {
        // Remember this as the last import we've seen
        lastImportIndex = i;
        continue; // Keep looking for more imports
      }

      // If we've found imports previously and now hit a non-import line,
      // this is the first line of actual code
      // We should insert our import right after the last import
      if (lastImportIndex >= 0) {
        // Return position after the last import
        return lastImportIndex + 1;
      }

      // If we haven't found any imports yet, but we've hit code,
      // insert the import right before this line of code
      // This handles files that have no imports at all
      return i;
    }

    // Edge case: we've gone through the entire file
    // Either there are only imports and no code, or the file is empty
    // In this case, just insert at the beginning (index 0)
    return 0;
  }
}
