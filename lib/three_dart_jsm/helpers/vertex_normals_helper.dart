import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

final _v1 = Vector3();
final _v2 = Vector3();
final _normalMatrix = Matrix3();

class VertexNormalsHelper extends LineSegments {
  late Object3D object;
  late int size;

  VertexNormalsHelper.create(BufferGeometry? geometry, Material? material):super(geometry, material) {}

  factory VertexNormalsHelper(Object3D object, [int size = 1, int color = 0xff0000]) {
    final geometry = BufferGeometry();

    final nNormals = object.geometry?.attributes["normal"].count;
    final positions = Float32BufferAttribute(Float32Array(nNormals * 2 * 3), 3, false);

    geometry.setAttribute('position', positions);

    final vnh = VertexNormalsHelper.create(geometry, LineBasicMaterial({"color": color, "toneMapped": false}));

    vnh.object = object;
    vnh.size = size;
    vnh.type = 'VertexNormalsHelper';

    //

    vnh.matrixAutoUpdate = false;

    vnh.update();

    return vnh;
  }

  void update() {
    this.object.updateMatrixWorld(true);

    _normalMatrix.getNormalMatrix(this.object.matrixWorld);

    final matrixWorld = this.object.matrixWorld;

    final position = this.geometry!.attributes["position"];

  
    BufferGeometry? objGeometry = this.object.geometry;

    if (objGeometry != null) {
      final objPos = objGeometry.attributes["position"];
      final objNorm = objGeometry.attributes["normal"];

      int idx = 0;

      // for simplicity, ignore index and drawcalls, and render every normal

      for (int j = 0, jl = objPos.count; j < jl; j++) {
        _v1.fromBufferAttribute(objPos, j)
            .applyMatrix4(matrixWorld);

        _v2.fromBufferAttribute(objNorm, j);

        _v2
            .applyMatrix3(_normalMatrix)
            .normalize()
            .multiplyScalar(this.size)
            .add(_v1);

        position.setXYZ(idx, _v1.x, _v1.y, _v1.z);

        idx = idx + 1;

        position.setXYZ(idx, _v2.x, _v2.y, _v2.z);

        idx = idx + 1;
      }
    }

    position.needsUpdate = true;
  }
}
