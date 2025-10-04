import 'dart:convert';
import 'dart:typed_data';

import 'package:love_db/model/document.dart';
import 'package:love_db/model/vector.dart';
import 'package:love_db/repository/repository.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbRepository implements Repository {
  DbRepository._();

  late final Database _database;
  late final String _name;
  late final String _documentsTableName;
  late final String _vectorsTableName;

  static Future<DbRepository> create(String name) async {
    final repo = DbRepository._();
    await repo._open(name);
    return repo;
  }

  static Future<void> remove(String name) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "$name.db");

    await deleteDatabase(path);
  }

  Future<void> _open(String name) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "$name.db");

    _name = name;
    _documentsTableName = "love_db_${name}_documents";
    _vectorsTableName = "love_db_${name}_vectors";

    _database = await openDatabase(path, version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_documentsTableName (
            id TEXT PRIMARY KEY,
            text TEXT,
            metadata TEXT,
            created_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_vectorsTableName (
            id TEXT PRIMARY KEY,
            vector BLOB NOT NULL
          )
        ''');
      },
    );
  }

  @override
  Future<void> insert({required String id, required Uint8List vector, required String text, Map<String, dynamic>? metadata}) async {
    await _database.transaction((txn) async {
      await txn.insert(_documentsTableName, {
        "id": id,
        "text": text,
        "metadata": jsonEncode(metadata ?? <String, dynamic>{}),
        "created_at": DateTime.now().millisecondsSinceEpoch}
      );

      await txn.insert(_vectorsTableName, {"id": id, "vector": vector});
    });
  }

  @override
  Future<List<Vector>> getVectors() async {
    final result = await _database.query(_vectorsTableName);

    return result.map((row) => Vector(
      id: row['id'] as String,
      vector: row['vector'] as Uint8List,
    )).toList();
  }

  @override
  Future<List<Document>> getDocuments({required List<String> ids}) async {
    final result = await _database.query(
      _documentsTableName,
      where: "id IN (${List.filled(ids.length, '?').join(',')})",
      whereArgs: ids,
    );

    return result.map((row) => Document(
      id: row["id"] as String,
      text: row["text"] as String,
      metadata: Map<String, dynamic>.from(jsonDecode(row["metadata"] as String)),
    )).toList();
  }

  @override
  Future<int> count() async {
    final result = Sqflite.firstIntValue(
      await _database.rawQuery('SELECT COUNT(*) FROM $_documentsTableName'),
    );
    return result ?? 0;
  }

  @override
  Future<void> delete({required String id}) async {
    await _database.transaction((txn) async {
      await txn.delete(_documentsTableName, where: 'id = ?', whereArgs: [id]);
      await txn.delete(_vectorsTableName, where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> dispose() async {
    await _database.close();
  }
}