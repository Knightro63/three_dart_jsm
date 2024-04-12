part of renderer_nodes;

class MeshBasicNodeMaterial extends MeshBasicMaterial {
  bool isNodeMaterial = true;

  Node? colorNode;
  Node? opacityNode;
  Node? alphaTestNode;
  Node? lightNode;
  Node? positionNode;
  Node? emissiveNode;

  MeshBasicNodeMaterial(Map<String, dynamic>? parameters) : super(parameters);

  MeshBasicMaterial copy(Material source) {
    if (source is MeshBasicNodeMaterial) {
      this.colorNode = source.colorNode;
      this.opacityNode = source.opacityNode;
      this.alphaTestNode = source.alphaTestNode;
      this.lightNode = source.lightNode;
      this.positionNode = source.positionNode;
    }
    return super.copy(source);
  }
}
