import 'geometry.dart';

class BoxGeometry extends Geometry {
  BoxGeometry(double width,double height,double depth,[int widthSegments = 1, int heightSegments = 1, int depthSegments = 1]):super() {
    this.parameters = {
      "width": width,
      "height": height,
      "depth": depth,
      "widthSegments": widthSegments,
      "heightSegments": heightSegments,
      "depthSegments": depthSegments
    };

    this.fromBufferGeometry(BoxGeometry(width, height, depth, widthSegments, heightSegments, depthSegments));
    this.mergeVertices();
  }
}
