part of renderer_nodes;

class PointUVNode extends Node {

	PointUVNode():super( 'vec2' );

	String generate() {
		return 'vec2( gl_PointCoord.x, 1.0 - gl_PointCoord.y )';
	}

}