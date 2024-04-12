part of renderer_nodes;

class NodeCode {
  late String name;
  late String type;
  late String code;

  NodeCode(String name, String type, [String code = '']) {
    this.name = name;
    this.type = type;
    this.code = code;
  }
}
