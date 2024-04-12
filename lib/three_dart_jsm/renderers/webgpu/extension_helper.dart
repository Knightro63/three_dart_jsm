part of three_webgpu;

extension Matrix4GPU on Matrix4 {
  Matrix4 makePerspective(num left, num right, num top, num bottom, num near, num far) {
    Console.info(
        'THREE.WebGPURenderer: Modified Matrix4.makePerspective() and Matrix4.makeOrtographic() to work with WebGPU, see https://github.com/mrdoob/three.js/issues/20276.');

    final te = this.elements;
    final x = 2 * near / (right - left);
    final y = 2 * near / (top - bottom);

    final a = (right + left) / (right - left);
    final b = (top + bottom) / (top - bottom);
    final c = -far / (far - near);
    final d = -far * near / (far - near);

    te[0] = x;
    te[4] = 0;
    te[8] = a;
    te[12] = 0;
    te[1] = 0;
    te[5] = y;
    te[9] = b;
    te[13] = 0;
    te[2] = 0;
    te[6] = 0;
    te[10] = c;
    te[14] = d;
    te[3] = 0;
    te[7] = 0;
    te[11] = -1;
    te[15] = 0;

    return this;
  }

  Matrix4 makeOrthographic(num left, num right, num top, num bottom, num near, num far) {
    Console.info(
        'THREE.WebGPURenderer: Modified Matrix4.makePerspective() and Matrix4.makeOrtographic() to work with WebGPU, see https://github.com/mrdoob/three.js/issues/20276.');

    final te = this.elements;
    final w = 1.0 / (right - left);
    final h = 1.0 / (top - bottom);
    final p = 1.0 / (far - near);

    final x = (right + left) * w;
    final y = (top + bottom) * h;
    final z = near * p;

    te[0] = 2 * w;
    te[4] = 0;
    te[8] = 0;
    te[12] = -x;
    te[1] = 0;
    te[5] = 2 * h;
    te[9] = 0;
    te[13] = -y;
    te[2] = 0;
    te[6] = 0;
    te[10] = -1 * p;
    te[14] = -z;
    te[3] = 0;
    te[7] = 0;
    te[11] = 0;
    te[15] = 1;

    return this;
  }
}
