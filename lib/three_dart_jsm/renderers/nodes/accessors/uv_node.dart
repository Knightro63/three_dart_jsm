part of renderer_nodes;

class UVNode extends AttributeNode {
  late int index;

  UVNode([this.index = 0]) : super(null, 'vec2');

  String getAttributeName(NodeBuilder? builder) {
    var index = this.index;

    return 'uv${(index > 0 ? index + 1 : '')}';
  }
}
