part of renderer_nodes;

final shaderStages = ['fragment', 'vertex'];
final vector = ['x', 'y', 'z', 'w'];

class NodeBuilder {
  late Object3D object;
  late Material material;
  late dynamic renderer;
  late WGSLNodeParser parser;

  late List<Node> nodes;
  late List<Node> updateNodes;
  late Map<String, Node> hashNodes;

  late String vertexShader;
  late String fragmentShader;
  late Map<String,dynamic> flowNodes;
  late Map<String,dynamic> flowCode;
  late Map<String,dynamic> uniforms;
  late Map<String,dynamic> codes;
  late List<NodeAttribute> attributes;
  late List<NodeVary> varys;

  late Map<String,dynamic> vars;
  late Map<String,dynamic> flow;
  late List<Node> stack;

  late WeakMap nodesData;
  late WeakMap flowsData;

  late dynamic context;

  late String? shaderStage;
  late Node? node;

  NodeBuilder(Object3D object, renderer, WGSLNodeParser? parser) {
    this.object = object;
    this.material = object.material;
    this.renderer = renderer;
    this.parser = parser ?? WGSLNodeParser();

    this.nodes = [];
    this.updateNodes = [];
    this.hashNodes = {};

    // this.vertexShader = null;
    // this.fragmentShader = null;

    this.flowNodes = {"vertex": [], "fragment": []};
    this.flowCode = {"vertex": '', "fragment": ''};
    this.uniforms = {"vertex": [], "fragment": [], "index": 0};
    this.codes = {"vertex": [], "fragment": []};
    this.attributes = [];
    this.varys = [];
    this.vars = {"vertex": [], "fragment": []};
    this.flow = {"code": ''};
    this.stack = [];

    this.context = {
      "keywords": NodeKeywords(),
      "material": object.material
    };

    this.nodesData = WeakMap();
    this.flowsData = WeakMap();

    this.shaderStage = null;
    this.node = null;
  }

  void addStack(Node node) {
    this.stack.add(node);
  }

  void removeStack(Node node) {
    final lastStack = this.stack.removeLast();

    if (lastStack != node) {
      throw ('NodeBuilder: Invalid node stack!');
    }
  }

  void addNode(Node node) {
    if (this.nodes.indexOf(node) == -1) {
      final updateType = node.getUpdateType(this);

      if (updateType != NodeUpdateType.None) {
        this.updateNodes.add(node);
      }

      this.nodes.add(node);

      final _hash = node.getHash(this);

      this.hashNodes[_hash] = node;
    }
  }

  getMethod(method) {
    return method;
  }

  Node? getNodeFromHash(String hash) {
    return this.hashNodes[hash];
  }

  Node addFlow(String shaderStage, Node node) {
    this.flowNodes[shaderStage].add(node);

    return node;
  }

  void setContext(context) {
    this.context = context;
  }

  getContext() {
    return this.context;
  }

  String? getTexture(textureProperty, uvSnippet, [biasSnippet = null, shaderStage = null]) {
    Console.warn('Abstract function.');
    return null;
  }

  void getCubeTexture(/* textureProperty, uvSnippet, biasSnippet = null */) {
    Console.warn('Abstract function.');
  }

  // rename to generate
  String getConst(String? type, value) {
    if (type == 'float') return value + (value % 1 ? '' : '.0');
    if (type == 'vec2')
      return "${this.getType('vec2')}( ${value.x}, ${value.y} )";
    if (type == 'vec3')
      return "${this.getType('vec3')}( ${value.x}, ${value.y}, ${value.z} )";
    if (type == 'vec4')
      return "${this.getType('vec4')}( ${value.x}, ${value.y}, ${value.z}, ${value.w} )";
    if (type == 'color')
      return "${this.getType('vec3')}( ${value.r}, ${value.g}, ${value.b} )";

    throw ("NodeBuilder: Type '${type}' not found in generate constant attempt.");
  }

  String getType(String type) {
    return type;
  }

  generateMethod(method) {
    return method;
  }

  NodeAttribute getAttribute(String name, String type) {
    final attributes = this.attributes;

    // find attribute

    for (final attribute in attributes) {
      if (attribute.name == name) {
        return attribute;
      }
    }

    // create a if no exist

    final attribute = NodeAttribute(name, type);

    attributes.add(attribute);

    return attribute;
  }

  String getPropertyName(node /*, shaderStage*/) {
    return node.name;
  }

  bool isVector(String? type) {
    if(type == null) false;
    return RegExp(r"vec\d").hasMatch(type!);
  }

  bool isMatrix(String? type) {
    if(type == null) false;
    return RegExp(r"mat\d").hasMatch(type!);
  }

  bool isShaderStage(String? shaderStage) {
    return this.shaderStage == shaderStage;
  }

  getTextureEncodingFromMap(map) {
    final encoding;

    if (map && map.isTexture) {
      encoding = map.encoding;
    } 
    else if (map && map.isWebGLRenderTarget) {
      encoding = map.texture.encoding;
    } 
    else {
      encoding = LinearEncoding;
    }

    return encoding;
  }

