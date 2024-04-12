part of renderer_nodes;

final declarationRegexp = RegExp(r"^fn\s*([a-z_0-9]+)?\s*\(([\s\S]*?)\)\s*\-\>\s*([a-z_0-9]+)?",caseSensitive: false);
final propertiesRegexp = RegExp(r"[a-z_0-9]+", caseSensitive: false);

Map<String,dynamic> parse(String source) {
  source = source.trim();

  final declaration = declarationRegexp.allMatches(source).toList();// .firstMatch(source);//source.match(declarationRegexp);

  if (declaration.length == 4) {
    // tokenizer

    final inputsCode = declaration[2].toString();
    final propsMatches = [];

    final matches = propertiesRegexp.allMatches(inputsCode);
    for (final match in matches) {
      propsMatches.add(match.group(0));
    }

    // parser

    final inputs = [];

    int i = 0;

    while (i < propsMatches.length) {
      final name = propsMatches[i++][0];
      final type = propsMatches[i++][0];

      propsMatches[i++][0]; // precision

      inputs.add(NodeFunctionInput(type, name));
    }

    //

    final blockCode = source.substring(declaration[0].start);

    final name = declaration[1] != undefined ? declaration[1] : '';
    final type = declaration[3];

    return {
      'type': type, 
      'inputs': inputs, 
      'name': name, 
      'inputsCode': inputsCode, 
      'blockCode': blockCode
    };
  } else {
    throw ('FunctionNode: Function is not a WGSL code.');
  }
}

class WGSLNodeFunction extends NodeFunction {
  late String inputsCode;
  late String blockCode;

  WGSLNodeFunction.create(String type, inputs, String name) : super(type, inputs, name) {}

  factory WGSLNodeFunction(source) {
    final data = parse(source);
    final type = data["type"];
    final inputs = data["inputs"];
    final name = data["name"];
    final inputsCode = data["inputsCode"];
    final blockCode = data["blockCode"];

    final wnf = WGSLNodeFunction.create(type, inputs, name);

    wnf.inputsCode = inputsCode;
    wnf.blockCode = blockCode;

    return wnf;
  }

  String getCode([String? name]) {
    name ??= this.name;

    return """fn ${name} ( ${this.inputsCode.trim()} ) -> ${this.type}""" + this.blockCode;
  }
}
