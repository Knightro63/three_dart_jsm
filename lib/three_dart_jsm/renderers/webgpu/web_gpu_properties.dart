part of three_webgpu;

class WebGPUProperties {
  late WeakMap properties;

  WebGPUProperties() {
    this.properties = new WeakMap();
  }

  get(object) {
    var map = this.properties.get(object);

    if (map == undefined) {
      map = {};
      this.properties.set(object, map);
    }

    return map;
  }

  void remove(object) {
    this.properties.delete(object);
  }

  void dispose() {
    this.properties = WeakMap();
  }
}
