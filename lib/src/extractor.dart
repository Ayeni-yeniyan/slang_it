/// Extracts translations from Dart source files
///
/// This class is responsible for finding slang_it.key'text' patterns in Dart code
/// and extracting them into a structured map that can be written to JSON.
///
/// Example:
///   Input:  Text(slang_it.home.title'Home')
///   Output: {"home": {"title": "Home"}}
///
/// The extractor handles:
/// - Single and double quoted strings
/// - Escaped quotes within strings
/// - Multi-line patterns
/// - Nested key paths (dot notation)
/// - Unicode characters in translations
library;

import 'dart:io';
import '/utils/logger/logger.dart';

import 'config.dart';

/// Handles extraction of translation strings from Dart source code
///
/// This class uses regular expressions to find patterns like:
/// - slang_it.key'value'
/// - slang_it.nested.key'value'
/// - slang_it.key"value"
/// - slang_it.key'value with \'escaped quotes\''
class TranslationExtractor {
  static final _logger = MyAppLogger.getLogger('TranslationExtractor');

  final SlangItConfig config;

  const TranslationExtractor(this.config);

  /// Extract translations from a single file
  /// Parameters:
  /// - [file]: The Dart file to extract translations from
  ///
  /// Returns:
  /// - A map of extracted translations in nested structure
  ///
  /// Example:
  /// ```dart
  /// final file = File('lib/screens/home.dart');
  /// final translations = await extractor.extractFromFile(file);
  /// // Result: {"home": {"title": "Home", "subtitle": "Welcome"}}
  /// ```
  Future<Map<String, dynamic>> extractFromFile(File file) async {
    _logger.i('Extracting from file: ${file.path}');
    if (file.existsSync()) {
      final content = await file.readAsString();
      return extractFromContent(content);
    }
    _logger.w('File does not exist');
    return {};
  }

