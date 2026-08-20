class Document {
  Document({required this.id, required this.text, Map<String, dynamic>? metadata, this.distance})
      : metadata = metadata ?? <String, dynamic>{};

  final String id;
  final String text;
  final Map<String, dynamic> metadata;
  final double? distance;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'metadata': metadata,
      if (distance != null) 'distance': distance,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
        id: json['id'],
        text: json['text'],
        metadata: Map<String, dynamic>.from(json['metadata']),
        distance: json['distance']?.toDouble(),
    );
  }
}