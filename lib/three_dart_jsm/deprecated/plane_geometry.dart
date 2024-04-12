import 'geometry.dart';

class PlaneGeometry extends Geometry {
  String type = "PlaneGeometry";

  PlaneGeometry(num width, num height, [num widthSegments = 1, num heightSegments = 1]): super() {
    this.parameters = {
      "width": width,
      "height": height,
      "widthSegments": widthSegments,
      "heightSegments": heightSegments
    };

    this.fromBufferGeometry(PlaneGeometry(width, height, widthSegments, heightSegments));
    this.mergeVertices();
  }
}
