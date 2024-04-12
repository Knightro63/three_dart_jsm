part of renderer_nodes;

class VaryNode extends Node {
  late Node node;
  late String? name;

  VaryNode(this.node, [this.name]) : super() {
    generateLength = 1;
  }

  String getHash([NodeBuilder? builder]) {
    return this.name ?? super.getHash(builder);
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    // VaryNode is auto type
    return this.node.getNodeType(builder);
  }

  String? generate([NodeBuilder? builder, output]) {
    final type = this.getNodeType(builder);
    final node = this.node;
    final name = this.name;

    final nodeVary = builder?.getVaryFromNode(this, type);

    if (name != null) {
      nodeVary!.name = name;
    }

    final propertyName = builder?.getPropertyName(nodeVary);//, NodeShaderStage.Vertex

    // force node run in vertex stage
    builder?.flowNodeFromShaderStage(NodeShaderStage.Vertex, node, type, propertyName);
    final _result = builder?.getPropertyName(nodeVary);

    return _result;
  }
}
