import 'package:three_dart/three3d/three.dart';
import 'geometry.dart';

class ConvexGeometry extends Geometry {
  String type = "ConvexGeometry";

  ConvexGeometry(List<Vector3>? points) : super() {
    this.fromBufferGeometry(ConvexGeometry(points ?? []));
    this.mergeVertices();
  }
}
