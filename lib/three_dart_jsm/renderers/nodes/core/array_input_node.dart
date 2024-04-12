part of renderer_nodes;

class ArrayInputNode extends InputNode {
  late List<Node> nodes;

  ArrayInputNode([List<Node>? nodes]) : super() {
    this.nodes = nodes ?? [];
  }

  @override
  String? getNodeType([NodeBuilder? builder, output]) {
    return this.nodes[0].getNodeType(builder);
  }
}
