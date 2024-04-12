part of renderer_nodes;

class PropertyNode extends Node {
  String? name;

  PropertyNode([this.name, String? nodeType = 'vec4']) : super(nodeType);

  String getHash([NodeBuilder? builder]) {
    return this.name ?? super.getHash(builder);
  }

  String? generate([NodeBuilder? builder, output]) {
    final nodeVary = builder?.getVarFromNode(this, this.getNodeType(builder));
    final name = this.name;

    if (name != null) {
      nodeVary!.name = name;
    }

    return builder?.getPropertyName(nodeVary);
  }
}
