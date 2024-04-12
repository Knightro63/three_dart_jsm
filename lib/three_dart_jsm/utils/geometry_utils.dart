import 'package:three_dart/three3d/math/index.dart';
import 'package:three_dart/three_dart.dart';

class GeometryUtils {
  /**
	 * Generates 2D-Coordinates in a very fast way.
	 *
	 * Based on work by:
	 * @link http://www.openprocessing.org/sketch/15493
	 *
	 * @param center     Center of Hilbert curve.
	 * @param size       Total width of Hilbert curve.
	 * @param iterations Number of subdivisions.
	 * @param v0         Corner index -X, -Z.
	 * @param v1         Corner index -X, +Z.
	 * @param v2         Corner index +X, +Z.
	 * @param v3         Corner index +X, -Z.
	 */
  static List<Vector3> hilbert2D(Vector3? center,num? size, int? iterations, int? v0, int? v1, int? v2, int? v3) {
    // Default Vars
    center = center != null ? center : Vector3(0, 0, 0);
    size = size != null ? size : 10;

    final half = size / 2;
    iterations = iterations != null ? iterations : 1;
    v0 = v0 != null ? v0 : 0;
    v1 = v1 != null ? v1 : 1;
    v2 = v2 != null ? v2 : 2;
    v3 = v3 != null ? v3 : 3;

    final vec_s = [
      Vector3(center.x - half, center.y, center.z - half),
      Vector3(center.x - half, center.y, center.z + half),
      Vector3(center.x + half, center.y, center.z + half),
      Vector3(center.x + half, center.y, center.z - half)
    ];

    final vec = [vec_s[v0], vec_s[v1], vec_s[v2], vec_s[v3]];

    // Recurse iterations
    if (0 <= --iterations) {
      final List<Vector3> tmp = [];

      tmp.addAll(
          GeometryUtils.hilbert2D(vec[0], half, iterations, v0, v3, v2, v1));

      tmp.addAll(
          GeometryUtils.hilbert2D(vec[1], half, iterations, v0, v1, v2, v3));
      tmp.addAll(
          GeometryUtils.hilbert2D(vec[2], half, iterations, v0, v1, v2, v3));
      tmp.addAll(
          GeometryUtils.hilbert2D(vec[3], half, iterations, v2, v1, v0, v3));

      // Return recursive call
      return tmp;
    }

    // Return complete Hilbert Curve.
    return vec;
  }

  /**
	 * Generates 3D-Coordinates in a very fast way.
	 *
	 * Based on work by:
	 * @link http://www.openprocessing.org/visuals/?visualID=15599
	 *
	 * @param center     Center of Hilbert curve.
	 * @param size       Total width of Hilbert curve.
	 * @param iterations Number of subdivisions.
	 * @param v0         Corner index -X, +Y, -Z.
	 * @param v1         Corner index -X, +Y, +Z.
	 * @param v2         Corner index -X, -Y, +Z.
	 * @param v3         Corner index -X, -Y, -Z.
	 * @param v4         Corner index +X, -Y, -Z.
	 * @param v5         Corner index +X, -Y, +Z.
	 * @param v6         Corner index +X, +Y, +Z.
	 * @param v7         Corner index +X, +Y, -Z.
	 */
  static List<Vector3> hilbert3D(Vector3? center, num? size, int? iterations, int? v0, int? v1, int? v2, int? v3, int? v4, int? v5, int? v6, int? v7) {
    // Default Vars
    center = center != null ? center : Vector3();
    size = size != null ? size : 10;

    double half = size / 2;
    iterations = iterations != null ? iterations : 1;
    v0 = v0 != null ? v0 : 0;
    v1 = v1 != null ? v1 : 1;
    v2 = v2 != null ? v2 : 2;
    v3 = v3 != null ? v3 : 3;
    v4 = v4 != null ? v4 : 4;
    v5 = v5 != null ? v5 : 5;
    v6 = v6 != null ? v6 : 6;
    v7 = v7 != null ? v7 : 7;

    final vec_s = [
      Vector3(center.x - half, center.y + half, center.z - half),
      Vector3(center.x - half, center.y + half, center.z + half),
      Vector3(center.x - half, center.y - half, center.z + half),
      Vector3(center.x - half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y - half, center.z - half),
      Vector3(center.x + half, center.y - half, center.z + half),
      Vector3(center.x + half, center.y + half, center.z + half),
      Vector3(center.x + half, center.y + half, center.z - half)
    ];

    final vec = [
      vec_s[v0],
      vec_s[v1],
      vec_s[v2],
      vec_s[v3],
      vec_s[v4],
      vec_s[v5],
      vec_s[v6],
      vec_s[v7]
    ];

    // Recurse iterations
    if (--iterations >= 0) {
      final List<Vector3> tmp = [];

      tmp.addAll(GeometryUtils.hilbert3D(
          vec[0], half, iterations, v0, v3, v4, v7, v6, v5, v2, v1));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[1], half, iterations, v0, v7, v6, v1, v2, v5, v4, v3));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[2], half, iterations, v0, v7, v6, v1, v2, v5, v4, v3));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[3], half, iterations, v2, v3, v0, v1, v6, v7, v4, v5));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[4], half, iterations, v2, v3, v0, v1, v6, v7, v4, v5));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[5], half, iterations, v4, v3, v2, v5, v6, v1, v0, v7));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[6], half, iterations, v4, v3, v2, v5, v6, v1, v0, v7));
      tmp.addAll(GeometryUtils.hilbert3D(
          vec[7], half, iterations, v6, v5, v2, v1, v0, v3, v4, v7));

      // Return recursive call
      return tmp;
    }

    // Return complete Hilbert Curve.
    return vec;
  }

  /**
	 * Generates a Gosper curve (lying in the XY plane)
	 *
	 * https://gist.github.com/nitaku/6521802
	 *
	 * @param size The size of a single gosper island.
	 */
  static Function gosper(int? size) {
    size = (size != null) ? size : 1;

    Function fractalize = (config){
      String output = '';
      String input = config["axiom"];

      for (int i = 0, il = config["steps"];0 <= il ? i < il : i > il;0 <= il ? i++ : i--) {

        for (int j = 0, jl = input.length; j < jl; j++){
          final char = input[j];

          if (config["rules"].keys.indexOf(char) >= 0){
            output += config["rules"][char];
          } 
          else {
            output += char;
          }
        }

        input = output;
      }

      return output;
    };

    Function toPoints = (Map<String, dynamic> config) {
      num currX = 0, currY = 0;
      num angle = 0;
      List<num> path = [0, 0, 0];
      final fractal = config["fractal"];

      for (int i = 0, l = fractal.length; i < l; i++) {
        final char = fractal[i];

        if (char == '+') {
          angle += config["angle"];
        } else if (char == '-') {
          angle -= config["angle"];
        } else if (char == 'F') {
          currX += config["size"] * Math.cos(angle);
          currY += -config["size"] * Math.sin(angle);
          path.addAll([currX, currY, 0]);
        }
      }

      return path;
    };

    //

    final gosper = fractalize({
      "axiom": 'A',
      "steps": 4,
      "rules": {"A": 'A+BF++BF-FA--FAFA-BF+', "B": '-FA+BFBF++BF+FA--FA-B'}
    });

    final points = toPoints({
      "fractal": gosper,
      "size": size,
      "angle": Math.pi / 3 // 60 degrees
    });

    return points;
  }
}
