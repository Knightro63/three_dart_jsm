part of renderer_nodes;

class MaterialReferenceNode extends ReferenceNode {
  late Material? material;

  MaterialReferenceNode(property, String inputType, [this.material = null]): super(property, inputType, material) {
    generateLength = 1;
  }

  void update([frame]) {
    this.object = this.material != null ? this.material : frame.material;

    super.update(frame);
  }
}
