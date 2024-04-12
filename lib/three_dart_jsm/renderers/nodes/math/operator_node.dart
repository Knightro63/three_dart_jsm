part of renderer_nodes;

class OperatorNode extends TempNode {
  late String op;
  late Node? aNode;
  late Node? bNode;

  OperatorNode(this.op, Node? aNode, Node? bNode, [List? params]) : super() {
    generateLength = 2;

    if (params != null && params.length > 0) {
      Node? finalBNode = bNode;

      for (int i = 0; i < params.length; i++) {
        finalBNode = OperatorNode(op, finalBNode, params[i]);
      }

      bNode = finalBNode;
    }

    this.aNode = aNode;
    this.bNode = bNode;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    final op = this.op;

    final aNode = this.aNode;
    final bNode = this.bNode;

    final typeA = aNode?.getNodeType(builder);
    final typeB = bNode?.getNodeType(builder);

    if (typeA == 'void' || typeB == 'void') {
      return 'void';
    } 
    else if (op == '=') {
      return typeA;
    } 
    else if (op == '==' || op == '&&') {
      return 'bool';
    } 
    else if (op == '<=' || op == '>') {
      final length = builder?.getTypeLength(output);
      return (length ?? 0) > 1 ? "bvec${length}" : 'bool';
    } 
    else if(builder != null){
      if (typeA == 'float' && builder.isMatrix(typeB)) {
        return typeB;
      } 
      else if (builder.isMatrix(typeA) && builder.isVector(typeB)) {
        // matrix x vector
        return builder.getVectorFromMatrix(typeA);
      } 
      else if (builder.isVector(typeA) && builder.isMatrix(typeB)) {
        // vector x matrix
        return builder.getVectorFromMatrix(typeB);
      } 
      else if (builder.getTypeLength(typeB) > builder.getTypeLength(typeA)) {
        // anytype x anytype: use the greater length vector
        return typeB;
      }
      return typeA;
    }

    return null;
  }

  String? generate([NodeBuilder? builder, output]) {
    final op = this.op;

    final aNode = this.aNode;
    final bNode = this.bNode;

    final type = this.getNodeType(builder, output);

    String? typeA = null;
    String? typeB = null;

    if (type != 'void') {
      typeA = aNode?.getNodeType(builder);
      typeB = bNode?.getNodeType(builder);

      if (op == '=') {
        typeB = typeA;
      }
      else if(builder != null){
        if (builder.isMatrix(typeA) && builder.isVector(typeB)) {
          // matrix x vector
          typeB = builder.getVectorFromMatrix(typeA);
        } 
        else if (builder.isVector(typeA) && builder.isMatrix(typeB)) {
          // vector x matrix
          typeA = builder.getVectorFromMatrix(typeB);
        } 
        else {
          // anytype x anytype
          typeA = typeB = type;
        }
      }
      else {
        // anytype x anytype
        typeA = typeB = type;
      }
    } 
    else {
      typeA = typeB = type;
    }

    final a = aNode?.build(builder, typeA);
    final b = bNode?.build(builder, typeB);

    final outputLength = builder?.getTypeLength(output) ?? 0;

    if (output != 'void') {
      if (op == '=') {
        builder?.addFlowCode("${a} ${this.op} ${b}");

        return a;
      } else if (op == '>' && outputLength > 1) {
        return "${builder?.getMethod('greaterThan')}( ${a}, ${b} )";
      } else if (op == '<=' && outputLength > 1) {
        return "${builder?.getMethod('lessThanEqual')}( ${a}, ${b} )";
      } else {
        return "( ${a} ${this.op} ${b} )";
      }
    } else if (typeA != 'void') {
      return "${a} ${this.op} ${b}";
    }

    return null;
  }
}
