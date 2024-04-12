part of renderer_nodes;

class AttributeNode extends Node {
  late String? _attributeName;

  AttributeNode(String? attributeName, String nodeType) : super(nodeType) {
    generateLength = 1;
    this._attributeName = attributeName;
  }

  @override
  String getHash([NodeBuilder? builder]) {
    return this.getAttributeName(builder) ?? '';
  }

  AttributeNode setAttributeName(attributeName) {
    this._attributeName = attributeName;
    return this;
  }
  
  String? getAttributeName(NodeBuilder? builder) {
    return this._attributeName;
  }

  @override
  String? generate([NodeBuilder? builder, output]) {
    final attribute = builder == null? null:builder.getAttribute(this.getAttributeName(builder)!, this.getNodeType(builder)!);

    if (builder != null && builder.isShaderStage('vertex')) {
      return attribute?.name;
    } 
    else if(builder != null){
      final nodeVary = VaryNode(this);
      return nodeVary.build(builder, attribute?.type);
    }
    return null;
  }
}
