part of renderer_nodes;

class MaterialNode extends Node {
  static const String ALPHA_TEST = 'alphaTest';
  static const String COLOR = 'color';
  static const String OPACITY = 'opacity';
  static const String SPECULAR = 'specular';
  static const String ROUGHNESS = 'roughness';
  static const String METALNESS = 'metalness';

  late String scope;

  MaterialNode([scope = MaterialNode.COLOR]) : super() {
    generateLength = 2;
    this.scope = scope;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    final scope = this.scope;
    final material = builder?.context["material"];

    if (scope == MaterialNode.COLOR) {
      return material.map != null ? 'vec4' : 'vec3';
    } else if (scope == MaterialNode.OPACITY) {
      return 'float';
    } else if (scope == MaterialNode.SPECULAR) {
      return 'vec3';
    } else if (scope == MaterialNode.ROUGHNESS ||
        scope == MaterialNode.METALNESS) {
      return 'float';
    }

    return null;
  }

  String? generate([NodeBuilder? builder, output]) {
    final material = builder?.context["material"];
    final scope = this.scope;

    Node? node = null;

    print(" ============ this ${this} generate scope: ${scope}  ");

    if (scope == MaterialNode.ALPHA_TEST) {
      node = MaterialReferenceNode('alphaTest', 'float');
    } else if (scope == MaterialNode.COLOR) {
      final colorNode = MaterialReferenceNode('color', 'color');

      if (material.map != null &&
          material.map != undefined &&
          material.map.isTexture == true) {
        node = OperatorNode(
            '*', colorNode, MaterialReferenceNode('map', 'texture'));
      } else {
        node = colorNode;
      }
    } else if (scope == MaterialNode.OPACITY) {
      final opacityNode = MaterialReferenceNode('opacity', 'float');

      if (material.alphaMap != null &&
          material.alphaMap != undefined &&
          material.alphaMap.isTexture == true) {
        node = OperatorNode(
            '*', opacityNode, MaterialReferenceNode('alphaMap', 'texture'));
      } else {
        node = opacityNode;
      }
    } else if (scope == MaterialNode.SPECULAR) {
      final specularColorNode =
          MaterialReferenceNode('specularColor', 'color');

      if (material.specularColorMap != null &&
          material.specularColorMap != undefined &&
          material.specularColorMap.isTexture == true) {
        node = OperatorNode('*', specularColorNode,
            MaterialReferenceNode('specularColorMap', 'texture'));
      } else {
        node = specularColorNode;
      }
    } else {
      final outputType = this.getNodeType(builder)!;

      node = MaterialReferenceNode(scope, outputType);
    }

    return node.build(builder, output);
  }
}
