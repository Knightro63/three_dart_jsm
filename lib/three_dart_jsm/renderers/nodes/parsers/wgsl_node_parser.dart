part of renderer_nodes;

class WGSLNodeParser extends NodeParser {
  WGSLNodeFunction parseFunction(source) {
    return WGSLNodeFunction(source);
  }
}
