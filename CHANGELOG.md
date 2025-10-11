# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-10-11

### Added
- Initial release of slang_it CLI tool
- Core functionality to extract translations from `slang_it.key'text'` patterns in Dart code
- Automatic JSON generation in `lib/i18n/{locale}.i18n.json` format
- Automatic execution of `dart run slang` to generate translation files
- Automatic code transformation from `slang_it.key'text'` to `t.key`
- Smart import management - automatically adds `import '../i18n/strings.g.dart'`
- Command-line interface with multiple modes:
  - Basic mode: `dart run slang_it`
  - Watch mode: `dart run slang_it --watch` for continuous development
  - Dry-run mode: `dart run slang_it --dry-run` to preview changes
  - Backup mode: `dart run slang_it --backup` to create `.bak` files
  - Interactive mode: `dart run slang_it --interactive` for confirmation prompts
- Configuration file support via `slang_it.yaml`
- Support for nested translation keys (e.g., `home.settings.title`)
- Proper handling of escaped quotes in translation strings
- Relative import path calculation that works at any directory depth
- Exclusion patterns for generated files (`.g.dart`, `.freezed.dart`, etc.)
- Deep merge strategy that preserves existing manual edits in JSON files
- Multi-line pattern support for code formatted across lines
- File watcher for watch mode using `DirectoryWatcher`

### Features
- **Zero-config operation**: Works immediately with sensible defaults
- **Smart import insertion**: Places imports after existing imports, before code
- **Translation preservation**: Never overwrites manual JSON edits
- **Performance optimized**: Early exit when files don't contain slang_it patterns
<!-- - **Cross-platform**: Works on Windows, macOS, and Linux -->
- **Comprehensive error handling**: Graceful recovery from invalid JSON, malformed patterns
- **User-friendly output**: Clear progress messages and success confirmations

### Documentation
- Complete README with installation, usage, and examples
- Inline code documentation with detailed comments explaining every line
- Configuration examples and customization guide
- Troubleshooting section
- FAQ addressing common questions

### Technical Details
- Regex-based pattern matching for `slang_it.key'text'` extraction
- Nested map generation for hierarchical JSON structure
- Atomic file operations for safe source code modification
- Support for both single and double quoted strings
- Proper escaping/unescaping of special characters

## [1.0.0] - TBD

## [1.1.0] - TBD

### Planned for stable release
- Additional testing and validation
- Performance benchmarks on large codebases
- Community feedback integration
- Example project with real-world usage

---

## Unreleased

### Planned Features
- Multi-locale support (extract to multiple language files)
- Parameter extraction from translation strings (e.g., `{name}`, `{count}`)
- Plural support detection
- Context/gender support
- IDE plugin for VS Code and IntelliJ
- Migration tool from existing slang projects
- Validation command to ensure all keys exist in code
- Remove unused translations feature
- Git integration (auto-commit translations)
- CI/CD integration examples

---

## Version History

### How to Upgrade

#### From nothing to 1.0.0
```bash
flutter pub add --dev slang_it
dart run slang_it
```

### Breaking Changes
None yet - this is the initial release.

### Deprecations
None yet.

---

[1.0.0]: https://github.com/Ayeni-yeniyan/slang_it/releases/tag/v1.0.0