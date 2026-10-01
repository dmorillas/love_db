import 'dart:typed_data';

import 'package:love_db/model/document.dart';
import 'package:love_db/model/vector.dart';

abstract class Repository {
  Future<void> insert({required String id, required Uint8List vector, required String text, Map<String, dynamic>? metadata});
  Future<void> insertMany({required List<String> ids, required List<Uint8List> vectors, required List<String> texts, List<Map<String, dynamic>>? metadatas});
  Future<void> upsert({required String id, required Uint8List vector, required String text, Map<String, dynamic>? metadata});
  Future<List<Vector>> getVectors();
  Future<List<Document>> getDocuments({required List<String> ids});
  Future<int> count();
  Future<void> delete({required String id});
  Future<void> dispose();
}