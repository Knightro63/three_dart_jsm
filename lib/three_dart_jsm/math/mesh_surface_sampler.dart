import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

/**
 * Utility class for sampling weighted random points on the surface of a mesh.
 *
 * Building the sampler is a one-time O(n) operation. Once built, any number of
 * random samples may be selected in O(logn) time. Memory usage is O(n).
 *
 * References:
 * - http://www.joesfer.com/?p=84
 * - https://stackoverflow.com/a/4322940/1314762
 */

class MeshSurfaceSampler {
  final _face = Triangle();
  final _color = Vector3();

  late BufferGeometry geometry;
  late Function randomFunction;
  late BufferAttribute positionAttribute;
  late BufferAttribute? colorAttribute;
  BufferAttribute? weightAttribute;
  Float32Array? distribution;

  MeshSurfaceSampler(Mesh mesh) {
    BufferGeometry? geometry = mesh.geometry;

    if (geometry?.attributes['position'].itemSize != 3) {
      throw ('THREE.MeshSurfaceSampler: Requires BufferGeometry triangle mesh.');
    }

    if (geometry?.index != null ) {
      print('THREE.MeshSurfaceSampler: Converting geometry to non-indexed BufferGeometry.');
      geometry = geometry!.toNonIndexed();
    }

    this.geometry = geometry!;
    this.randomFunction = Math.random;

    this.positionAttribute = this.geometry.getAttribute('position');
    this.colorAttribute = this.geometry.getAttribute('color');
    this.weightAttribute = null;

    this.distribution = null;
  }

  MeshSurfaceSampler setWeightAttribute(String? name) {
    this.weightAttribute = name != null? this.geometry.getAttribute(name) : null;
    return this;
  }

  MeshSurfaceSampler build() {
    final positionAttribute = this.positionAttribute;
    final weightAttribute = this.weightAttribute;

    final faceWeights = Float32Array(positionAttribute.count ~/ 3);

    // Accumulate weights for each mesh face.

    for (int i = 0; i < positionAttribute.count; i += 3) {
      double faceWeight = 1;

      if (weightAttribute != null) {
        faceWeight = weightAttribute.getX(i)!.toDouble() +
            weightAttribute.getX(i + 1)!.toDouble() +
            weightAttribute.getX(i + 2)!.toDouble();
      }

      _face.a.fromBufferAttribute(positionAttribute, i);
      _face.b.fromBufferAttribute(positionAttribute, i + 1);
      _face.c.fromBufferAttribute(positionAttribute, i + 2);
      faceWeight *= _face.getArea();

      faceWeights[i ~/ 3] = faceWeight;
    }

    // Store cumulative total face weights in an array, where weight index
    // corresponds to face index.

    this.distribution = Float32Array(positionAttribute.count ~/ 3);

    double cumulativeTotal = 0;

    for (int i = 0; i < faceWeights.length; i++) {
      cumulativeTotal += faceWeights[i];

      this.distribution![i] = cumulativeTotal;
    }

    return this;
  }

  MeshSurfaceSampler setRandomGenerator(Function randomFunction) {
    this.randomFunction = randomFunction;
    return this;
  }

  MeshSurfaceSampler sample(Vector3 targetPosition, [Vector3? targetNormal, Color? targetColor]) {
    final cumulativeTotal = this.distribution![this.distribution!.length - 1];
    final faceIndex = this.binarySearch(this.randomFunction() * cumulativeTotal);

    return this.sampleFace(faceIndex, targetPosition, targetNormal, targetColor);
  }

  int binarySearch(int x) {
    final dist = this.distribution!;
    int start = 0;
    int end = dist.length - 1;

    int index = -1;

    while (start <= end) {
      final mid = Math.ceil((start + end) / 2);

      if (mid == 0 || dist[mid - 1] <= x && dist[mid] > x) {
        index = mid;

        break;
      } else if (x < dist[mid]) {
        end = mid - 1;
      } else {
        start = mid + 1;
      }
    }

    return index;
  }

  MeshSurfaceSampler sampleFace(int faceIndex, Vector3 targetPosition, [Vector3? targetNormal, Color? targetColor]) {
    int u = this.randomFunction();
    int v = this.randomFunction();

    if (u + v > 1) {
      u = 1 - u;
      v = 1 - v;
    }

    _face.a.fromBufferAttribute(this.positionAttribute, faceIndex * 3);
    _face.b.fromBufferAttribute(this.positionAttribute, faceIndex * 3 + 1);
    _face.c.fromBufferAttribute(this.positionAttribute, faceIndex * 3 + 2);

    targetPosition
        .set(0, 0, 0)
        .addScaledVector(_face.a, u)
        .addScaledVector(_face.b, v)
        .addScaledVector(_face.c, 1 - (u + v));

    if (targetNormal != null) {
      _face.getNormal(targetNormal);
    }

    if (targetColor != null && this.colorAttribute != null) {
      _face.a.fromBufferAttribute(this.colorAttribute!, faceIndex * 3);
      _face.b.fromBufferAttribute(this.colorAttribute!, faceIndex * 3 + 1);
      _face.c.fromBufferAttribute(this.colorAttribute!, faceIndex * 3 + 2);

      _color
          .set(0, 0, 0)
          .addScaledVector(_face.a, u)
          .addScaledVector(_face.b, v)
          .addScaledVector(_face.c, 1 - (u + v));

      targetColor.r = _color.x;
      targetColor.g = _color.y;
      targetColor.b = _color.z;
    }

    return this;
  }
}
