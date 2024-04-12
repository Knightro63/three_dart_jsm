import 'geometry.dart';

class IcosahedronGeometry extends Geometry {
  String type = "IcosahedronGeometry";

  IcosahedronGeometry(num radius, int detail) : super() {
    this.parameters = {"radius": radius, "detail": detail};

    this.fromBufferGeometry(IcosahedronGeometry(radius, detail));
    this.mergeVertices();
  }
}
