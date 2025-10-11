enum TranslationFileType {
  json,
  // csv,
  // arb,
}

/// Converter class for TranslationFileType
///
/// Provides methods to convert between TranslationFileType enum
/// and string representations.
class TranslationFileTypeConverter {
  /// Convert a string to TranslationFileType
  ///
  /// Throws [ArgumentError] if the string doesn't match any file type.
  ///
  /// Example:
  /// ```dart
  /// final type = TranslationFileTypeConverter.fromString('json');
  /// // Returns: TranslationFileType.json
  /// ```
  static TranslationFileType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'json':
        return TranslationFileType.json;
      // case 'csv':
      //   return TranslationFileType.csv;
      // case 'arb':
      //   return TranslationFileType.arb;
      default:
        throw ArgumentError(
          'Invalid translation file type: $value. '
          'Supported types: json',
          // When more types are added: 'Supported types: json, csv, arb'
        );
    }
  }
}
