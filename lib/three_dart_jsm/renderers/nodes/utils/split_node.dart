part of renderer_nodes;

class SplitNode extends Node {
  late dynamic node;
  late String components;

  SplitNode(node, [components = 'x']) : super() {
    generateLength = 1;

    this.node = node;
    this.components = components;
  }

  int getVectorLength() {
    int vectorLength = this.components.length;

    for (final c in this.components.split('')) {
      vectorLength = Math.max(vector.indexOf(c) + 1, vectorLength);
    }

    return vectorLength;
  }

  String? getNodeType([builder, output]) {
    return builder?.getTypeFromLength(this.components.length);
  }

  String? generate([NodeBuilder? builder, output]) {
    Node node = this.node;
    final nodeTypeLength = builder?.getTypeLength(node.getNodeType(builder)) ?? 0;

    if (nodeTypeLength > 1) {
      String? type = null;

      final componentsLength = this.getVectorLength();

      if (componentsLength >= nodeTypeLength) {
        // need expand the input node
        type = builder?.getTypeFromLength(this.getVectorLength());
      }

      final nodeSnippet = node.build(builder, type);

      return "${nodeSnippet}.${this.components}";
    } 
    else {
      // ignore components if node is a float
      return node.build(builder);
    }
  }
}
