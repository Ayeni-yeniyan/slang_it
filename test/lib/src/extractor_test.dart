import 'dart:io';

import 'package:slang_it/src/config.dart';
import 'package:slang_it/src/extractor.dart';
import 'package:test/test.dart';

void main() {
  late TranslationExtractor extractor;
  final testFiles = <File>[];

  setUp(() {
    extractor = TranslationExtractor(SlangItConfig());
  });

  tearDown(() async {
    for (final file in testFiles) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    testFiles.clear();
  });

  group('TranslationExtractor tests', () {
    test(
      'extractFromFile reads file and extracts translations',
      () async {
        // Arrange
        final testFile = File('test/helpers/untranslated_file.dart');
        testFiles.add(testFile);

        testFile.parent.createSync(recursive: true);
        testFile.writeAsStringSync('''
import 'package:flutter/material.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(slang_it.untranslated.header'header text'),
      Text(slang_it.untranslated.subheading'subheadding text'),
      Text(slang_it.untranslated.settings.heading'settings heading'),
    ],);
  }
}

''');
        // Act
        final result = await extractor.extractFromFile(testFile);

        final expectedResult = {
          'untranslated': {
            'header': 'header text',
            'subheading': 'subheadding text',
            'settings': {'heading': 'settings heading'},
          },
        };
        // Assert
        expect(result, isNotEmpty);
        expect(result, equals(expectedResult));
      },
    );

    test(
      'extractFromFile reads file and returns empty on file not existing',
      () async {
        // Act
        final result = await extractor.extractFromFile(
          File('test/helpers/untranslated_filess.dart'),
        );

        final expectedResult = {};
        // Assert
        expect(result, isEmpty);
        expect(result, equals(expectedResult));
      },
    );

    test(
      'setNestedValue sets value as map if it is a map and previous value not map',
      () async {
        // Arrange
        final testFile = File('test/helpers/untranslated2_file.dart');
        testFiles.add(testFile);

        await testFile.parent.create(recursive: true);
        await testFile.writeAsString('''
import 'package:flutter/material.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(slang_it.untranslated.header'header text'),
      Text(slang_it.untranslated.subheading'subheadding text'),
      Text(slang_it.untranslated.subheading.heading'settings heading'),
    ],);
  }
}

''');
        // Act
        final result = await extractor.extractFromFile(testFile);

        final expectedResult = {
          'untranslated': {
            'header': 'header text',
            'subheading': {'heading': 'settings heading'},
          },
        };
        // Assert
        expect(result, isNotEmpty);
        expect(result, equals(expectedResult));
      },
    );
  });

  test(
    'setNestedValue sets value as map if it is a map and previous value not map',
    () async {
      // Arrange
      final testFile = File('test/helpers/untranslated2_file.dart');
      testFiles.add(testFile);

      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(r'''
import 'package:flutter/material.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(slang_it.untranslated.header'header text ${name}'),
      Text(slang_it.untranslated.subheading'subheadding text ${someval.val}'),
      Text(slang_it.untranslated.settings.heading'settings heading'),
    ],);
  }
}

''');
      // Act
      final result = await extractor.extractFromFile(testFile);

      final expectedResult = {
        'untranslated': {
          'header': r'header text ${name}',
          'subheading': r'subheadding text ${val}',
          'settings': {'heading': 'settings heading'},
        },
      };
      // Assert
      expect(result, isNotEmpty);
      expect(result, equals(expectedResult));
    },
  );
}
