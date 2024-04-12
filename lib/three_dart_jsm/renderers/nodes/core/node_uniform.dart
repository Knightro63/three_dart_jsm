part of renderer_nodes;

class NodeUniform {
  late String name;
  late String type;
  late Node node;
  late bool needsUpdate;

  NodeUniform(this.name, this.type, this.node, [this.needsUpdate = false]);

  get value {
    return this.node.value;
  }

  set value(val) {
    this.node.value = val;
  }
}
