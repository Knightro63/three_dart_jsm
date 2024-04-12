part of renderer_nodes;

final Skinning = ShaderNode((inputs, builder) {
  final position = inputs.position;
  final normal = inputs.normal;
  final index = inputs.index;
  final weight = inputs.weight;
  final bindMatrix = inputs.bindMatrix;
  final bindMatrixInverse = inputs.bindMatrixInverse;
  final boneMatrices = inputs.boneMatrices;

  final boneMatX = element(boneMatrices, index.x);
  final boneMatY = element(boneMatrices, index.y);
  final boneMatZ = element(boneMatrices, index.z);
  final boneMatW = element(boneMatrices, index.w);

  // POSITION

  final skinVertex = mul(bindMatrix, position);

  final skinned = add(
      mul(mul(boneMatX, skinVertex), weight.x),
      mul(mul(boneMatY, skinVertex), weight.y),
      mul(mul(boneMatZ, skinVertex), weight.z),
      mul(mul(boneMatW, skinVertex), weight.w));

  final skinPosition = mul(bindMatrixInverse, skinned).xyz;

  // NORMAL

  var skinMatrix = add(mul(weight.x, boneMatX), mul(weight.y, boneMatY),
      mul(weight.z, boneMatZ), mul(weight.w, boneMatW));

  skinMatrix = mul(mul(bindMatrixInverse, skinMatrix), bindMatrix);

  final skinNormal = transformDirection(skinMatrix, normal).xyz;

  // ASSIGNS

  assign(position, skinPosition).build(builder);
  assign(normal, skinNormal).build(builder);
});

class SkinningNode extends Node {
  late dynamic skinnedMesh;
  late dynamic skinIndexNode;
  late dynamic skinWeightNode;
  late dynamic bindMatrixNode;
  late dynamic bindMatrixInverseNode;
  late dynamic boneMatricesNode;

  SkinningNode(skinnedMesh) : super('void') {
    this.skinnedMesh = skinnedMesh;

    this.updateType = NodeUpdateType.Object;

    //

    this.skinIndexNode = new AttributeNode('skinIndex', 'uvec4');
    this.skinWeightNode = new AttributeNode('skinWeight', 'vec4');

    this.bindMatrixNode = new Matrix4Node(skinnedMesh.bindMatrix);
    this.bindMatrixInverseNode = new Matrix4Node(skinnedMesh.bindMatrixInverse);
    this.boneMatricesNode = new BufferNode(skinnedMesh.skeleton.boneMatrices,
        'mat4', skinnedMesh.skeleton.bones.length);
  }

  String? generate([NodeBuilder? builder, output]) {
    // inout nodes
    final position = new PositionNode(PositionNode.LOCAL);
    final normal = new NormalNode(NormalNode.LOCAL);

    final index = this.skinIndexNode;
    final weight = this.skinWeightNode;
    final bindMatrix = this.bindMatrixNode;
    final bindMatrixInverse = this.bindMatrixInverseNode;
    final boneMatrices = this.boneMatricesNode;

    Skinning({
      position,
      normal,
      index,
      weight,
      bindMatrix,
      bindMatrixInverse,
      boneMatrices
    }, builder);

    return null;
  }

  void update([frame]) {
    this.skinnedMesh.skeleton.update();
  }
}
