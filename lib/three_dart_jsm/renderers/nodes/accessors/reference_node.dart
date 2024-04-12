part of renderer_nodes;

class ReferenceNode extends Node {
  late dynamic property;
  late dynamic object;
  late Node? node;

  ReferenceNode(property, String inputType, [object = null]) : super() {
    this.property = property;
    this.inputType = inputType;

    this.object = object;

    this.node = null;

    this.updateType = NodeUpdateType.Object;

    this.setNodeType(inputType);
  }

  void setNodeType(String inputType) {
    Node? node = null;
    String nodeType = inputType;

    if (nodeType == 'float') {
      node = new FloatNode();
    } else if (nodeType == 'vec2') {
      node = new Vector2Node(null);
    } else if (nodeType == 'vec3') {
      node = new Vector3Node(null);
    } else if (nodeType == 'vec4') {
      node = new Vector4Node(null);
    } else if (nodeType == 'color') {
      node = new ColorNode(null);
      nodeType = 'vec3';
    } else if (nodeType == 'texture') {
      node = new TextureNode();
      nodeType = 'vec4';
    }

    this.node = node;
    this.nodeType = nodeType;
    this.inputType = inputType;
  }

  String getNodeType([NodeBuilder? builder, output]) {
    return this.inputType;
  }

  void update([frame]) {
    final object = this.object != null ? this.object : frame.object;
    final value = object.getProperty(this.property);

    this.node?.value = value;
  }

  String? generate([NodeBuilder? builder, output]) {
    return this.node?.build(builder, this.getNodeType(builder));
  }
}
