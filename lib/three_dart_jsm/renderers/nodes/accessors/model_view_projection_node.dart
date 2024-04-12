part of renderer_nodes;

class ModelViewProjectionNode extends Node {
  late PositionNode position;

  ModelViewProjectionNode([PositionNode? position]) : super('vec4') {
    generateLength = 1;
    this.position = position ?? PositionNode();
  }

  String? generate([NodeBuilder? builder, output]) {
    final position = this.position;

    final mvpMatrix = OperatorNode(
        '*',
        CameraNode(CameraNode.PROJECTION_MATRIX),
        ModelNode(ModelNode.VIEW_MATRIX));
    final mvpNode = OperatorNode('*', mvpMatrix, position);

    final _result = mvpNode.build(builder);

    return _result;
  }
}
