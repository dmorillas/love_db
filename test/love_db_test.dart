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

  Future<void> basicCrudFlow({required SearchMode mode, required Metric metric}) async {
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
    await basicCrudFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('bruteForce + euclidean basic CRUD and search order', () async {
    await basicCrudFlow(mode: SearchMode.bruteForce, metric: Metric.euclidean);
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

  Future<void> upsertInsertFlow({required SearchMode mode, required Metric metric}) async {
    final love = LoVeDB(dimension: 4, metric: metric, mode: mode);
    final c = await love.collection('upsert_insert');

    final id = nanoid();
    await c.upsert(id: id, text: 'original', vector: [1, 0, 0, 0]);

    final results = await c.find(vector: [1, 0, 0, 0], limit: 1);
    expect(results.length, 1);
    expect(results.first.text, 'original');
    expect(results.first.id, id);

    await c.dispose();
  }

  test('bruteForce + cosine upsert inserts new document', () async {
    await upsertInsertFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('hnsw + cosine upsert inserts new document', () async {
    await upsertInsertFlow(mode: SearchMode.hnsw, metric: Metric.cosine);
  });

  Future<void> upsertUpdateFlow({required SearchMode mode, required Metric metric}) async {
    final love = LoVeDB(dimension: 4, metric: metric, mode: mode);
    final c = await love.collection('upsert_update');

    final id = nanoid();
    await c.insert(id: id, text: 'before', vector: [1, 0, 0, 0]);

    await c.upsert(id: id, text: 'after', vector: [0, 1, 0, 0], metadata: {"key": "value"});

    final doc = await c.get(id: id);
    expect(doc, isNotNull);
    expect(doc!.text, 'after');
    expect(doc.metadata['key'], 'value');

    final count = await c.count();
    expect(count, 1);

    await c.dispose();
  }

  test('bruteForce + cosine upsert updates existing document', () async {
    await upsertUpdateFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('hnsw + cosine upsert updates existing document', () async {
    await upsertUpdateFlow(mode: SearchMode.hnsw, metric: Metric.cosine);
  });

  test('hnsw + euclidean upsert updates HNSW index correctly', () async {
    final love = LoVeDB(dimension: 4, metric: Metric.euclidean, mode: SearchMode.hnsw);
    final c = await love.collection('upsert_hnsw_index');

    final id = nanoid();
    await c.insert(id: id, text: 'far', vector: [0, 1, 0, 0]);
    await c.insert(id: nanoid(), text: 'close', vector: [0.9, 0, 0, 0]);

    var results = await c.find(vector: [1, 0, 0, 0], limit: 2);
    expect(results.first.text, 'close');

    await c.upsert(id: id, text: 'updated_close', vector: [0.95, 0, 0, 0]);

    results = await c.find(vector: [1, 0, 0, 0], limit: 2);
    expect(results.first.text, 'updated_close');
    expect(results.first.id, id);

    final count = await c.count();
    expect(count, 2);

    await c.dispose();
  });

  Future<void> findReturnsDistanceFlow({required SearchMode mode, required Metric metric}) async {
    final love = LoVeDB(dimension: 4, metric: metric, mode: mode);
    final c = await love.collection('find_distance');

    await c.insert(id: 'doc-a', text: 'a', vector: [1, 0, 0, 0]);
    await c.insert(id: 'doc-b', text: 'b', vector: [0.8, 0.6, 0, 0]);
    await c.insert(id: 'doc-c', text: 'c', vector: [0, 0, 1, 0]);

    final results = await c.find(vector: [1, 0, 0, 0], limit: 3);

    expect(results, isNotEmpty);
    expect(results.every((d) => d.distance != null), isTrue);

    expect(results.first.text, 'a');
    expect(results.first.distance, metric == Metric.cosine ? closeTo(1.0, 0.01) : closeTo(0.0, 0.01));

    final fetched = await c.get(id: 'doc-a');
    expect(fetched!.distance, isNull);

    await c.dispose();
  }

  test('bruteForce + cosine find returns distance', () async {
    await findReturnsDistanceFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('bruteForce + euclidean find returns distance', () async {
    await findReturnsDistanceFlow(mode: SearchMode.bruteForce, metric: Metric.euclidean);
  });

  test('hnsw + cosine find returns distance', () async {
    await findReturnsDistanceFlow(mode: SearchMode.hnsw, metric: Metric.cosine);
  });

  test('hnsw + euclidean find returns distance', () async {
    await findReturnsDistanceFlow(mode: SearchMode.hnsw, metric: Metric.euclidean);
  });

  Future<void> insertManyFlow({required SearchMode mode, required Metric metric}) async {
    final love = LoVeDB(dimension: 4, metric: metric, mode: mode);
    final c = await love.collection('insert_many');

    await c.insertMany(
      ids: ['doc-a', 'doc-b', 'doc-c'],
      texts: ['a', 'b', 'c'],
      vectors: [
        [1, 0, 0, 0],
        [0.9, 0.1, 0, 0],
        [0, 0, 1, 0],
      ],
      metadatas: [
        {"author": "Ada"},
        {"author": "Alan"},
        {"author": "Grace"},
      ],
    );

    expect(await c.count(), 3);

    // Every document is persisted and keeps its id / text / metadata pairing.
    for (final expected in {'doc-a': 'Ada', 'doc-b': 'Alan', 'doc-c': 'Grace'}.entries) {
      final doc = await c.get(id: expected.key);
      expect(doc, isNotNull);
      expect(doc!.text, expected.key.substring(4));
      expect(doc.metadata['author'], expected.value);
    }

    // HNSW is approximate, so only the nearest hit is guaranteed at this size.
    final results = await c.find(vector: [1, 0, 0, 0], limit: 3);
    expect(results, isNotEmpty);
    expect(results.first.id, 'doc-a');
    expect(results.every((d) => ['doc-a', 'doc-b', 'doc-c'].contains(d.id)), isTrue);

    await c.dispose();
  }

  test('bruteForce + cosine insertMany inserts and searches all documents', () async {
    await insertManyFlow(mode: SearchMode.bruteForce, metric: Metric.cosine);
  });

  test('bruteForce + euclidean insertMany inserts and searches all documents', () async {
    await insertManyFlow(mode: SearchMode.bruteForce, metric: Metric.euclidean);
  });

  test('hnsw + cosine insertMany inserts and searches all documents', () async {
    await insertManyFlow(mode: SearchMode.hnsw, metric: Metric.cosine);
  });

  test('hnsw + euclidean insertMany inserts and searches all documents', () async {
    await insertManyFlow(mode: SearchMode.hnsw, metric: Metric.euclidean);
  });

  test('insertMany works without metadata', () async {
    final love = LoVeDB(dimension: 4, mode: SearchMode.bruteForce);
    final c = await love.collection('insert_many_no_metadata');

    await c.insertMany(
      ids: ['doc-a', 'doc-b'],
      texts: ['a', 'b'],
      vectors: [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
      ],
    );

    final a = await c.get(id: 'doc-a');
    expect(a!.text, 'a');
    expect(a.metadata, isEmpty);

    await c.dispose();
  });

  test('insertMany rebuilds the HNSW index on open', () async {
    final love = LoVeDB(dimension: 4, mode: SearchMode.hnsw);
    var c = await love.collection('insert_many_rebuild');

    await c.insertMany(
      ids: ['doc-x', 'doc-y'],
      texts: ['x', 'y'],
      vectors: [
        [0.9, 0, 0, 0],
        [0, 0.9, 0, 0],
      ],
    );
    await c.dispose();

    c = await love.collection('insert_many_rebuild');
    final res = await c.find(vector: [1, 0, 0, 0], limit: 1);
    expect(res.first.text, 'x');
    expect(await c.count(), 2);
    await c.dispose();
  });

  test('insertMany throws when a document id already exists', () async {
    final love = LoVeDB(dimension: 4, mode: SearchMode.bruteForce);
    final c = await love.collection('insert_many_conflict');

    await c.insert(id: 'doc-a', text: 'a', vector: [1, 0, 0, 0]);

    expect(
      () => c.insertMany(
        ids: ['doc-new', 'doc-a'],
        texts: ['new', 'duplicate'],
        vectors: [
          [0, 0, 1, 0],
          [0, 1, 0, 0],
        ],
      ),
      throwsA(isA<DatabaseException>()),
    );

    // The whole batch is rolled back.
    expect(await c.count(), 1);
    expect(await c.get(id: 'doc-new'), isNull);

    await c.dispose();
  });

  test('insertMany validates its inputs', () async {
    final love = LoVeDB(dimension: 4, mode: SearchMode.bruteForce);
    final c = await love.collection('insert_many_validation');

    expect(
      () => c.insertMany(ids: [], texts: [], vectors: []),
      throwsArgumentError,
    );

    expect(
      () => c.insertMany(
        ids: ['a', 'b'],
        texts: ['only-one'],
        vectors: [
          [1, 0, 0, 0],
          [0, 1, 0, 0],
        ],
      ),
      throwsArgumentError,
    );

    expect(
      () => c.insertMany(
        ids: ['a'],
        texts: ['a'],
        vectors: [
          [1, 0, 0],
        ],
      ),
      throwsArgumentError,
    );

    expect(
      () => c.insertMany(
        ids: ['a'],
        texts: ['a'],
        vectors: [
          [1, 0, 0, 0],
        ],
        metadatas: [{}, {}],
      ),
      throwsArgumentError,
    );

    expect(await c.count(), 0);

    await c.dispose();
  });
}
