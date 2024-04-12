part of renderer_nodes;

class TextureNode extends InputNode {
  late dynamic value;
  late UVNode uv;
  late dynamic bias;

  TextureNode([value = null, UVNode? uv = null, bias = null]) : super('texture') {
    this.value = value;
    this.uv = uv ?? UVNode();
    this.bias = bias;
  }

  String? generate([NodeBuilder? builder, output]) {
    final texture = this.value;

    if (!texture || texture.isTexture != true) {
      throw ('TextureNode: Need a three.js texture.');
    }

    final type = this.getNodeType(builder);

    final textureProperty = super.generate(builder, type);

    if (output == 'sampler2D' || output == 'texture2D') {
      return textureProperty;
    } 
    else if (output == 'sampler') {
      return textureProperty == null?null:textureProperty + '_sampler';
    } 
    else {
      final nodeData = builder?.getDataFromNode(this);

      String? snippet = nodeData.snippet;

      if (snippet == undefined) {
        final uvSnippet = this.uv.build(builder, 'vec2');
        final bias = this.bias;

        String? biasSnippet = null;

        if (bias != null) {
          biasSnippet = bias.build(builder, 'float');
        }

        snippet = builder?.getTexture(textureProperty, uvSnippet, biasSnippet);

        nodeData.snippet = snippet;
      }

      return builder?.format(snippet, 'vec4', output);
    }
  }
}
