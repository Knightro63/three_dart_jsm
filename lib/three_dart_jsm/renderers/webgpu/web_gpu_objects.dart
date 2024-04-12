part of three_webgpu;

class WebGPUObjects {
  late WebGPUGeometries geometries;
  late WebGPUInfo info;
  late WeakMap updateMap;

  WebGPUObjects(geometries, info) {
    this.geometries = geometries;
    this.info = info;

    this.updateMap = new WeakMap();
  }

  void update(Object3D object) {
    final geometry = object.geometry;
    final updateMap = this.updateMap;
    final frame = this.info.render["frame"];

    if (geometry is! BufferGeometry) {
      throw ('THREE.WebGPURenderer: This renderer only supports THREE.BufferGeometry for geometries.');
    }

    if (updateMap.get(geometry) != frame) {
      this.geometries.update(geometry);

      updateMap.set(geometry, frame);
    }
  }

  void dispose() {
    this.updateMap = WeakMap();
  }
}
