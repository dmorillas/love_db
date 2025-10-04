import 'dart:typed_data';

class Vector {
  Vector({required this.id, required this.vector});

  final String id;
  final Uint8List vector;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vector': vector,
    };
  }

  factory Vector.fromJson(Map<String, dynamic> json) {
    return Vector(
      id: json['id'],
      vector: json['vector'],
    );
  }
}