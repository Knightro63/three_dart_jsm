import 'geometry.dart';

class CircleGeometry extends Geometry {
  String type = "CircleGeometry";

  CircleGeometry(double radius, int segments, int thetaStart, double thetaLength) : super() {
    this.parameters = {
      "radius": radius,
      "segments": segments,
      "thetaStart": thetaStart,
      "thetaLength": thetaLength
    };

    this.fromBufferGeometry(CircleGeometry(radius,segments,thetaStart,thetaLength));
    this.mergeVertices();
  }
}
