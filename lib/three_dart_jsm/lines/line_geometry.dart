import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

import 'line_segments_geometry.dart';

class LineGeometry extends LineSegmentsGeometry {
  String type = 'LineGeometry';
  bool isLineGeometry = true;

  LineGeometry():super();

  LineGeometry setPositions(array) {
    // converts [ x1, y1, z1,  x2, y2, z2, ... ] to pairs format

    int length = array.length - 3;
    final points = Float32Array(2 * length);

    for (int i = 0; i < length; i += 3) {
      points[2 * i] = array[i];
      points[2 * i + 1] = array[i + 1];
      points[2 * i + 2] = array[i + 2];

      points[2 * i + 3] = array[i + 3];
      points[2 * i + 4] = array[i + 4];
      points[2 * i + 5] = array[i + 5];
    }

    super.setPositions(points);

    return this;
  }

  LineGeometry setColors(array) {
    // converts [ r1, g1, b1,  r2, g2, b2, ... ] to pairs format

    int length = array.length - 3;
    final colors = Float32Array(2 * length);

    for (int i = 0; i < length; i += 3) {
      colors[2 * i] = array[i];
      colors[2 * i + 1] = array[i + 1];
      colors[2 * i + 2] = array[i + 2];

      colors[2 * i + 3] = array[i + 3];
      colors[2 * i + 4] = array[i + 4];
      colors[2 * i + 5] = array[i + 5];
    }

    super.setColors(colors);

    return this;
  }

  LineGeometry fromLine(line) {
    final geometry = line.geometry;

    if (geometry.isGeometry) {
      this.setPositions(geometry.vertices);
    } else if (geometry.isBufferGeometry) {
      this.setPositions(
          geometry.attributes.position.array); // assumes non-indexed

    }

    // set colors, maybe

    return this;
  }

  LineGeometry copy(BufferGeometry source) {
    // todo

    return this;
  }
}
