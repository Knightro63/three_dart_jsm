import 'package:three_dart/three3d/three.dart';
import 'geometry.dart';

/**
 * Creates extruded geometry from a path shape.
 *
 * parameters = {
 *
 *  curveSegments: <int>, // number of points on the curves
 *  steps: <int>, // number of points for z-side extrusions / used for subdividing segments of extrude spline too
 *  depth: <float>, // Depth to extrude the shape
 *
 *  bevelEnabled: <bool>, // turn on bevel
 *  bevelThickness: <float>, // how deep into the original shape bevel goes
 *  bevelSize: <float>, // how far from shape outline (including bevelOffset) is bevel
 *  bevelOffset: <float>, // how far from shape outline does bevel start
 *  bevelSegments: <int>, // number of bevel layers
 *
 *  extrudePath: <THREE.Curve> // curve to extrude shape along
 *
 *  UVGenerator: <Object> // object that provides UV generator functions
 *
 * }
 */

class ExtrudeGeometry extends Geometry {
  String type = "ExtrudeGeometry";

  ExtrudeGeometry(List<Shape> shapes, ExtrudeGeometryOptions options) : super() {
    this.parameters = {"shapes": shapes, "options": options};

    this.fromBufferGeometry(ExtrudeGeometry(shapes, options));
    this.mergeVertices();
  }

  Map<String,dynamic> toJSON() {
    final data = super.toJSON();

    final shapes = this.parameters["shapes"];
    final options = this.parameters["options"];

    return toJSON3(shapes, options, data);
  }

  Function toJSON3 = (shapes, options, data) {
    data.shapes = [];

    if (shapes is List) {
      for (int i = 0, l = shapes.length; i < l; i++) {
        final shape = shapes[i];

        data.shapes.add(shape.uuid);
      }
    } else {
      data.shapes.add(shapes.uuid);
    }

    if (options.extrudePath != null)
      data.options.extrudePath = options.extrudePath.toJSON();

    return data;
  };
}
