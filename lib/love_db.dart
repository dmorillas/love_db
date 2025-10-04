import 'package:love_db/domain/brute_force_collection.dart';
import 'package:love_db/domain/collection.dart';
import 'package:love_db/domain/hnsw_collection.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/model/search_mode.dart';
import 'package:love_db/repository/db_repository.dart';

class LoVeDB {
  final int dimension;
  final Metric metric;
  final SearchMode mode;

  LoVeDB({
    required this.dimension,
    this.metric = Metric.cosine,
    this.mode = SearchMode.hnsw,
  });

  Future<Collection> collection(String name) async {
    final repository = await DbRepository.create(name);

    if (mode == SearchMode.bruteForce) {
      return BruteForceCollection(name: name, repository: repository, metric: metric, dimension: dimension);
    }

    return await HnswCollection.initialize(name: name, repository: repository, dimension: dimension, metric: metric);
  }

  Future<void> dropCollection(String name) async {
    await DbRepository.remove(name);
  }
}
