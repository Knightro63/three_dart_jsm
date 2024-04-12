part of renderer_nodes;

class ContextNode extends Node {
  late Node node;
  late dynamic context;

  ContextNode(this.node, [context]) : super() {
    this.context = context ?? {};
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    return this.node.getNodeType(builder);
  }

  String? generate([NodeBuilder? builder, output]) {
    final previousContext = builder?.getContext();

    Map _context = {};
    _context.addAll(builder?.context);
    _context.addAll(this.context);

    builder?.setContext(_context);

    final snippet = this.node.build(builder, output);

    builder?.setContext(previousContext);

    return snippet;
  }
}
