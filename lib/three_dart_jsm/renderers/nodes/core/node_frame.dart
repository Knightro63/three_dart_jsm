part of renderer_nodes;

class NodeFrame {
  late num time;
  late num deltaTime;
  late int frameId;
  num? startTime;
  late WeakMap updateMap;
  late dynamic renderer;
  late Material? material;
  late Camera? camera;
  late Object3D? object;
  late num lastTime;

  NodeFrame() {
    this.time = 0;
    this.deltaTime = 0;

    this.frameId = 0;

    this.startTime = null;

    this.updateMap = new WeakMap();

    this.renderer = null;
    this.material = null;
    this.camera = null;
    this.object = null;
  }

  void updateNode(Node node) {
    if (node.updateType == NodeUpdateType.Frame) {
      if (this.updateMap.get(node) != this.frameId) {
        this.updateMap.set(node, this.frameId);
        node.update(this);
      }
    } 
    else if (node.updateType == NodeUpdateType.Object) {
      node.update(this);
    }
  }

  void update() {
    this.frameId++;

    if (this.lastTime == undefined) this.lastTime = Performance.now();
    this.deltaTime = (Performance.now() - this.lastTime) / 1000;
    this.lastTime = Performance.now();
    this.time += this.deltaTime;
  }
}
