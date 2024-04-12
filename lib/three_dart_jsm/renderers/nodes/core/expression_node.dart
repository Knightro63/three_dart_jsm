part of renderer_nodes;

class ExpressionNode extends TempNode {
  late String snipped;
  String? name;

  ExpressionNode([snipped = '', String nodeType = 'void']) : super(nodeType) {
    generateLength = 1;
    this.snipped = snipped;
  }
  
  @override
  String? generate([NodeBuilder? builder, output]) {
    var type = this.getNodeType(builder);
    var snipped = this.snipped;

    if (type == 'void') {
      builder?.addFlowCode(snipped);
    } else {
      return "( ${snipped} )";
    }
    return null;
  }
}
