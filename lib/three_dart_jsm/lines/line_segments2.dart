import 'package:three_dart/three_dart.dart';
import 'package:flutter_gl/flutter_gl.dart';

class LineSegments2 extends Mesh {
  String type = "LineSegments2";
  bool isLineSegments2 = true;

  LineSegments2([BufferGeometry? geometry, Material? material]) : super(geometry, material) {}

  // if ( geometry === undefined ) geometry = LineSegmentsGeometry();
  // if ( material === undefined ) material = LineMaterial( { color: Math.random() * 0xffffff } );

  LineSegments2 computeLineDistances() {
    // for backwards-compatability, but could be a method of LineSegmentsGeometry...

    final start = Vector3();
    final end = Vector3();    

    final geometry = this.geometry!;

    final instanceStart = geometry.attributes["instanceStart"];
    final instanceEnd = geometry.attributes["instanceEnd"];
    final lineDistances =
        Float32Array((2 * instanceStart.data.count).toInt());

    for (int i = 0, j = 0, l = instanceStart.data.count; i < l; i++, j += 2) {
      start.fromBufferAttribute(instanceStart, i);
      end.fromBufferAttribute(instanceEnd, i);

      lineDistances[j] = (j == 0) ? 0.0 : lineDistances[j - 1];
      lineDistances[j + 1] = lineDistances[j] + start.distanceTo(end);
    }

    final instanceDistanceBuffer =
        InstancedInterleavedBuffer(lineDistances, 2, 1); // d0, d1

    geometry.setAttribute(
        'instanceDistanceStart',
        InterleavedBufferAttribute(
            instanceDistanceBuffer, 1, 0, false)); // d0
    geometry.setAttribute(
        'instanceDistanceEnd',
        InterleavedBufferAttribute(
            instanceDistanceBuffer, 1, 1, false)); // d1

    return this;
  }

  void raycast(Raycaster raycaster, List<Intersection> intersects) {
    final start = Vector4();
    final end = Vector4();

    final ssOrigin = Vector4();
    final ssOrigin3 = Vector3();
    final mvMatrix = Matrix4();
    final line = Line3();
    final closestPoint = Vector3();

    final threshold = (raycaster.params["Line2"] != null)
        ? raycaster.params["Line2"].threshold ?? 0
        : 0;

    final ray = raycaster.ray;
    final camera = raycaster.camera;
    final projectionMatrix = camera.projectionMatrix;

    final geometry = this.geometry!;
    final material = this.material;
    final resolution = material.resolution;
    final lineWidth = material.linewidth + threshold;

    final instanceStart = geometry.attributes["instanceStart"];
    final instanceEnd = geometry.attributes["instanceEnd"];

    // pick a point 1 unit out along the ray to avoid the ray origin
    // sitting at the camera origin which will cause "w" to be 0 when
    // applying the projection matrix.
    ray.at(1, ssOrigin);
    // TODO ray.at need Vec3 but ssOrigin is vec4

    // ndc space [ - 1.0, 1.0 ]
    ssOrigin.w = 1;
    ssOrigin.applyMatrix4(camera.matrixWorldInverse);
    ssOrigin.applyMatrix4(projectionMatrix);
    ssOrigin.multiplyScalar(1 / ssOrigin.w);

    // screen space
    ssOrigin.x *= resolution.x / 2;
    ssOrigin.y *= resolution.y / 2;
    ssOrigin.z = 0;

    ssOrigin3.copy(ssOrigin);

    final matrixWorld = this.matrixWorld;
    mvMatrix.multiplyMatrices(camera.matrixWorldInverse, matrixWorld);

    for (int i = 0, l = instanceStart.count; i < l; i++) {
      start.fromBufferAttribute(instanceStart, i);
      end.fromBufferAttribute(instanceEnd, i);

      start.w = 1;
      end.w = 1;

      // camera space
      start.applyMatrix4(mvMatrix);
      end.applyMatrix4(mvMatrix);

      // clip space
      start.applyMatrix4(projectionMatrix);
      end.applyMatrix4(projectionMatrix);

      // ndc space [ - 1.0, 1.0 ]
      start.multiplyScalar(1 / start.w);
      end.multiplyScalar(1 / end.w);

      // skip the segment if it's outside the camera near and far planes
      final isBehindCameraNear = start.z < -1 && end.z < -1;
      final isPastCameraFar = start.z > 1 && end.z > 1;
      if (isBehindCameraNear || isPastCameraFar) {
        continue;
      }

      // screen space
      start.x *= resolution.x / 2;
      start.y *= resolution.y / 2;

      end.x *= resolution.x / 2;
      end.y *= resolution.y / 2;

      // create 2d segment
      line.start.copy(start);
      line.start.z = 0;

      line.end.copy(end);
      line.end.z = 0;

      // get closest point on ray to segment
      final param = line.closestPointToPointParameter(ssOrigin3, true);
      line.at(param, closestPoint);

      // check if the intersection point is within clip space
      final zPos = MathUtils.lerp(start.z, end.z, param);
      final isInClipSpace = zPos >= -1 && zPos <= 1;

      final isInside = ssOrigin3.distanceTo(closestPoint) < lineWidth * 0.5;

      if (isInClipSpace && isInside) {
        line.start.fromBufferAttribute(instanceStart, i);
        line.end.fromBufferAttribute(instanceEnd, i);

        line.start.applyMatrix4(matrixWorld);
        line.end.applyMatrix4(matrixWorld);

        final pointOnLine = Vector3();
        final point = Vector3();

        ray.distanceSqToSegment(line.start, line.end, point, pointOnLine);

        intersects.add(Intersection.fromJson({
          "point": point,
          "pointOnLine": pointOnLine,
          "distance": ray.origin.distanceTo(point),
          "object": this,
          "face": null,
          "faceIndex": i,
          "uv": null,
          "uv2": null,
        }));
      }
    }
  }
}
