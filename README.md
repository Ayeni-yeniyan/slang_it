# slang_it

A CLI tool for automatic localization text extraction and code transformation for [slang](https://pub.dev/packages/slang). Write your translations inline with `slang_it.key'text'` and watch them automatically transform into type-safe `t.key` calls.

## Features

- **Inline Translation Writing**: Write translation texts directly in your code using `slang_it.key'text'` syntax
- **Automatic Extraction**: Automatically extracts translation texts to JSON files
- **Code Transformation**: Transforms `slang_it.key'text'` to `t.key` after extraction
- **Watch Mode**: Continuously monitors file changes and processes them automatically
- **Nested Keys**: Supports nested translation keys like `slang_it.settings.profile.name'Name'`
- **Dry Run**: Preview changes before applying them
- **Backup Support**: Create backup files before modifications
- **Interactive Mode**: Ask for confirmation before making changes
- **Configurable**: Customize paths, patterns, and behavior via YAML config

## Prerequisites

**IMPORTANT**: This tool is built on top of [slang](https://pub.dev/packages/slang). You **must** set up slang first before using slang_it.

### Setting up slang

1. Add slang to your `pubspec.yaml`:

```yaml
dependencies:
  slang: ^3.31.0
  slang_flutter: ^3.31.0

dev_dependencies:
  slang_build_runner: ^3.31.0
  build_runner: ^2.4.0
```

2. Create a `slang.yaml` file in your project root:

```yaml
base_locale: en
fallback_strategy: base_locale
input_directory: lib/i18n
input_file_pattern: .i18n.json
output_directory: lib/i18n
output_file_name: strings.g.dart
translate_var: t
```

3. Create the i18n directory:

```bash
mkdir -p lib/i18n
```

4. Run slang once to initialize:

```bash
dart run slang
```

For more details on slang setup, see the [slang documentation](https://pub.dev/packages/slang).

## Getting Started

### Installation

Add slang_it to your `pubspec.yaml`:

```yaml
dev_dependencies:
  slang_it: ^0.0.2
```

Then install dependencies:

```bash
dart pub get
```

### Configuration

Create a `slang_it.yaml` file in your project root:

```yaml
# slang_it configuration

# Directory where i18n files are located
i18n_dir: lib/i18n

# Supported locales
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
```

## Usage

### Basic Workflow

1. **Write translations inline** in your Dart code:

```dart
import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(slang_it.home.title'Home'),
        Text(slang_it.home.subtitle'Welcome to our app'),
        Text(slang_it.settings.profile.name'Profile Name'),
      ],
    );
  }
}
```

2. **Run slang_it** to extract and transform:

```bash
dart run slang_it
```

3. **Result**: Your code is automatically transformed to:

```dart
import 'package:flutter/material.dart';
import 'package:your_app/i18n/strings.g.dart';

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(t.home.title),
        Text(t.home.subtitle),
        Text(t.settings.profile.name),
      ],
    );
  }
}
```

And a JSON file is created at `lib/i18n/en.i18n.json`:

```json
{
  "home": {
    "title": "Home",
    "subtitle": "Welcome to our app"
  },
  "settings": {
    "profile": {
      "name": "Profile Name"
    }
  }
}
```

### Command Line Options

```bash
# Process all files in lib/
dart run slang_it

# Process specific directory
dart run slang_it lib/screens/

# Watch mode - auto-process on file changes
dart run slang_it --watch
dart run slang_it -w

# Preview changes without modifying files
dart run slang_it --dry-run
dart run slang_it -d

# Create backups before modifying
dart run slang_it --backup
dart run slang_it -b

# Interactive mode - ask for confirmation
dart run slang_it --interactive
dart run slang_it -i

# Show help
dart run slang_it --help
dart run slang_it -h

# Use custom config file
dart run slang_it --config path/to/config.yaml
dart run slang_it -c path/to/config.yaml
```

### Watch Mode

Watch mode is perfect for development - it automatically processes files as you save them:

```bash
dart run slang_it --watch
```

This will:
1. Run an initial full processing
2. Watch for file changes
3. Automatically extract and transform when you save files
4. Keep running until you press Ctrl+C

## How It Works

1. **Extraction**: Scans your Dart files for `slang_it.key'value'` patterns
2. **JSON Update**: Merges extracted translations into your JSON file (preserving existing values)
3. **Slang Generation**: Runs `dart run slang` to generate type-safe translation code
4. **Transformation**: Replaces `slang_it.key'value'` with `t.key` in your source files

## Examples

### Simple Translation

```dart
// Before
Text(slang_it.welcome'Welcome!')

// After
Text(t.welcome)
```

### Nested Keys

```dart
// Before
Text(slang_it.errors.network.timeout'Connection timed out')

// After
Text(t.errors.network.timeout)
```

### Multiple Translations

```dart
// Before
Column(
  children: [
    Text(slang_it.login.title'Login'),
    Text(slang_it.login.subtitle'Please enter your credentials'),
    ElevatedButton(
      onPressed: () {},
      child: Text(slang_it.login.submit'Sign In'),
    ),
  ],
)

// After
Column(
  children: [
    Text(t.login.title),
    Text(t.login.subtitle),
    ElevatedButton(
      onPressed: () {},
      child: Text(t.login.submit),
    ),
  ],
)
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `i18n_dir` | `lib/i18n` | Directory where i18n files are stored |
| `locale` | `en` | Base locale for translations |
| `translation_file` | `strings.g.dart` | Generated translation file name |
| `pattern` | `slang_it` | Pattern to match in code |
| `include` | `lib/**/*.dart` | Files to process |
| `exclude` | Generated files | Files to skip |
| `run_slang_after` | `true` | Run slang after extraction |
| `preserve_formatting` | `true` | Keep code formatting |

---

## Contributing

Found a bug or want to contribute? Please open an issue or pull request on [GitHub repository](https://github.com/Ayeni-yeniyan/slang_it).

## Support

- **Issues**: Report bugs or request features on GitHub
- **Discussions**: Ask questions and share tips in GitHub 

> **AI generated docs**