part of renderer_nodes;

class TempNode extends Node {
  TempNode([type]) : super(type) {}

  String? build([NodeBuilder? builder, output]) {
    final type = builder?.getVectorType(this.getNodeType(builder, output));

    if (builder != null && builder.context["temp"] != false && type != 'void ' && output != 'void') {
      Map nodeData = builder.getDataFromNode(this);

      if (nodeData["snippet"] == undefined) {
        final snippet = super.build(builder, type);

        final nodeVar = builder.getVarFromNode(this, type);
        final propertyName = builder.getPropertyName(nodeVar);

        builder.addFlowCode("${propertyName} = ${snippet}");

        nodeData["snippet"] = snippet;
        nodeData["propertyName"] = propertyName;
      }

      return builder.format(nodeData["propertyName"], type, output);
    }

    return super.build(builder, output);
  }
}
