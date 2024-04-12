part of renderer_nodes;

class VarNode extends Node {
  late Node node;
  String? name;

  VarNode(this.node, [this.name, String? nodeType = null]) : super(nodeType) {
    generateLength = 1;
  }

  String getHash([NodeBuilder? builder]) {
    return this.name ?? super.getHash(builder);
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    return super.getNodeType(builder) ?? this.node.getNodeType(builder);
  }

  String? generate([NodeBuilder? builder, output]) {
    final type = builder?.getVectorType(this.getNodeType(builder));
    final node = this.node;
    final name = this.name;

    final snippet = node.build(builder, type);

    final nodeVar = builder?.getVarFromNode(this, type);

    if (name != null) {
      nodeVar!.name = name;
    }

    final propertyName = builder?.getPropertyName(nodeVar);

    builder?.addFlowCode("${propertyName} = ${snippet}");

    return propertyName;
  }

  getProperty(String name) {
    if(name == "xyz") {
      return this.xyz;
    } else if (name == "w") {
      return w;
    } else {
      return super.getProperty(name);
    }
  }
}
