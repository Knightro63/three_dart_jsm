part of renderer_nodes;

class NodeFunction {
  late String type;
  late dynamic inputs;
  late String name;
  late String presicion;

  NodeFunction(this.type, this.inputs, [this.name = '', this.presicion = '']);

  void getCode(/*name = this.name*/) {
    Console.warn('Abstract function.');
  }
}
