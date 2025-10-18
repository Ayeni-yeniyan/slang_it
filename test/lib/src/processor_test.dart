import 'dart:io';

import 'package:slang_it/src/config.dart';
import 'package:slang_it/src/transformer.dart';
import 'package:test/test.dart';

void main() {
  late SourceTransformer transformer;
  final testFiles = <File>[];
  setUp(() {
    transformer = SourceTransformer(SlangItConfig());
  });
  tearDown(() async {
    for (final file in testFiles) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    testFiles.clear();
  });

  group('SourceTransformer tests', () {
    test(
      'transformFile transforms a single file',
      () async {
        // Arrange
        final testFile = File('test/helpers/untranslated_file.dart');
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
      Text(slang_it.untranslated.settings.heading'settings heading'),
    ],);
  }
}

''');
        // Act
        await transformer.transformFile(testFile);
        final result = testFile.readAsStringSync();
        const expectedResult = '''
import 'package:flutter/material.dart';
import '../../lib/i18n/strings.g.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(t.untranslated.header),
      Text(t.untranslated.subheading),
      Text(t.untranslated.settings.heading),
    ],);
  }
}

''';
        // Assert
        expect(result, isNotEmpty);
        expect(result, equals(expectedResult));
      },
    );

    test(
      'transformFile skips write on unchanged file',
      () async {
        // Arrange
        final testFile = File('test/helpers/untranslated_file.dart');
        testFiles.add(testFile);
        await testFile.parent.create(recursive: true);
        await testFile.writeAsString('''
import 'package:flutter/material.dart';
import '../../lib/i18n/strings.g.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(t.untranslated.header),
      Text(t.untranslated.subheading),
      Text(t.untranslated.settings.heading),
    ],);
  }
}

''');
        final expectedResult = testFile.readAsStringSync();

        // Act
        await transformer.transformFile(testFile);
        final result = testFile.readAsStringSync();
        // Assert
        expect(result, equals(expectedResult));
      },
    );
  });
}