  /// Extract translations from content string
  ///
  /// This is where the actual extraction logic happens.
  /// It parses the content using regex to find all slang_it patterns.
  ///
  /// Algorithm:
  /// 1. Check if content contains the pattern (early exit optimization)
  /// 2. Normalize line endings for consistent regex matching
  /// 3. Apply regex to find all matches
  /// 4. For each match, extract key path and value
  /// 5. Build nested map structure
  ///
  /// Parameters:
  /// - [content]: The source code content to parse
  ///
  /// Returns:
  /// - A nested map structure representing the translations
  ///   Example: {"section": {"key": "value"}}
  ///
  /// Edge cases handled:
  /// - Empty content
  /// - Content without any slang_it calls
  /// - Malformed patterns (skipped)
  /// - Escaped quotes in values
  /// - Unicode characters
  Map<String, dynamic> extractFromContent(String content) {
    if (!content.contains('${config.pattern}.')) return {};

    // Holds all extracted translations in a nested structure
    // Example: {"home": {"title": "Home", "subtitle": "Welcome"}}
    final translations = <String, dynamic>{};

    // Normalize line endings for consistent regex matching across platforms
    // Windows uses \r\n (CRLF), Unix/Mac uses \n (LF)
    // Standardize everything to \n for simplicity
    final normalized = content.replaceAll('\r\n', '\n');

    // Find all matches of the pattern in the normalized content
    // This returns an Iterable of Match objects
    // Each Match contains the full match and capture groups
    final matches = config.regxPattern.allMatches(normalized);

    // Process each match found in the content
    // Each match represents one slang_it.key'value' occurrence
    for (final match in matches) {
      // Extract the key path from capture group 1
      // Example: For "slang_it.home.title'Home'", keyPath = "home.title"
      //
      // We use group(1) because:
      // - group(0) would be the entire match: "slang_it.home.title'Home'"
      // - group(1) is our first capture group: "home.title"
      // - group(2) would be the value: "Home"
      final keyPath = match.group(1);

      // Extract the value from capture group 2
      // Example: For "slang_it.home.title'Home'", value = "Home"
      final value = _parseValue(match.group(2));

      _logger.i(' Extracted - Key: $keyPath, Value: $value');
      // Validate that both key and value are present and not empty
      // This handles edge cases where the regex might match but capture empty strings
      //
      // Possible edge cases:
      // - Malformed pattern: slang_it.'value' (missing key)
      // - Empty value: slang_it.key'' (empty string)
      // - Regex bug causing null captures
      //
      // If validation fails, we skip this match and continue to the next one
      // This prevents crashes and ensures we only process valid translations
      if (keyPath == null ||
          value == null ||
          keyPath.isEmpty ||
          value.isEmpty) {
        // Skip this invalid match - don't add it to translations
        // Continue to process the next match
        continue;
      }

      // Unescape special characters in the value
      //
      // When developers write code like:
      //   slang_it.message'It\'s working!'
      //
      // The source code contains the backslash literally: "It\'s working!"
      // We need to convert this back to the actual character: "It's working!"
      //
      // Why this is necessary:
      // - In Dart code, quotes inside strings must be escaped
      // - In JSON, we store the unescaped version
      // - This makes the JSON human-readable and easier to translate
      //
      // Replacements performed:
      // 1. \' → ' (escaped single quote becomes single quote)
      // 2. \\ → \ (escaped backslash becomes single backslash)
      //
      // Example transformations:
      // - "It\'s working!" → "It's working!"
      // - "Path: C:\\Users" → "Path: C:\Users"
      final unescapedValue = value
          .replaceAll(r"\'", "'") // Replace \' with '
          .replaceAll(r'\\', r'\'); // Replace \\ with \

      if (unescapedValue != value) {
        _logger
            .i('Converted Value: $value to Unescaped Value: $unescapedValue');
      }
      // Add this translation to our nested map structure
      //
      // This is the key operation that builds the JSON structure
      //
      // Example flow:
      // Input: keyPath = "home.settings.title", unescapedValue = "Settings"
      //
      // _setNestedValue will create:
      // {
      //   "home": {
      //     "settings": {
      //       "title": "Settings"
      //     }
      //   }
      // }
      //
      // If "home" already exists with other keys, they are preserved:
      // {
      //   "home": {
      //     "subtitle": "Welcome",     ← Existing key preserved
      //     "settings": {
      //       "title": "Settings"      ← New key added
      //     }
      //   }
      // }
      _setNestedValue(translations, keyPath, unescapedValue);
    }

    // Return the complete map of translations extracted from this content
    // This will be merged with translations from other files by the processor
    return translations;
  }

  /// Set a nested value in a map using a dot-separated key path
  ///
  /// This method converts a flat key path like "home.settings.title" into
  /// a nested map structure: {"home": {"settings": {"title": "value"}}}
  ///
  /// Algorithm:
  /// 1. Split the key path by dots: "a.b.c" → ["a", "b", "c"]
  /// 2. Navigate through the map, creating sub-maps as needed
  /// 3. Set the value at the final key
  ///
  /// Parameters:
  /// - [map]: The root map to modify
  /// - [keyPath]: Dot-separated path (e.g., "home.settings.title")
  /// - [value]: The translation string to store
  ///
  /// Example:
  /// ```dart
  /// final map = {};
  /// _setNestedValue(map, "home.title", "Home");
  /// // Result: map = {"home": {"title": "Home"}}
  ///
  /// _setNestedValue(map, "home.subtitle", "Welcome");
  /// // Result: map = {"home": {"title": "Home", "subtitle": "Welcome"}}
  /// ```
  ///
  /// Edge cases handled:
  /// - Creating new nested structures as needed
  /// - Preserving existing keys at same level
  /// - Handling conflicts (when a key exists as string but needs to be map)
  /// - Using putIfAbsent to avoid overwriting existing translations
  void _setNestedValue(Map<String, dynamic> map, String keyPath, String value) {
    // Split the key path by dots to get individual keys
    //
    // Examples:
    // - "home.title" → ["home", "title"]
    // - "settings.profile.name" → ["settings", "profile", "name"]
    // - "simple" → ["simple"]
    //
    // Each element becomes a level in the nested structure
    final keys = keyPath.split('.');

    // Start at the root of the map
    // As we navigate through nested levels, this will point to deeper maps
    Map<String, dynamic> current = map;

    // Navigate/create the nested structure for all keys except the last one
    //
    // Why all except the last?
    // - The last key will hold the actual string value (translation)
    // - All other keys are just containers (nested maps)
    //
    // Example: For ["home", "settings", "title"]
    // - i=0: Process "home" (create/navigate to home map)
    // - i=1: Process "settings" (create/navigate to settings map)
    // - Skip i=2: "title" will be handled after the loop
    for (int i = 0; i < keys.length - 1; i++) {
      // If this key doesn't exist yet, create an empty map for it
      //
      // putIfAbsent(key, ifAbsent) works like this:
      // - If key exists: return existing value, don't call ifAbsent
      // - If key missing: call ifAbsent(), store result, return it
      //
      // This ensures we create the structure only if needed
      // and don't overwrite existing nested maps
      current.putIfAbsent(keys[i], () => <String, dynamic>{});

      // Handle edge case: what if someone previously used this key as a string?
      //
      // Example problematic scenario:
      // 1. First we extract: slang_it.home'Welcome' → {"home": "Welcome"}
      // 2. Later we extract: slang_it.home.title'Title' → need {"home": {"title": ...}}
      //
      // We need "home" to be a map, but it's currently a string!
      //
      // Solution: Check if the existing value is a map
      // If not, replace it with an empty map
      //
      // This means the first value ("Welcome") will be lost, but this is
      // an edge case that indicates conflicting key paths in the code.
      // The developer should fix their key structure.
      if (current[keys[i]] is! Map<String, dynamic>) {
        // Value exists but is not a map - replace it with empty map
        // This allows us to continue building the nested structure
        current[keys[i]] = <String, dynamic>{};
      }

      // Move deeper into the nested structure
      //
      // current now points to the next level down
      //
      // Example progression for "home.settings.title":
      // - After i=0: current = map["home"] = {}
      // - After i=1: current = map["home"]["settings"] = {}
      //
      // Now we're at the right place to set "title"
      current = current[keys[i]] as Map<String, dynamic>;
    }

    // Set the final value at the deepest level
    //
    // We use putIfAbsent instead of direct assignment (current[keys.last] = value)
    //
    // Why putIfAbsent?
    // - It only sets the value if the key doesn't exist
    // - This preserves any manual edits users made to the JSON file
    // - If a translation already exists, we don't overwrite it
    //
    // This is CRUCIAL for the user experience:
    // - User extracts translations: "home.title" = "Home"
    // - User manually edits JSON: "home.title" = "Home Page" (better translation)
    // - User runs extractor again
    // - Result: "home.title" stays "Home Page" (manual edit preserved)
    //
    // Without putIfAbsent, we'd overwrite to "Home" every time
    //
    // Example: if keys = ["home", "settings", "title"]
    // - keys.last = "title"
    // - current already points to map["home"]["settings"]
    // - We set current["title"] = value
    //
    // Final structure:
    // {
    //   "home": {
    //     "settings": {
    //       "title": "Settings"  ← Set here
    //     }
    //   }
    // }
    current.putIfAbsent(keys.last, () => value);
  }

  /// Parse string and replace nested property access with last property
  ///
  /// Example: "header text ${name}" → "header text ${name}"
  /// Example: "subheading text ${someval.val}" → "subheading text ${val}"
  String? _parseValue(String? val) {
    if (val == null) return null;
    if (!val.contains(r'${')) {
      return val;
    }

    final parts = val.split(r'${');
    if (parts.length == 1) return val;

    final buffer = StringBuffer(parts[0]);

    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      final closeBraceIndex = part.indexOf('}');

      if (closeBraceIndex == -1) {
        buffer.write(r'${');
        buffer.write(part);
        continue;
      }

      final expression = part.substring(0, closeBraceIndex);
      final remainder = part.substring(closeBraceIndex);
      if (expression.contains('.')) {
        final lastPart = expression.substring(expression.lastIndexOf('.') + 1);
        buffer.write(r'${');
        buffer.write(lastPart);
      } else {
        buffer.write(r'${');
        buffer.write(expression);
      }
      buffer.write(remainder);
    }

    return buffer.toString();
  }
}
