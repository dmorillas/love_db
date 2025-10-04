import 'package:local_hnsw/local_hnsw.dart';
import 'package:local_hnsw/local_hnsw.item.dart';
import 'package:love_db/model/document.dart';
import 'package:love_db/domain/collection.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/repository/repository.dart';
import 'package:love_db/vector_utils.dart';

class HnswCollection extends Collection {
  late LocalHNSW<String> _hnswIndex;

  HnswCollection._internal({
    required name,
    required repository,
    required dimension,
    required Metric metric,
  }): super(name, repository, dimension, metric) {
    _hnswIndex = LocalHNSW<String>(
      dim: dimension,
      metric: (metric == Metric.cosine) ? LocalHnswMetric.cosine : LocalHnswMetric.euclidean,
    );
  }

  static Future<HnswCollection> initialize({
    required String name,
    required Repository repository,
    required int dimension,
    required Metric metric,
  }) async {
    final instance = HnswCollection._internal(
      name: name,
      repository: repository,
      dimension: dimension,
      metric: metric,
    );

    final vectors = await repository.getVectors();
    for (final vector in vectors) {
      final embedding = VectorUtils.bytesToVector(vector.vector, dimension);
      instance._hnswIndex.add(LocalHnswItem<String>(item: vector.id, vector: embedding));
    }

    return instance;
  }

  @override
  Future<void> insert({required String id, required List<double> vector, required String text, Map<String, dynamic>? metadata}) async {
    await super.insert(id: id, vector: vector, text: text, metadata: metadata);
    _hnswIndex.add(LocalHnswItem<String>(item: id, vector: vector));
  }

  @override
  Future<void> delete({required String id}) async {
    await super.delete(id: id);
    _hnswIndex.delete(id);
  }

  @override
  Future<List<Document>> find({required List<double> vector, int limit = 10}) async {
    if (vector.length != dimension) {
      throw ArgumentError('Query vector length (${vector.length}) must equal collection dimension (${dimension}).');
    }
    final items = _hnswIndex.search(vector, limit).items;
    final ids = items.map((e) => e.item).toList();

    if (ids.isEmpty) {
      return [];
    }

    return await getDocuments(ids: ids);
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}