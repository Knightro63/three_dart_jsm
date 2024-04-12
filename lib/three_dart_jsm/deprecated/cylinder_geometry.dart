import 'geometry.dart';

class CylinderGeometry extends Geometry {
  String type = "CylinderGeometry";

  CylinderGeometry(double radiusTop, double radiusBottom, double height, int radialSegments,
      int heightSegments, bool openEnded, num thetaStart, double thetaLength)
      : super() {
    this.parameters = {
      "radiusTop": radiusTop,
      "radiusBottom": radiusBottom,
      "height": height,
      "radialSegments": radialSegments,
      "heightSegments": heightSegments,
      "openEnded": openEnded,
      "thetaStart": thetaStart,
      "thetaLength": thetaLength
    };

    this.fromBufferGeometry(CylinderGeometry(
        radiusTop,
        radiusBottom,
        height,
        radialSegments,
        heightSegments,
        openEnded,
        thetaStart,
        thetaLength));
    this.mergeVertices();
  }
}
