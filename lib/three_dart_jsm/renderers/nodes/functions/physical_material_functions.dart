part of renderer_nodes;

final getGeometryRoughness = ShaderNode(() {
  final dxy = max(abs(dFdx(normalGeometry)), abs(dFdy(normalGeometry)));
  final geometryRoughness = max(max(dxy.x, dxy.y), dxy.z);

  return geometryRoughness;
});

final getRoughness = ShaderNode((inputs) {
  final roughness = inputs.roughness;

  final geometryRoughness = getGeometryRoughness();

  var roughnessFactor = max(roughness,
      0.0525); // 0.0525 corresponds to the base mip of a 256 cubemap.
  roughnessFactor = add(roughnessFactor, geometryRoughness);
  roughnessFactor = min(roughnessFactor, 1.0);

  return roughnessFactor;
});
