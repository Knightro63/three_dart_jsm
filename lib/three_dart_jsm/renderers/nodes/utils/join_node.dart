part of renderer_nodes;

class JoinNode extends Node {
  late List<Node> nodes;

  JoinNode([List<Node>? nodes]) : super() {
    generateLength = 1;
    this.nodes = nodes ?? [];
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    return builder?.getTypeFromLength(this.nodes.length);
  }

  String? generate([NodeBuilder? builder, output]) {
    final type = this.getNodeType(builder)!;
    final nodes = this.nodes;
    final snippetValues = [];

    for (int i = 0; i < nodes.length; i++) {
      final input = nodes[i];
      final inputSnippet = input.build(builder, 'float');

      snippetValues.add(inputSnippet);
    }

    return "${builder?.getType(type)}( ${snippetValues.join(', ')} )";
  }
}
