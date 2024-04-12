part of renderer_nodes;

class CondNode extends Node {
  late Node node;
  late Node ifNode;
  late Node elseNode;

  CondNode(this.node, [Node? ifNode, Node? elseNode]) : super() {
    this.node = node;

    this.ifNode = ifNode ?? Node();
    this.elseNode = elseNode ?? Node();
  }

  getNodeType([NodeBuilder? builder, output]) {
    final ifType = this.ifNode.getNodeType(builder);
    final elseType = this.elseNode.getNodeType(builder);

    if (builder != null && builder.getTypeLength(elseType) > builder.getTypeLength(ifType)) {
      return elseType;
    }

    return ifType;
  }

  String? generate([NodeBuilder? builder, output]) {
    final type = this.getNodeType(builder);

    final context = {"temp": false};
    final nodeProperty = PropertyNode(null, type).build(builder);

    final nodeSnippet =
            ContextNode(this.node /*, context*/).build(builder, 'bool'),
        ifSnippet = ContextNode(this.ifNode, context).build(builder, type),
        elseSnippet =
            ContextNode(this.elseNode, context).build(builder, type);

    builder?.addFlowCode("""if ( ${nodeSnippet} ) {

\t\t${nodeProperty} = ${ifSnippet};

\t} else {

\t\t${nodeProperty} = ${elseSnippet};

\t}""");

    return nodeProperty;
  }
}
