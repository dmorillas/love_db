class Document {
  Document({required this.id, required this.text, Map<String, dynamic>? metadata})
      : metadata = metadata ?? <String, dynamic>{};

  final String id;
  final String text;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'metadata': metadata,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
        id: json['id'],
        text: json['text'],
        metadata: Map<String, dynamic>.from(json['metadata'])
    );
  }
}