import 'dart:io';

import 'package:beading/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Открывает файл базы в Application Support (в фоновом изоляте).
Future<AppDatabase> openAppDatabase() async {
  final Directory directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return AppDatabase(NativeDatabase.createInBackground(File(p.join(directory.path, 'beading.sqlite'))));
}
