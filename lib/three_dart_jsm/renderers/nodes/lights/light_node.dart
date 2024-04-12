part of renderer_nodes;

class LightNode extends Node {
  ColorNode colorNode = ColorNode(Color());
  FloatNode lightCutoffDistanceNode = FloatNode( 0 );
  FloatNode lightDecayExponentNode = FloatNode( 0 );
  Light? light;

	LightNode([this.light]):super('vec3') {
		this.updateType = NodeUpdateType.Object;
	}

	void update([frame]) {
		this.colorNode.value.copy( this.light?.color ).multiplyScalar( this.light?.intensity );
		this.lightCutoffDistanceNode.value = this.light?.distance;
		this.lightDecayExponentNode.value = this.light?.decay;
	}

	String? generate([NodeBuilder? builder,output]) {
		final lightPositionView = Object3DNode( Object3DNode.VIEW_POSITION );
		final positionView = PositionNode( PositionNode.VIEW );
		final lVector = OperatorNode( '-', lightPositionView, positionView );
		final lightDirection = MathNode( MathNode.NORMALIZE, lVector );
		final lightDistance = MathNode( MathNode.LENGTH, lVector );
		final lightAttenuation = getDistanceAttenuation(
			lightDistance,
			cutoffDistance: this.lightCutoffDistanceNode,
			decayExponent: this.lightDecayExponentNode
		);

		final lightColor = OperatorNode( '*', this.colorNode, lightAttenuation );

		lightPositionView.object3d = this.light;

		final lightingModelFunction = builder?.context.lightingModel;

		if ( lightingModelFunction != null ) {
			final directDiffuse = builder?.context.directDiffuse;
			final directSpecular = builder?.context.directSpecular;

			lightingModelFunction( {
				lightDirection,
				lightColor,
				directDiffuse,
				directSpecular
			}, builder );
		}
    return null;
	}
}
