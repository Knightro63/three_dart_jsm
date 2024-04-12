part of renderer_nodes;

Proxy(target, handler) {
  return _Proxy(target, handler);
}

class _Proxy {
  late dynamic target;
  late dynamic handler;
  _Proxy(this.target, this.handler) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    String name = invocation.memberName.toString();

    name = name.replaceFirst(RegExp(r'^Symbol\("'), "");
    name = name.replaceFirst(RegExp(r'"\)$'), "");


    String prop = name;
    final node = target;

    if(prop == 'build') {

      final params = invocation.typeArguments;
      final positional = invocation.positionalArguments;

      return node.build(positional[0], positional[1]);
    }

    // handler get
    if (prop is String && node.getProperty(prop) == undefined) {
      if (RegExp(r"^[xyzwrgbastpq]{1,4}$").hasMatch(prop) == true) {
        // accessing properties ( swizzle )

        prop = prop
          ..replaceAll(RegExp(r"r|s"), 'x')
              .replaceAll(RegExp(r"g|t"), 'y')
              .replaceAll(RegExp(r"b|p"), 'z')
              .replaceAll(RegExp(r"a|q"), 'w');

        return ShaderNodeObject(SplitNode(node, prop));
      } else if (RegExp(r"^\d+$").hasMatch(prop) == true) {
        // accessing array

        return ShaderNodeObject(ArrayElementNode(
            node, FloatNode(num.parse(prop)).setConst(true)));
      }
    }

    return node.getProperty(prop);
  }
}

class NodeHandler {

	// factory NodeHandler( Function nodeClosure, params ) {
	// 	final inputs = params.shift();
	// 	return nodeClosure( ShaderNodeObjects( inputs ), params );
	// }

	get ( node, prop ) {

		if ( prop is String && node[ prop ] == undefined ) {

			if ( RegExp(r"^[xyzwrgbastpq]{1,4}$").hasMatch( prop ) == true ) {

				// accessing properties ( swizzle )

				prop = prop..replaceAll( RegExp(r"r|s"), 'x' )
					.replaceAll( RegExp(r"g|t"), 'y' )
					.replaceAll( RegExp(r"b|p"), 'z' )
					.replaceAll( RegExp(r"a|q"), 'w' );

				return ShaderNodeObject( SplitNode( node, prop ) );

			} else if ( RegExp(r"^\d+$").hasMatch( prop ) == true ) {

				// accessing array

				return ShaderNodeObject( ArrayElementNode( node, FloatNode( num.parse( prop ) ).setConst( true ) ) );

			}

		}

		return node[ prop ];
	}
}

final nodeObjects = WeakMap();

ShaderNodeObject(obj) {
  if (obj is num) {
    return ShaderNodeObject(FloatNode(obj).setConst(true));
  } 
  else if (obj is Node) {
    dynamic nodeObject = nodeObjects.get(obj);

    if (nodeObject == undefined) {
      nodeObject = Proxy( obj, NodeHandler );
      nodeObjects.set(obj, nodeObject);
    }

    return nodeObject;
  }

  return obj;
}

ShaderNodeObjects(objects) {
  for (final name in objects) {
    objects[name] = ShaderNodeObject(objects[name]);
  }
  return objects;
}

ShaderNodeArray(array) {
  final len = array.length;
  for (int i = 0; i < len; i++) {
    array[i] = ShaderNodeObject(array[i]);
  }
  return array;
}

ShaderNodeProxy(NodeClass, [scope = null, factor = null]) {
  print(" ShaderNode .ShaderNodeProxy NodeClass: ${NodeClass} ");

  // TODO

  // if ( scope == null ) {

  // 	return ( params ) {

  // 		return ShaderNodeObject( NodeClass( ShaderNodeArray( params ) ) );

  // 	};

  // } else if ( factor == null ) {

  // 	return ( params ) {

  // 		return ShaderNodeObject( NodeClass( scope, ShaderNodeArray( params ) ) );

  // 	};

  // } else {

  // 	factor = ShaderNodeObject( factor );

  // 	return ( params ) {

  // 		return ShaderNodeObject( NodeClass( scope, ShaderNodeArray( params ), factor ) );

  // 	};

  // }
}

ShaderNodeScript(jsFunc) {
  return (inputs, builder) {
    ShaderNodeObjects(inputs);

    return ShaderNodeObject(jsFunc(inputs, builder));
  };
}

// final ShaderNode = Proxy( ShaderNodeScript, NodeHandler );
final ShaderNode = ShaderNodeScript;

//
// Node Material Shader Syntax
//

final uniform = ShaderNode((inputNode) {
  inputNode.setConst(false);

  return inputNode;
});

final nodeObject = (val) {
  return ShaderNodeObject(val);
};

final float = (val) {
  return nodeObject(FloatNode(val).setConst(true));
};

final color = (params) {
  return nodeObject(ColorNode(Color(params)).setConst(true));
};

final join = (params) {
  return nodeObject(JoinNode(ShaderNodeArray(params)));
};

final cond = (params) {
  return nodeObject(CondNode(ShaderNodeArray(params)));
};

final vec2 = (params) {
  if (params[0]?.isNode == true) {
    return nodeObject(ConvertNode(params[0], 'vec2'));
  } else {
    // Providing one scalar value: This value is used for all components

    if (params.length == 1) {
      params[1] = params[0];
    }

    return nodeObject(Vector2Node(Vector2(params)).setConst(true));
  }
};

final vec3 = (params) {
  if (params[0]?.isNode == true) {
    return nodeObject(ConvertNode(params[0], 'vec3'));
  } else {
    // Providing one scalar value: This value is used for all components

    if (params.length == 1) {
      params[1] = params[2] = params[0];
    }

    return nodeObject(Vector3Node(Vector3(params)).setConst(true));
  }
};

