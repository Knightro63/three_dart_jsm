part of renderer_nodes;

class BypassNode extends Node {
  late Node outputNode;
  late Node callNode;

  BypassNode(returnNode, callNode) : super() {
    this.outputNode = returnNode;
    this.callNode = callNode;
  }

  @override
  String? getNodeType([NodeBuilder? builder, output]) {
    return this.outputNode.getNodeType(builder);
  }

  @override
  String? generate([NodeBuilder? builder, output]) {
    var snippet = this.callNode.build(builder, 'void');

    if (snippet != '') {
      builder?.addFlowCode(snippet);
    }

    return this.outputNode.build(builder, output);
  }
}
