part of renderer_nodes;

class InputNode extends Node {
  InputNode([String? inputType]):super(inputType) {
    this.inputType = inputType ?? 'input_node';
    this.constant = false;
  }

  InputNode setConst(value) {
    this.constant = value;
    return this;
  }

  bool getConst() {
    return this.constant;
  }

  String getInputType(NodeBuilder? builder) {
    return this.inputType;
  }

  String generateConst(NodeBuilder builder) {
    return builder.getConst(this.getNodeType(builder), this.value);
  }

  @override
  String? generate([NodeBuilder? builder, output]) {
    final type = this.getNodeType(builder);

    if (this.constant == true) {
      return builder?.format(this.generateConst(builder), type, output);
    } 
    else {
      final inputType = this.getInputType(builder);

      final nodeUniform =
          builder?.getUniformFromNode(this, builder.shaderStage, inputType);
      final propertyName = builder?.getPropertyName(nodeUniform);

      return builder?.format(propertyName, type, output);
    }
  }
}