final vec4 = (params) {
  if (params[0]?.isNode == true) {
    return nodeObject(ConvertNode(params[0], 'vec4'));
  } else {
    // Providing one scalar value: This value is used for all components

    if (params.length == 1) {
      params[1] = params[2] = params[3] = params[0];
    }

    return nodeObject(Vector4Node(Vector4(params)).setConst(true));
  }
};

final addTo = (varNode, params) {
  varNode.node = add(varNode.node, ShaderNodeArray(params));

  return nodeObject(varNode);
};

final add = ShaderNodeProxy(OperatorNode, '+');
final sub = ShaderNodeProxy(OperatorNode, '-');
final mul = ShaderNodeProxy(OperatorNode, '*');
final div = ShaderNodeProxy(OperatorNode, '/');
final equal = ShaderNodeProxy(OperatorNode, '==');
final assign = ShaderNodeProxy(OperatorNode, '=');
final greaterThan = ShaderNodeProxy(OperatorNode, '>');
final lessThanEqual = ShaderNodeProxy(OperatorNode, '<=');
final and = ShaderNodeProxy(OperatorNode, '&&');

final element = ShaderNodeProxy(ArrayElementNode);

final normalGeometry = NormalNode(NormalNode.GEOMETRY);
final normalLocal = NormalNode(NormalNode.LOCAL);
final normalWorld = NormalNode(NormalNode.WORLD);
final normalView = NormalNode(NormalNode.VIEW);
final transformedNormalView = VarNode(
    NormalNode(NormalNode.VIEW), 'TransformedNormalView', 'vec3');

final positionLocal = PositionNode(PositionNode.LOCAL);
final positionWorld = PositionNode(PositionNode.WORLD);
final positionView = PositionNode(PositionNode.VIEW);
final positionViewDirection = PositionNode(PositionNode.VIEW_DIRECTION);

final PI = float(3.141592653589793);
final PI2 = float(6.283185307179586);
final PI_HALF = float(1.5707963267948966);
final RECIPROCAL_PI = float(0.3183098861837907);
final RECIPROCAL_PI2 = float(0.15915494309189535);
final EPSILON = float(1e-6);

final diffuseColor = PropertyNode('DiffuseColor', 'vec4');
final roughness = PropertyNode('Roughness', 'float');
final metalness = PropertyNode('Metalness', 'float');
final alphaTest = PropertyNode('AlphaTest', 'float');
final specularColor = PropertyNode('SpecularColor', 'color');

final abs = ShaderNodeProxy(MathNode, 'abs');
final acos = ShaderNodeProxy(MathNode, 'acos');
final asin = ShaderNodeProxy(MathNode, 'asin');
final atan = ShaderNodeProxy(MathNode, 'atan');
final ceil = ShaderNodeProxy(MathNode, 'ceil');
final clamp = ShaderNodeProxy(MathNode, 'clamp');
final cos = ShaderNodeProxy(MathNode, 'cos');
final cross = ShaderNodeProxy(MathNode, 'cross');
final degrees = ShaderNodeProxy(MathNode, 'degrees');
final dFdx = ShaderNodeProxy(MathNode, 'dFdx');
final dFdy = ShaderNodeProxy(MathNode, 'dFdy');
final distance = ShaderNodeProxy(MathNode, 'distance');
final dot = ShaderNodeProxy(MathNode, 'dot');
final exp = ShaderNodeProxy(MathNode, 'exp');
final exp2 = ShaderNodeProxy(MathNode, 'exp2');
final faceforward = ShaderNodeProxy(MathNode, 'faceforward');
final floor = ShaderNodeProxy(MathNode, 'floor');
final fract = ShaderNodeProxy(MathNode, 'fract');
final invert = ShaderNodeProxy(MathNode, 'invert');
final inversesqrt = ShaderNodeProxy(MathNode, 'inversesqrt');
final length = ShaderNodeProxy(MathNode, 'length');
final log = ShaderNodeProxy(MathNode, 'log');
final log2 = ShaderNodeProxy(MathNode, 'log2');
final max = ShaderNodeProxy(MathNode, 'max');
final min = ShaderNodeProxy(MathNode, 'min');
final mix = ShaderNodeProxy(MathNode, 'mix');
final mod = ShaderNodeProxy(MathNode, 'mod');
final negate = ShaderNodeProxy(MathNode, 'negate');
final normalize = ShaderNodeProxy(MathNode, 'normalize');
final pow = ShaderNodeProxy(MathNode, 'pow');
final pow2 = ShaderNodeProxy(MathNode, 'pow', 2);
final pow3 = ShaderNodeProxy(MathNode, 'pow', 3);
final pow4 = ShaderNodeProxy(MathNode, 'pow', 4);
final radians = ShaderNodeProxy(MathNode, 'radians');
final reflect = ShaderNodeProxy(MathNode, 'reflect');
final refract = ShaderNodeProxy(MathNode, 'refract');
final round = ShaderNodeProxy(MathNode, 'round');
final saturate = ShaderNodeProxy(MathNode, 'saturate');
final sign = ShaderNodeProxy(MathNode, 'sign');
final sin = ShaderNodeProxy(MathNode, 'sin');
final smoothstep = ShaderNodeProxy(MathNode, 'smoothstep');
final sqrt = ShaderNodeProxy(MathNode, 'sqrt');
final step = ShaderNodeProxy(MathNode, 'step');
final tan = ShaderNodeProxy(MathNode, 'tan');
final transformDirection = ShaderNodeProxy(MathNode, 'transformDirection');
