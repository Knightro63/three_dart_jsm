part of renderer_nodes;

final LinearToLinear = ShaderNode((inputs) {
  return inputs.value;
});

final LinearTosRGB = ShaderNode((inputs) {
  final value = inputs.value;

  final rgb = value.rgb;

  final a = sub(mul(pow(value.rgb, vec3(0.41666)), 1.055), vec3(0.055));
  final b = mul(rgb, 12.92);
  final factor = vec3(lessThanEqual(rgb, vec3(0.0031308)));

  final rgbResult = mix(a, b, factor);

  return join([rgbResult.r, rgbResult.g, rgbResult.b, value.a]);
});

final EncodingLib = {
  "LinearToLinear": LinearToLinear,
  "LinearTosRGB": LinearTosRGB
};

class ColorSpaceNode extends TempNode {
  static const String LINEAR_TO_LINEAR = 'LinearToLinear';
  static const String LINEAR_TO_SRGB = 'LinearTosRGB';

  late dynamic method;
  late dynamic node;

  ColorSpaceNode(method, node) : super('vec4') {
    this.method = method;

    this.node = node;
  }

  ColorSpaceNode fromEncoding(int encoding) {
    String? method = null;

    if (encoding == LinearEncoding) {
      method = 'Linear';
    } else if (encoding == sRGBEncoding) {
      method = 'sRGB';
    }

    this.method = 'LinearTo' + (method??'');

    return this;
  }

  String? generate([NodeBuilder? builder, output]) {
    final type = this.getNodeType(builder);

    final method = this.method;
    final node = this.node;

    if (method != ColorSpaceNode.LINEAR_TO_LINEAR) {
      final encodingFunctionNode = EncodingLib[method];

      return encodingFunctionNode({value: node}).build(builder, type);
    } else {
      return node.build(builder, type);
    }
  }
}
