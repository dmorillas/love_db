import 'package:love_db/model/document.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/repository/repository.dart';
import 'package:love_db/vector_utils.dart';

abstract class Collection {
  final String name;
  final Repository repository;
  final int dimension;
  final Metric metric;

  Collection(this.name, this.repository, this.dimension, this.metric);

  Future<List<Document>> find({required List<double> vector, int limit = 10});

  Future<List<Document>> getDocuments({required List<String> ids}) async {
    final documents = await repository.getDocuments(ids: ids);
    final documentsById = {
      for (final document in documents) document.id: document
    };

    final response = <Document>[];
    for (final id in ids) {
      final doc = documentsById[id];
      if (doc != null) response.add(doc);
    }

    return response;
  }

  Future<void> insert({required String id, required List<double> vector, required String text, Map<String, dynamic>? metadata}) async {
    if (vector.length != dimension) {
      throw ArgumentError('Vector length (${vector.length}) must equal collection dimension ($dimension).');
    }
    await repository.insert(id: id, vector: VectorUtils.vectorToBytes(vector), text: text, metadata: metadata);
  }

  Future<int> count() async {
    return await repository.count();
  }

  Future<void> delete({required String id}) async {
    await repository.delete(id: id);
  }

  Future<Document?> get({required String id}) async {
    final documents = await repository.getDocuments(ids: [id]);
    if (documents.isEmpty) return null;

    return documents.first;
  }

  Future<void> dispose() async {
    await repository.dispose();
  }
}