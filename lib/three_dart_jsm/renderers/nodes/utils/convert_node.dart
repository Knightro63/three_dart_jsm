part of renderer_nodes;

class ConvertNode extends Node {
  late Node node;
  late String convertTo;

  ConvertNode(this.node, this.convertTo) : super();

  String? getNodeType([NodeBuilder? builder, output]) {
    return this.convertTo;
  }

  String? generate([NodeBuilder? builder, output]) {
    final convertTo = this.convertTo;
    final convertToSnippet = builder?.getType(convertTo);
    final nodeSnippet = this.node.build(builder, convertTo);

    return "${convertToSnippet}( ${nodeSnippet} )";
  }
}
