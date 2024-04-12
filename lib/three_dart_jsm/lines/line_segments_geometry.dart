import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

class LineSegmentsGeometry extends InstancedBufferGeometry {
  String type = "LineSegmentsGeometry";
  bool isLineSegmentsGeometry = true;

  LineSegmentsGeometry() : super() {
    List<double> positions = [-1,2,0,1,2,0,-1,1,0,1,1,0,-1,0,0,1,0,0,-1,-1,0,1,-1,0];
    List<double> uvs = [-1, 2, 1, 2, -1, 1, 1, 1, -1, -1, 1, -1, -1, -2, 1, -2];
    List<int> index = [0, 2, 1, 2, 3, 1, 2, 4, 3, 4, 5, 3, 4, 6, 5, 6, 7, 5];

    this.setIndex(index);
    this.setAttribute('position',
        Float32BufferAttribute(Float32Array.from(positions), 3, false));
    this.setAttribute(
        'uv', Float32BufferAttribute(Float32Array.from(uvs), 2, false));
  }

  LineSegmentsGeometry applyMatrix4(matrix) {
    final start = this.attributes["instanceStart"];
    final end = this.attributes["instanceEnd"];

    if (start != null) {
      start.applyMatrix4(matrix);

      end.applyMatrix4(matrix);

      start.needsUpdate = true;
    }

    if (this.boundingBox != null) {
      this.computeBoundingBox();
    }

    if (this.boundingSphere != null) {
      this.computeBoundingSphere();
    }

    return this;
  }

  LineSegmentsGeometry setPositions(array) {
    final lineSegments;

    if (array is Float32Array) {
      lineSegments = array;
    } 
    else if (array is List) {
      lineSegments = Float32Array.from(List<double>.from(array));
    }
    else{
      lineSegments = array;
    }

    final instanceBuffer = InstancedInterleavedBuffer(lineSegments, 6, 1); // xyz, xyz

    this.setAttribute('instanceStart',
        InterleavedBufferAttribute(instanceBuffer, 3, 0, false)); // xyz
    this.setAttribute('instanceEnd',
        InterleavedBufferAttribute(instanceBuffer, 3, 3, false)); // xyz

    //

    this.computeBoundingBox();
    this.computeBoundingSphere();

    return this;
  }

  LineSegmentsGeometry setColors(array) {
    final colors;

    if (array is Float32Array) {
      colors = array;
    } 
    else if (array is List) {
      colors = Float32Array.from(List<double>.from(array));
    }
    else{
      colors = array;
    }

    final instanceColorBuffer = InstancedInterleavedBuffer(colors, 6, 1); // rgb, rgb

    this.setAttribute(
        'instanceColorStart',
        InterleavedBufferAttribute(
            instanceColorBuffer, 3, 0, false)); // rgb
    this.setAttribute(
        'instanceColorEnd',
        InterleavedBufferAttribute(
            instanceColorBuffer, 3, 3, false)); // rgb

    return this;
  }

  LineSegmentsGeometry fromWireframeGeometry(geometry) {
    this.setPositions(geometry.attributes.position.array);

    return this;
  }

  LineSegmentsGeometry fromEdgesGeometry(geometry) {
    this.setPositions(geometry.attributes.position.array);

    return this;
  }

  LineSegmentsGeometry fromMesh(mesh) {
    this.fromWireframeGeometry(WireframeGeometry(mesh.geometry));

    // set colors, maybe

    return this;
  }

  LineSegmentsGeometry fromLineSegments(lineSegments) {
    final geometry = lineSegments.geometry;

    if (geometry.isGeometry) {
      this.setPositions(geometry.vertices);
    } else if (geometry.isBufferGeometry) {
      this.setPositions(
          geometry.attributes.position.array); // assumes non-indexed

    }

    // set colors, maybe

    return this;
  }

  void computeBoundingBox() {
    final box = Box3(null, null);

    if (this.boundingBox == null) {
      this.boundingBox = Box3(null, null);
    }

    final start = this.attributes["instanceStart"];
    final end = this.attributes["instanceEnd"];

    if (start != null && end != null) {
      this.boundingBox!.setFromBufferAttribute(start);

      box.setFromBufferAttribute(end);

      this.boundingBox!.union(box);
    }
  }

  void computeBoundingSphere() {
    final vector = Vector3();

    if (this.boundingSphere == null) {
      this.boundingSphere = Sphere(null, null);
    }

    if (this.boundingBox == null) {
      this.computeBoundingBox();
    }

    final start = this.attributes["instanceStart"];
    final end = this.attributes["instanceEnd"];

    if (start != null && end != null) {
      final center = this.boundingSphere!.center;

      this.boundingBox!.getCenter(center);

      num maxRadiusSq = 0;

      for (int i = 0, il = start.count; i < il; i++) {
        vector.fromBufferAttribute(start, i);
        maxRadiusSq = Math.max(maxRadiusSq, center.distanceToSquared(vector));

        vector.fromBufferAttribute(end, i);
        maxRadiusSq = Math.max(maxRadiusSq, center.distanceToSquared(vector));
      }

      this.boundingSphere!.radius = Math.sqrt(maxRadiusSq);

      if (this.boundingSphere?.radius == null) {
        print('THREE.LineSegmentsGeometry.computeBoundingSphere(): Computed radius is NaN. The instanced position data is likely to have NaN values. ${this}');
      }
    }
  }

  // toJSON({}) {

  // 	// todo
  //   print(" toJSON TODO ...........");

  // }

  LineSegmentsGeometry applyMatrix(matrix) {
    print('THREE.LineSegmentsGeometry: applyMatrix() has been renamed to applyMatrix4().');
    return this.applyMatrix4(matrix);
  }
}
