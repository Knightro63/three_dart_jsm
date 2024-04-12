part of renderer_nodes;

class CameraNode extends Object3DNode {
  static const String PROJECTION_MATRIX = 'projectionMatrix';
  static const String VIEW_MATRIX = 'viewMatrix';
  static const String NORMAL_MATRIX = 'normalMatrix';
  static const String WORLD_MATRIX = 'worldMatrix';
  static const String POSITION = 'position';
  static const String VIEW_POSITION = 'viewPosition';

  Node? _inputNode;

  CameraNode([String scope = CameraNode.POSITION]) : super(scope) {
    generateLength = 1;
    this._inputNode = null;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    final scope = this.scope;

    if (scope == CameraNode.PROJECTION_MATRIX) {
      return 'mat4';
    }

    return super.getNodeType(builder);
  }

  void update([frame]) {
    final Camera? camera = frame.camera;
    final Node? inputNode = this._inputNode;
    final scope = this.scope;

    if (scope == CameraNode.PROJECTION_MATRIX) {
      inputNode?.value = camera?.projectionMatrix;
    } 
    else if (scope == CameraNode.VIEW_MATRIX) {
      inputNode?.value = camera?.matrixWorldInverse;
    } 
    else {
      super.update(frame);
    }
  }

  String? generate([NodeBuilder? builder, output]) {
    final scope = this.scope;

    if (scope == CameraNode.PROJECTION_MATRIX) {
      this._inputNode = Matrix4Node();
    }

    return super.generate(builder);
  }
}
