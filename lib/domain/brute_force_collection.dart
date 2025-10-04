import 'dart:math';

import 'package:love_db/model/document.dart';
import 'package:love_db/domain/collection.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/vector_utils.dart';

class BruteForceCollection extends Collection {

  BruteForceCollection({
    required name,
    required repository,
    required dimension,
    required metric,
  }) : super(name, repository, dimension, metric);

  @override
  Future<List<Document>> find({required List<double> vector, int limit = 10}) async {
    if (vector.length != dimension) {
      throw ArgumentError('Query vector length (${vector.length}) must equal collection dimension ($dimension).');
    }
    final vectors = await repository.getVectors();
    final results = <String, double>{};

    for (var row in vectors) {
      final v = VectorUtils.bytesToVector(row.vector, dimension);
      final distance = (metric == Metric.cosine) ? _cosineSimilarity(vector, v) : _euclideanDistance(vector, v);
      results[row.id] = distance;
    }

    final sortedEntries = results.entries.toList()
      ..sort((a, b) => (metric == Metric.cosine)
          ? b.value.compareTo(a.value)
          : a.value.compareTo(b.value)
      );
    final ids = sortedEntries.take(limit).map((e) => e.key).toList();

    if (ids.isEmpty) {
      return [];
    }

    return await getDocuments(ids: ids);
  }

  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError('Vectors must have the same length.');
    }

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      magnitude1 += v1[i] * v1[i];
      magnitude2 += v2[i] * v2[i];
    }
    final double denom = sqrt(magnitude1) * sqrt(magnitude2);
    if (denom == 0) return 0.0;
    return dotProduct / denom;
  }

  double _euclideanDistance(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError('Vectors must have the same length.');
    }

    double sum = 0;

    for (int i = 0; i < v1.length; i++) {
      final diff = v1[i] - v2[i];
      sum += diff * diff;
    }

    return sqrt(sum);
  }
}