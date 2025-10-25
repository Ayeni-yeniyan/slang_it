#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:slang_it/src/processor.dart';
import 'package:slang_it/src/config.dart';
import 'package:slang_it/utils/logger/app_logger.dart';

void main(List<String> arguments) async {
  final logger = MyAppLogger.getLogger('SlangIt');
  // Define command-line arguments that the tool accepts
  final parser = ArgParser()
    ..addFlag('watch', abbr: 'w', help: 'Watch mode - auto-run on changes')
    ..addFlag(
      'dry-run',
      abbr: 'd',
      help: 'Show what would change without modifying',
    )
    ..addFlag('backup', abbr: 'b', help: 'Create backup files before modifying')
    ..addFlag(
      'interactive',
      abbr: 'i',
      help: 'Ask for confirmation before changes',
    )
    ..addFlag('help', abbr: 'h', help: 'Show this help message')
    ..addFlag('configure', help: 'Setup slang configuration', negatable: false)
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to config file',
      defaultsTo: 'slang_it.yaml',
    );

  final results = parser.parse(arguments);
  // Check if prompt requested help
  if (results['help'] as bool) {
    _showHelp(parser);
    return;
  }

  try {
    // Load configuration
    final config = await SlangItConfig.load(results['config'] as String);

    // Get paths to process
    final paths = results.rest.isEmpty ? ['lib'] : results.rest;

    // Create processor
    final processor = SlangItProcessor(
      config: config,
      dryRun: results['dry-run'] as bool,
      backup: results['backup'] as bool,
      interactive: results['interactive'] as bool,
    );

    if (results['watch'] as bool) {
      logger.i('👀 Watch mode enabled. Press Ctrl+C to stop.\n');
      await processor.slangItWatch(paths);
    } else {
      await processor.slangItProcess(paths);
    }
  } catch (e, stackTrace) {
    stderr.writeln('❌ Error: $e');
    if (Platform.environment['DEBUG'] == '1') {
      stderr.writeln(stackTrace);
    }
    exit(1);
  }
}

void _showHelp(ArgParser parser) {
  MyAppLogger.getLogger('SlangItHelper').i('''

slang_it - Automatic localization extraction and transformation

Usage: dart run slang_it [options] [paths...]

Examples:
  dart run slang_it                    # Process all files in lib/
  dart run slang_it lib/screens/       # Process specific directory
  dart run slang_it --watch            # Watch mode
  dart run slang_it --dry-run          # Preview changes
  dart run slang_it --backup           # Create backups before modifying

Options:
${parser.usage}

Configuration:
  Create slang_it.yaml in your project root to customize behavior.
  See https://github.com/ayeni_yeniyan/slang_it for examples.
''');
}
