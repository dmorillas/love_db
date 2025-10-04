import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_db/love_db.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/model/search_mode.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String baseDir;
  _FakePathProvider(this.baseDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => baseDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;
  late PathProviderPlatform originalProvider;

  setUpAll(() async {
    // Use ffi database factory for tests
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('love_db_test_');
    originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tmpDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalProvider;
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<void> _basicCrudFlow({required SearchMode mode, required Metric metric}) async {
    final love = LoVeDB(dimension: 4, metric: metric, mode: mode);
    final c = await love.collection('col');

    await c.insert(id: nanoid(), text: 'a', vector: [1, 0, 0, 0]);
    await c.insert(id: nanoid(), text: 'b', vector: [0, 1, 0, 0]);
    await c.insert(id: nanoid(), text: 'c', vector: [0, 0, 1, 0]);

    final results = await c.find(vector: [1, 0, 0, 0], limit: 2);
    expect(results, isNotEmpty);
    expect(results.first.text, 'a');
    expect(results.length, 2);

    await c.delete(id: results.first.id);
    final afterDelete = await c.find(vector: [1, 0, 0, 0], limit: 3);
    expect(afterDelete.where((d) => d.text == 'a'), isEmpty);

    await c.dispose();
  }

  test('bruteForce + cosine basic CRUD and search order', () async {
    await _basicCrudFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('bruteForce + euclidean basic CRUD and search order', () async {
    await _basicCrudFlow(mode: SearchMode.bruteForce, metric: Metric.euclidean);
  });

  test('hnsw + cosine basic CRUD and search order + rebuild on open', () async {
    final love = LoVeDB(dimension: 4, metric: Metric.cosine, mode: SearchMode.hnsw);
    var c = await love.collection('col2');

    await c.insert(id: nanoid(), text: 'x', vector: [0.9, 0.0, 0.0, 0.0]);
    await c.insert(id: nanoid(), text: 'y', vector: [0.0, 0.9, 0.0, 0.0]);
    await c.dispose();

    // Reopen: should rebuild HNSW from SQLite
    c = await love.collection('col2');
    final res = await c.find(vector: [1, 0, 0, 0], limit: 1);
    expect(res.first.text, 'x');
    await c.dispose();
  });

  test('hnsw + euclidean basic CRUD and search order + rebuild on open', () async {
    final love = LoVeDB(dimension: 4, metric: Metric.euclidean, mode: SearchMode.hnsw);
    var c = await love.collection('col3');

    await c.insert(id: nanoid(), text: 'x', vector: [1, 0, 0, 0]);
    await c.insert(id: nanoid(), text: 'y', vector: [0, 1, 0, 0]);
    await c.dispose();

    // Reopen: should rebuild HNSW from SQLite
    c = await love.collection('col3');
    final res = await c.find(vector: [0.9, 0, 0, 0], limit: 1);
    expect(res.first.text, 'x');
    await c.dispose();
  });
}
