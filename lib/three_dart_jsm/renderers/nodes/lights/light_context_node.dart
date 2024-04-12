part of renderer_nodes;

class LightContextNode extends ContextNode {
  LightContextNode(Node node) : super(node) {}

  String getNodeType([NodeBuilder? builder, output]) {
    return 'vec3';
  }

  String? generate([NodeBuilder? builder, output]) {
    final material = builder?.material;

    Node? lightingModel = null;

    if (material is MeshStandardMaterial) {
      lightingModel = PhysicalLightingModel;
    }

    final directDiffuse = VarNode(Vector3Node(), 'DirectDiffuse', 'vec3');
    final directSpecular =
        VarNode(Vector3Node(), 'DirectSpecular', 'vec3');

    this.context.directDiffuse = directDiffuse;
    this.context.directSpecular = directSpecular;

    if (lightingModel != null) {
      this.context.lightingModel = lightingModel;
    }

    // add code

    final type = this.getNodeType(builder);

    super.generate(builder, type);

    final totalLight = OperatorNode('+', directDiffuse, directSpecular);

    return totalLight.build(builder, type);
  }
}
