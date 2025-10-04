import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:love_db/love_db.dart';
import 'package:love_db/model/metric.dart';
import 'package:love_db/model/search_mode.dart';
import 'package:nanoid/nanoid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String content = await rootBundle.loadString("assets/embeddings.json");
  Map<String, dynamic> verbsWithEmbeddings = json.decode(content);
  final dbEmbeddings = verbsWithEmbeddings["db"].map(
      (key, value) => MapEntry(key, List<double>.from(value)),
  );
  final queryEmbeddings = verbsWithEmbeddings["query"].map(
      (key, value) => MapEntry(key, List<double>.from(value)),
  );

  final loveDB = LoVeDB(
    dimension: 1536,
    metric: Metric.cosine,
    mode: SearchMode.hnsw,
  );

  var collection = await loveDB.collection("the_name");
  for (var entry in dbEmbeddings.entries) {
    await collection.insert(id: nanoid(), vector: entry.value, text: entry.key);
  }

  for (var entry in queryEmbeddings.entries) {
    print("Searching '${entry.key}'");
    var results = await collection.find(vector: entry.value, limit: 2);
    for (var element in results) {
      print("${element.id}: ${element.text}");
    }
  }

  await loveDB.dropCollection("the_name");
}