  String? getVectorType(String? type) {
    if (type == 'color') return 'vec3';
    if (type == 'texture') return 'vec4';

    return type;
  }

  String? getTypeFromLength(int type) {
    if (type == 1) return 'float';
    if (type == 2) return 'vec2';
    if (type == 3) return 'vec3';
    if (type == 4) return 'vec4';

    return null;
  }

  num getTypeLength(String? type) {
    final vecType = this.getVectorType(type);
    final vecNum = vecType == null?null:RegExp(r"vec([2-4])").firstMatch(vecType);

    if (vecNum != null) return num.parse(vecNum.group(1)!);
    if (vecType == 'float' || vecType == 'bool') return 1;

    return 0;
  }

  String? getVectorFromMatrix(String? type) {
    if(type == null){
      return null;
    }
    return 'vec${type.substring(3)}';
  }

  getDataFromNode(Node node, [shaderStage]) {
    shaderStage ??= this.shaderStage;

    dynamic nodeData = this.nodesData.get(node);

    if (nodeData == null) {
      nodeData = {"vertex": {}, "fragment": {}};

      this.nodesData.set(node, nodeData);
    }

    return shaderStage != null ? nodeData[shaderStage] : nodeData;
  }

  NodeUniform? getUniformFromNode(Node node, shaderStage, String type) {
    Map nodeData = this.getDataFromNode(node, shaderStage);

    NodeUniform? nodeUniform = nodeData["uniform"];

    if (nodeUniform == null) {
      final index = this.uniforms["index"]++;

      nodeUniform = NodeUniform('nodeUniform${index}', type, node);

      this.uniforms[shaderStage].add(nodeUniform);

      nodeData["uniform"] = nodeUniform;
    }

    return nodeUniform;
  }

  NodeVar getVarFromNode(node, type, [shaderStage]) {
    shaderStage ??= this.shaderStage;

    Map nodeData = this.getDataFromNode(node, shaderStage);

    NodeVar? nodeVar = nodeData["variable"];

    if (nodeVar == null) {
      final vars = this.vars[shaderStage];
      final index = vars.length;

      nodeVar = NodeVar('nodeVar${index}', type);

      vars.add(nodeVar);

      nodeData["variable"] = nodeVar;
    }

    return nodeVar;
  }

  NodeVary getVaryFromNode(Node node, String? type) {
    Map nodeData = this.getDataFromNode(node, null);

    NodeVary? nodeVary = nodeData["vary"];

    if (nodeVary == null) {
      final varys = this.varys;
      final index = varys.length;

      nodeVary = NodeVary('nodeVary${index}', type);

      varys.add(nodeVary);

      nodeData["vary"] = nodeVary;
    }

    return nodeVary;
  }

  NodeCode? getCodeFromNode(Node node, String type, [String? shaderStage]) {
    shaderStage = shaderStage ?? this.shaderStage;

    final nodeData = this.getDataFromNode(node);

    NodeCode? nodeCode = nodeData.code;

    if (nodeCode == null) {
      final codes = this.codes[shaderStage];
      final index = codes.length;

      nodeCode = NodeCode('nodeCode' + index, type);

      codes.add(nodeCode);

      nodeData.code = nodeCode;
    }

    return nodeCode;
  }

  addFlowCode(code) {
    this.flow["code"] += code;
  }

  getFlowData(shaderStage, node) {
    return this.flowsData.get(node);
  }

  flowNode(node, shaderStage) {
    this.node = node;

    final output = node.getNodeType(this);

    final flowData = this.flowChildNode(node, output);

    this.flowsData.set(node, flowData);

    this.node = null;

    return flowData;
  }

  flowChildNode(node, [output]) {
    final previousFlow = this.flow;

    final flow = {
      "code": '',
    };

    this.flow = flow;

    flow["result"] = node.build(this, output);

    // print("NodeBuilder.flowChildNode node: ${node} output: ${output} result ${flow["result"]}  ");

    this.flow = previousFlow;

    return flow;
  }

  flowNodeFromShaderStage(shaderStage, node,
      [output, propertyName]) {
    final previousShaderStage = this.shaderStage;

    this.setShaderStage(shaderStage);

    Map flowData = this.flowChildNode(node, output);

    if (propertyName != null) {
      flowData["code"] += "${propertyName} = ${flowData["result"]};\n\t";
    }

    this.flowCode[shaderStage] = this.flowCode[shaderStage] + flowData["code"];

    this.setShaderStage(previousShaderStage);

    return flowData;
  }

  String getAttributes(String shaderStage) {
    String snippet = '';

    if (shaderStage == 'vertex') {
      final attributes = this.attributes;

      for (int index = 0; index < attributes.length; index++) {
        final attribute = attributes[index];

        snippet += "layout(location = ${index}) in ${attribute.type} ${attribute.name}; ";
      }
    }

    return snippet;
  }

  void getVarys(String shaderStage) {
    Console.warn('Abstract function.');
  }

