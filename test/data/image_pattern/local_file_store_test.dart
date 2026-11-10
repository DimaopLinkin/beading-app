import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/data/image_pattern/local_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalFileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('file_store_test');
    store = LocalFileStore(() async => root);
    addTearDown(() => root.deleteSync(recursive: true));
  });

  File file(String path) => File('${root.path}/$path');

  test('пишет файл, создавая каталоги, и не оставляет временных файлов', () async {
    final result = await store.write('book_patterns/a/b.png', Uint8List.fromList(<int>[1, 2, 3]));

    expect(result.isSuccess, isTrue);
    expect(file('book_patterns/a/b.png').readAsBytesSync(), <int>[1, 2, 3]);
    expect(Directory('${root.path}/book_patterns/a').listSync().map((e) => e.path), <String>[
      '${root.path}/book_patterns/a/b.png',
    ]);
  });

  test('читает записанный файл; нет файла — StorageFailure, выход за каталог — ValidationFailure', () async {
    await store.write('a/1.png', Uint8List.fromList(<int>[4, 5]));

    expect((await store.read('a/1.png')).valueOrNull, <int>[4, 5]);
    expect((await store.read('a/нет.png')).failureOrNull, isA<StorageFailure>());
    expect((await store.read('../x.png')).failureOrNull, isA<ValidationFailure>());
  });

  test('копирует файл, оригинал остаётся', () async {
    await store.write('a/1.png', Uint8List.fromList(<int>[9]));

    final result = await store.copy(from: 'a/1.png', to: 'b/2.png');

    expect(result.isSuccess, isTrue);
    expect(file('b/2.png').readAsBytesSync(), <int>[9]);
    expect(file('a/1.png').existsSync(), isTrue);
  });

  test('копирование отсутствующего файла — StorageFailure', () async {
    expect((await store.copy(from: 'нет.png', to: 'b/2.png')).failureOrNull, isA<StorageFailure>());
  });

  test('удаляет файл и опустевший каталог; повторное удаление — успех', () async {
    await store.write('a/1.png', Uint8List(1));
    await store.write('a/2.png', Uint8List(1));

    await store.delete('a/1.png');
    expect(Directory('${root.path}/a').existsSync(), isTrue);
    await store.delete('a/2.png');
    expect(Directory('${root.path}/a').existsSync(), isFalse);
    expect((await store.delete('a/2.png')).isSuccess, isTrue);
    expect(root.existsSync(), isTrue);
  });

  test('абсолютный путь и выход за каталог отклоняются', () async {
    expect((await store.write('/tmp/x.png', Uint8List(1))).failureOrNull, isA<ValidationFailure>());
    expect((await store.write('../x.png', Uint8List(1))).failureOrNull, isA<ValidationFailure>());
    expect((await store.delete('a/../../x.png')).failureOrNull, isA<ValidationFailure>());
    expect(File('${root.parent.path}/x.png').existsSync(), isFalse);
  });

  test('сбой переименования не оставляет временный файл', () async {
    // Под именем будущего файла лежит непустой каталог: rename упадёт.
    Directory('${root.path}/a/1.png').createSync(recursive: true);
    File('${root.path}/a/1.png/x').writeAsStringSync('x');

    final result = await store.write('a/1.png', Uint8List(1));

    expect(result.failureOrNull, isA<StorageFailure>());
    expect(File('${root.path}/a/1.png.tmp').existsSync(), isFalse);
  });
}
