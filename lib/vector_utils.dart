import 'dart:typed_data';

class VectorUtils {
  static Uint8List vectorToBytes(List<double> v) {
    final b = BytesBuilder();
    final buf = ByteData(4 * v.length);
    for (int i = 0; i < v.length; i++) {
      buf.setFloat32(i * 4, v[i], Endian.little);
    }
    b.add(buf.buffer.asUint8List());
    return b.toBytes();
  }

  static List<double> bytesToVector(Uint8List bytes, int dim) {
    final bd = ByteData.sublistView(bytes);
    final out = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) out[i] = bd.getFloat32(i * 4, Endian.little);
    return out;
  }
}