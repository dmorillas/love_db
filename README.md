# **LoVeDB: Local Vector Database for Flutter 🧡**

A simple, fast, and local vector database for your Flutter applications. LoVeDB uses SQLite for persistent storage and offers two powerful search modes: brute-force and HNSW (Hierarchical Navigable Small World) indexing for efficient approximate nearest neighbor (ANN) searches.

## **✨ Features**

* **Two Search Modes:** Choose between a simple brute-force search or a highly optimized HNSW index for lightning-fast ANN searches.
* **Local & Lightweight:** Stores data directly on the user's device, making it ideal for offline-first applications.
* **Configurable Metrics:** Supports both **Cosine Similarity** and **Euclidean Distance** for vector comparison.
* **Clean API:** A straightforward, easy-to-use API for embedding storage, retrieval, and search.

## **🚀 Getting Started**

Add love\_db to your pubspec.yaml file:

```yaml
dependencies:
  love_db: ^1.0.0
```

Then run `flutter pub get`.

## **📦 Usage**

### **1\. Initialize the Database**

First, initialize a new LoVeDB instance. You must specify the dimension of your vectors. The metric and mode are optional.

```dart
import 'package:love_db/love_db.dart';

final db = LoVeDB(  
  dimension: 1536, // The dimension of your vector embeddings  
  metric: Metric.cosine, // Optional. By default: Metric.cosine  
  mode: SearchMode.hnsw, // Optional. By default: SearchMode.hnsw  
);
```

### **2\. Get a Collection**

A Collection is a named space to store your documents and vectors. Call `collection()` to get a new or existing collection.

```dart
final myCollection = await db.collection('my_documents');
```

### **3\. Insert Documents**

Insert a new document with its vector, text, and optional metadata.

```dart
final id = "document_id"; // The id for this entry
final vector = [0.1, 0.2, ...]; // Your vector embedding  
final text = "This is a sample document.";  
final metadata = {"author": "John Doe", "category": "Flutter"};

await myCollection.insert(
  id: id,
  vector: vector,  
  text: text,  
  metadata: metadata,  
);
```

### **4\. Search for Documents**

Search for the most similar documents by providing a query vector.

```dart
final queryVector = [0.9, 0.8, ...];  
final results = await myCollection.find(  
  vector: queryVector,  
  limit: 5, // Optional: Number of top results to return (default is 10)
);

for (final doc in results) {  
  print('Found document: ${doc.text} with ID ${doc.id}');  
}
```

### **5\. Delete Documents**

You can delete a document by its ID.

```dart
await myCollection.delete(id: "document-id-123");
```

### **6\. Clean Up**

It's important to dispose of the collection to close the underlying database connection.

```dart
await myCollection.dispose();
```

## **⚙️ Configuration**

* **dimension**: The number of elements in your vector embeddings. This is a required parameter.
* **metric**: The distance metric to use for searching.
  * Metric.cosine (default): Measures the cosine of the angle between two vectors. Higher values mean more similar.
  * Metric.euclidean: Measures the straight-line distance between two vectors. Lower values mean more similar.
* **mode**: The search algorithm to use.
  * SearchMode.hnsw (default): Uses an HNSW index for fast approximate nearest neighbor search.
  * SearchMode.bruteForce: Performs a linear scan through all vectors. Slower, but guarantees exact results.

## **📝 Contribution**

Feel free to open an issue or submit a pull request on GitHub.

## **ℹ️ License**

This project is licensed under the MIT License. See `LICENSE` for details.