part of renderer_nodes;

class NodeKeywords {
  late List<String> keywords;
  late Map<String,Node?> nodes;
  late Map keywordsCallback;

  NodeKeywords() {
    this.keywords = [];
    this.nodes = {};
    this.keywordsCallback = {};
  }

  Node? getNode(String name) {
    Node? node = this.nodes[name];

    if (node == null && this.keywordsCallback[name] != null) {
      node = this.keywordsCallback[name](name);
      this.nodes[name] = node;
    }

    return node;
  }

  NodeKeywords addKeyword(name, callback) {
    this.keywords.add(name);
    this.keywordsCallback[name] = callback;

    return this;
  }

  List parse(String code) {
    //final keywordNames = this.keywords;

    final regExp = RegExp(r"\\b${keywordNames.join( '\\b|\\b' )}\\b",caseSensitive: false);

    final codeKeywords = regExp.allMatches(code);//code.match(regExp);

    final List keywordNodes = [];

    //if (codeKeywords != null) {
      for (final keyword in codeKeywords) {
        final node = this.getNode(keyword.toString());

        if (node != undefined && keywordNodes.indexOf(node) == -1) {
          keywordNodes.add(node);
        }
      }
    //}

    return keywordNodes;
  }

  void include(NodeBuilder builder, String code) {
    final keywordNodes = this.parse(code);

    for (final keywordNode in keywordNodes) {
      keywordNode.build(builder);
    }
  }
}
