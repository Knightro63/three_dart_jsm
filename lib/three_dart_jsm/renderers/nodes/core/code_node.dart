part of renderer_nodes;

class CodeNode extends Node {
  late String code;
  late bool useKeywords;
  late List<Node> _includes;

  CodeNode([String code = '', String nodeType = 'code']) : super(nodeType) {
    this.code = code;
    this.useKeywords = false;
    this._includes = [];
  }

  CodeNode setIncludes(List<Node> includes) {
    this._includes = includes;
    return this;
  }

  List<Node> getIncludes(NodeBuilder? builder) {
    return this._includes;
  }

  @override
  String? generate([NodeBuilder? builder, output]) {
    if (this.useKeywords == true) {
      final contextKeywords = builder?.context.keywords;

      if (contextKeywords != undefined) {
        final nodeData = builder?.getDataFromNode(this, builder.shaderStage);

        if (nodeData.keywords == undefined) {
          nodeData.keywords = [];
        }

        if (nodeData.keywords.indexOf(contextKeywords) == -1) {
          contextKeywords.include(builder, this.code);

          nodeData.keywords.push(contextKeywords);
        }
      }
    }

    final includes = this.getIncludes(builder);

    for (final include in includes) {
      include.build(builder);
    }

    final nodeCode = builder?.getCodeFromNode(this, this.getNodeType(builder)!);
    nodeCode?.code = this.code;

    return nodeCode?.code;
  }
}
