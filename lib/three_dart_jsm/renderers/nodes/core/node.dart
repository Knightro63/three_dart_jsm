part of renderer_nodes;

class Node {
  late String uuid;
  String? nodeType;
  late NodeUpdateType updateType;
  late String inputType;

  dynamic xyz;
  dynamic w;

  late bool constant;
  late int generateLength;

  dynamic value;

  Node([String? nodeType = null]) {
    this.nodeType = nodeType;

    this.updateType = NodeUpdateType.None;

    this.uuid = MathUtils.generateUUID();
  }

  String get type {
    return this.runtimeType.toString();
  }

  String getHash([NodeBuilder? builder]) {
    return this.uuid;
  }

  NodeUpdateType getUpdateType([NodeBuilder? builder]) {
    return this.updateType;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    return this.nodeType;
  }

  void update([frame]) {
    Console.warn('Abstract function.');
  }

  String? generate([NodeBuilder? builder, output]) {
    throw('Abstract function.');
  }

  String? build([NodeBuilder? builder, output = null]) {
    final hash = this.getHash(builder);
    final sharedNode = builder?.getNodeFromHash(hash);

    if (sharedNode != undefined && this != sharedNode) {
      return sharedNode?.build(builder, output);
    }

    builder?.addNode(this);
    builder?.addStack(this);

    final isGenerateOnce = (this.generateLength == 1);

    String? snippet;

    if (isGenerateOnce) {
      final type = this.getNodeType(builder);
      final nodeData = builder?.getDataFromNode(this);

      snippet = nodeData["snippet"];

      if (snippet == undefined) {
        snippet = this.generate(builder) ?? '';

        nodeData["snippet"] = snippet;
      }

      snippet = builder?.format(snippet, type, output);
    } else {
      snippet = this.generate(builder, output) ?? '';
    }

    builder?.removeStack(this);

    return snippet;
  }

  getProperty(String name) {
    if(name == "xyz") {
      return xyz;
    } else {
      throw("Node ${this} getProperty name: ${name} is not support  ");
    }
  }
}
