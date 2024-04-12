part of renderer_nodes;

class BufferNode extends InputNode {
  late String bufferType;
  late int bufferCount;

  BufferNode(value, this.bufferType, [this.bufferCount = 0]) : super('buffer') {
    this.value = value;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    return this.bufferType;
  }
}
