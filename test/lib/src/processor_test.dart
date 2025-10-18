import 'dart:io';

import 'package:slang_it/src/config.dart';
import 'package:slang_it/src/processor.dart';

import 'package:test/test.dart';

void main() {
  late SlangItProcessor processer;

  late List<String> testFilesPathList;

  void setUpTestFiles() {
    testFilesPathList = [
      'test/helpers/untranslated_file.dart',
      'test/helpers/untranslated_file1.dart',
      'test/helpers/untranslated_file2.dart',
      'test/helpers/untranslated_file3.dart',
      'test/helpers/untranslated_file4.dart',
    ];
    for (final filePath in testFilesPathList) {
      final file = File(filePath);
      file.parent.createSync(recursive: true);
      const fileString = '''
import 'package:flutter/material.dart';

class UntranslatedDartFile extends StatelessWidget {
  const UntranslatedDartFile({super.key});

  @override
  Widget build(BuildContext context) {
    return  Column(children: [
      Text(slang_it.untranslated.header'header text'),

''';
      final m =
          "       Text(slang_it.untranslated.h${testFilesPathList.indexOf(filePath)}eader'header text ${testFilesPathList.indexOf(filePath)}'),\n";

      final n =
          "      Text(slang_it.untranslated.sub${testFilesPathList.indexOf(filePath)}heading'subheadding text'),";
      const endingString = '''

      Text(slang_it.untranslated.settings.heading'settings heading'),
    ],);
  }
}

''';
      file.writeAsStringSync(fileString + m + n + endingString);
    }
  }

  setUp(() {
    processer = SlangItProcessor(config: SlangItConfig());
    setUpTestFiles();
  });
  tearDown(() async {
    for (final filePath in testFilesPathList) {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    testFilesPathList.clear();
  });
  group('SlangItProcessor tests', () {
    test(
      'slangItProcess runs one a single file',
      () async {
        // Arrange
        // Act
        await processer.slangItProcess(testFilesPathList);

        // Assert
        assert(File('lib/i18n/en.i18n.json').existsSync());
      },
    );
    test(
      'slangItProcess runs on for single file',
      () async {
        // Arrange
        final testFile = File(testFilesPathList.first);
        // Act
        await processer.processFile(testFile);
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
      Text(slang_it.untranslated.newKey'new translation from watch'),
    ],);
  }
}

''');

        await processer.processFile(testFile);
        // Assert
        assert(File('lib/i18n/en.i18n.json').existsSync());
      },
    );
  });
}