  String getVars(String shaderStage) {
    String snippet = '';

    final vars = this.vars[shaderStage];

    for (int index = 0; index < vars.length; index++) {
      final variable = vars[index];

      snippet += "${variable.type} ${variable.name}; ";
    }

    return snippet;
  }

  void getUniforms(String shaderStage) {
    Console.warn('Abstract function.');
  }

  String getCodes(String shaderStage) {
    final codes = this.codes[shaderStage];

    String code = '';

    for (final nodeCode in codes) {
      code += nodeCode.code + '\n';
    }

    return code;
  }

  String getHash() {
    return this.vertexShader + this.fragmentShader;
  }

  String? getShaderStage() {
    return this.shaderStage;
  }

  void setShaderStage(String? shaderStage) {
    this.shaderStage = shaderStage;
  }

  void buildCode() {
    Console.warn('Abstract function.');
  }

  NodeBuilder build() {
    if (this.context["vertex"] != null && this.context["vertex"] is Node) {
      this.flowNodeFromShaderStage('vertex', this.context["vertex"]);
    }

    for (final shaderStage in shaderStages) {
      this.setShaderStage(shaderStage);

      final flowNodes = this.flowNodes[shaderStage];

      for (final node in flowNodes) {
        this.flowNode(node, shaderStage);
      }
    }

    this.setShaderStage(null);

    this.buildCode();

    return this;
  }

  String? format(String? snippet, String? fromType, String? toType) {
    fromType = this.getVectorType(fromType);
    toType = this.getVectorType(toType);

    final typeToType = "${fromType} to ${toType}";

    switch (typeToType) {
      case 'int to float':
        return "${this.getType('float')}( ${snippet} )";
      case 'int to vec2':
        return "${this.getType('vec2')}( ${this.getType('float')}( ${snippet} ) )";
      case 'int to vec3':
        return "${this.getType('vec3')}( ${this.getType('float')}( ${snippet} ) )";
      case 'int to vec4':
        return "${this.getType('vec4')}( ${this.getType('vec3')}( ${this.getType('float')}( ${snippet} ) ), 1.0 )";

      case 'float to int':
        return "${this.getType('int')}( ${snippet} )";
      case 'float to vec2':
        return "${this.getType('vec2')}( ${snippet} )";
      case 'float to vec3':
        return "${this.getType('vec3')}( ${snippet} )";
      case 'float to vec4':
        return "${this.getType('vec4')}( ${this.getType('vec3')}( ${snippet} ), 1.0 )";

      case 'vec2 to int':
        return "${this.getType('int')}( ${snippet}.x )";
      case 'vec2 to float':
        return "${snippet}.x";
      case 'vec2 to vec3':
        return "${this.getType('vec3')}( ${snippet}, 0.0 )";
      case 'vec2 to vec4':
        return "${this.getType('vec4')}( ${snippet}.xy, 0.0, 1.0 )";

      case 'vec3 to int':
        return "${this.getType('int')}( ${snippet}.x )";
      case 'vec3 to float':
        return "${snippet}.x";
      case 'vec3 to vec2':
        return "${snippet}.xy";
      case 'vec3 to vec4':
        return "${this.getType('vec4')}( ${snippet}, 1.0 )";

      case 'vec4 to int':
        return "${this.getType('int')}( ${snippet}.x )";
      case 'vec4 to float':
        return "${snippet}.x";
      case 'vec4 to vec2':
        return "${snippet}.xy";
      case 'vec4 to vec3':
        return "${snippet}.xyz";

      case 'mat3 to int':
        return "${this.getType('int')}( ${snippet} * ${this.getType('vec3')}( 1.0 ) ).x";
      case 'mat3 to float':
        return "( ${snippet} * ${this.getType('vec3')}( 1.0 ) ).x";
      case 'mat3 to vec2':
        return "( ${snippet} * ${this.getType('vec3')}( 1.0 ) ).xy";
      case 'mat3 to vec3':
        return "( ${snippet} * ${this.getType('vec3')}( 1.0 ) ).xyz";
      case 'mat3 to vec4':
        return "${this.getType('vec4')}( ${snippet} * ${this.getType('vec3')}( 1.0 ), 1.0 )";

      case 'mat4 to int':
        return "${this.getType('int')}( ${snippet} * ${this.getType('vec4')}( 1.0 ) ).x";
      case 'mat4 to float':
        return "( ${snippet} * ${this.getType('vec4')}( 1.0 ) ).x";
      case 'mat4 to vec2':
        return "( ${snippet} * ${this.getType('vec4')}( 1.0 ) ).xy";
      case 'mat4 to vec3':
        return "( ${snippet} * ${this.getType('vec4')}( 1.0 ) ).xyz";
      case 'mat4 to vec4':
        return "( ${snippet} * ${this.getType('vec4')}( 1.0 ) )";
    }

    return snippet;
  }

  String getSignature() {
    return """// Three.js r${REVISION} - NodeMaterial System\n""";
  }
}
