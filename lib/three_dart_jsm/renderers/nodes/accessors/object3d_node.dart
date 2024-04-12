part of renderer_nodes;

class Object3DNode extends Node {
  static const String VIEW_MATRIX = 'viewMatrix';
  static const String NORMAL_MATRIX = 'normalMatrix';
  static const String WORLD_MATRIX = 'worldMatrix';
  static const String POSITION = 'position';
  static const String VIEW_POSITION = 'viewPosition';

  late String scope;
  late Object3D? object3d;
  late Node? _inputNode;

  Object3DNode([this.scope = Object3DNode.VIEW_MATRIX, this.object3d = null]) : super() {
    this.updateType = NodeUpdateType.Object;
    this._inputNode = null;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    final scope = this.scope;

    if (scope == Object3DNode.WORLD_MATRIX ||
        scope == Object3DNode.VIEW_MATRIX) {
      return 'mat4';
    } else if (scope == Object3DNode.NORMAL_MATRIX) {
      return 'mat3';
    } else if (scope == Object3DNode.POSITION ||
        scope == Object3DNode.VIEW_POSITION) {
      return 'vec3';
    }
    return null;
  }

  void update([frame]) {
    final Object3D object = this.object3d != null ? this.object3d : frame.object;
    final Node? inputNode = this._inputNode;
    final camera = frame.camera;
    final scope = this.scope;

    if (scope == Object3DNode.VIEW_MATRIX) {
      inputNode?.value = object.modelViewMatrix;
    } else if (scope == Object3DNode.NORMAL_MATRIX) {
      inputNode?.value = object.normalMatrix;
    } else if (scope == Object3DNode.WORLD_MATRIX) {
      inputNode?.value = object.matrixWorld;
    } else if (scope == Object3DNode.POSITION) {
      inputNode?.value.setFromMatrixPosition(object.matrixWorld);
    } else if (scope == Object3DNode.VIEW_POSITION) {
      inputNode?.value.setFromMatrixPosition(object.matrixWorld);

      inputNode?.value.applyMatrix4(camera.matrixWorldInverse);
    }
  }

  String? generate([NodeBuilder? builder, output]) {
    final scope = this.scope;

    if (scope == Object3DNode.WORLD_MATRIX ||
        scope == Object3DNode.VIEW_MATRIX) {
      this._inputNode = new Matrix4Node();
    } else if (scope == Object3DNode.NORMAL_MATRIX) {
      this._inputNode = new Matrix3Node();
    } else if (scope == Object3DNode.POSITION ||
        scope == Object3DNode.VIEW_POSITION) {
      this._inputNode = new Vector3Node();
    }

    return this._inputNode?.build(builder);
  }
}
