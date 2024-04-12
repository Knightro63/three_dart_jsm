part of renderer_nodes;

class MathNode extends TempNode {
  // 1 input

  static const String RAD = 'radians';
  static const String DEG = 'degrees';
  static const String EXP = 'exp';
  static const String EXP2 = 'exp2';
  static const String LOG = 'log';
  static const String LOG2 = 'log2';
  static const String SQRT = 'sqrt';
  static const String INV_SQRT = 'inversesqrt';
  static const String FLOOR = 'floor';
  static const String CEIL = 'ceil';
  static const String NORMALIZE = 'normalize';
  static const String FRACT = 'fract';
  static const String SIN = 'sin';
  static const String COS = 'cos';
  static const String TAN = 'tan';
  static const String ASIN = 'asin';
  static const String ACOS = 'acos';
  static const String ATAN = 'atan';
  static const String ABS = 'abs';
  static const String SIGN = 'sign';
  static const String LENGTH = 'length';
  static const String NEGATE = 'negate';
  static const String INVERT = 'invert';
  static const String DFDX = 'dFdx';
  static const String DFDY = 'dFdy';
  static const String SATURATE = 'saturate';
  static const String ROUND = 'round';

  // 2 inputs

  static const String MIN = 'min';
  static const String MAX = 'max';
  static const String MOD = 'mod';
  static const String STEP = 'step';
  static const String REFLECT = 'reflect';
  static const String DISTANCE = 'distance';
  static const String DOT = 'dot';
  static const String CROSS = 'cross';
  static const String POW = 'pow';
  static const String TRANSFORM_DIRECTION = 'transformDirection';

  // 3 inputs

  static const String MIX = 'mix';
  static const String CLAMP = 'clamp';
  static const String REFRACT = 'refract';
  static const String SMOOTHSTEP = 'smoothstep';
  static const String FACEFORWARD = 'faceforward';

  late String method;
  late Node aNode;
  late Node? bNode;
  late Node? cNode;

  MathNode(this.method, this.aNode, [this.bNode = null, this.cNode = null]) : super() {
    this.method = method;

    this.aNode = aNode;
    this.bNode = bNode;
    this.cNode = cNode;
  }

  String? getInputType(NodeBuilder? builder) {
    final aType = this.aNode.getNodeType(builder);
    final bType = this.bNode != null? this.bNode?.getNodeType(builder) : null;
    final cType = this.cNode != null? this.cNode?.getNodeType(builder) : null;

    final aLen = builder?.getTypeLength(aType)??0;
    final bLen = builder?.getTypeLength(bType)??0;
    final cLen = builder?.getTypeLength(cType)??0;

    if (aLen > bLen && aLen > cLen) {
      return aType;
    } else if (bLen > cLen) {
      return bType;
    } else if (cLen > aLen) {
      return cType;
    }

    return aType;
  }

  String? getNodeType([NodeBuilder? builder, output]) {
    final method = this.method;

    if (method == MathNode.LENGTH ||
        method == MathNode.DISTANCE ||
        method == MathNode.DOT) {
      return 'float';
    } else if (method == MathNode.CROSS) {
      return 'vec3';
    } else {
      return this.getInputType(builder);
    }
  }

  String? generate([NodeBuilder? builder, output]) {
    final method = this.method;

    final type = this.getNodeType(builder);
    final inputType = this.getInputType(builder);

    final a = this.aNode;
    final b = this.bNode;
    final c = this.cNode;

    final isWebGL = builder?.renderer.isWebGLRenderer == true;

    if (isWebGL &&
        (method == MathNode.DFDX || method == MathNode.DFDY) &&
        output == 'vec3') {
      // Workaround for Adreno 3XX dFd*( vec3 ) bug. See #9988

      return JoinNode([
        MathNode(method, SplitNode(a, 'x')),
        MathNode(method, SplitNode(a, 'y')),
        MathNode(method, SplitNode(a, 'z'))
      ]).build(builder);
    } else if (method == MathNode.TRANSFORM_DIRECTION) {
      // dir can be either a direction vector or a normal vector
      // upper-left 3x3 of matrix is assumed to be orthogonal

      Node tA = a;
      Node? tB = b;

      if (builder!=null&& builder.isMatrix(tA.getNodeType(builder))) {
        tB = ExpressionNode("${builder.getType('vec4')}( ${tB?.build(builder, 'vec3')}, 0.0 )",'vec4');
      } 
      else{
        tA = ExpressionNode("${builder?.getType('vec4')}( ${tA.build(builder, 'vec3')}, 0.0 )",'vec4');
      }

      final mulNode = SplitNode(OperatorNode('*', tA, tB), 'xyz');

      return MathNode(MathNode.NORMALIZE, mulNode).build(builder);
    } else if (method == MathNode.SATURATE) {
      return "clamp( ${a.build(builder, inputType)}, 0.0, 1.0 )";
    } else if (method == MathNode.NEGATE) {
      return '( -' + a.build(builder, inputType).toString() + ' )';
    } else if (method == MathNode.INVERT) {
      return '( 1.0 - ' + a.build(builder, inputType).toString() + ' )';
    } else {
      final params = [];

      if (method == MathNode.CROSS) {
        params.addAll([a.build(builder, type), b?.build(builder, type)]);
      } else if (method == MathNode.STEP) {
        params.addAll([
          a.build(
              builder,
              builder?.getTypeLength(a.getNodeType(builder)) == 1
                  ? 'float'
                  : inputType),
          b?.build(builder, inputType)
        ]);
      } else if ((isWebGL &&
              (method == MathNode.MIN || method == MathNode.MAX)) ||
          method == MathNode.MOD) {
        params.addAll([
          a.build(builder, inputType),
          b?.build(
              builder,
              builder?.getTypeLength(b.getNodeType(builder)) == 1
                  ? 'float'
                  : inputType)
        ]);
      } else if (method == MathNode.REFRACT) {
        params.addAll([
          a.build(builder, inputType),
          b?.build(builder, inputType),
          c?.build(builder, 'float')
        ]);
      } else if (method == MathNode.MIX) {
        params.addAll([
          a.build(builder, inputType),
          b?.build(builder, inputType),
          c?.build(
              builder,
              builder?.getTypeLength(c.getNodeType(builder)) == 1
                  ? 'float'
                  : inputType)
        ]);
      } else {
        params.addAll([a.build(builder, inputType)]);

        if (c != null) {
          params.addAll(
              [b?.build(builder, inputType), c.build(builder, inputType)]);
        } else if (b != null) {
          params.add(b.build(builder, inputType));
        }
      }

      return "${builder?.getMethod(method)}( ${params.join(', ')} )";
    }
  }
}
