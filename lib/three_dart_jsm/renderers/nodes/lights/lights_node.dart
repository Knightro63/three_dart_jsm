part of renderer_nodes;

class LightsNode extends Node {
 late List<LightNode> lightNodes;

	LightsNode([lightNodes]):super( 'vec3' ) {
		this.lightNodes = lightNodes ?? [];
	}

	String? generate([NodeBuilder? builder,output]) {
		final lightNodes = this.lightNodes;

		for ( final lightNode in lightNodes ) {
			lightNode.build( builder );
		}

		return 'vec3( 0.0 )';
	}

	static LightsNode fromLights([ lights ]) {
		final lightNodes = [];
		for ( final light in lights ) {
			lightNodes.add( LightNode( light ) );
		}
		return new LightsNode( lightNodes );
	}
}
