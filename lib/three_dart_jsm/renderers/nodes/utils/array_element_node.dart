part of renderer_nodes;

class ArrayElementNode extends Node {
  late Node node;
  late Node indexNode;

  ArrayElementNode(this.node, this.indexNode) : super();

  String? getNodeType([NodeBuilder? builder, output]) {
    return this.node.getNodeType(builder);
  }

  String generate([NodeBuilder? builder, output]) {
    var nodeSnippet = this.node.build(builder);
    var indexSnippet = this.indexNode.build(builder, 'int');

    return "${nodeSnippet}[ ${indexSnippet} ]";
  }
}
