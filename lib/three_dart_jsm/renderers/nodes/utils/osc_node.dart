part of renderer_nodes;

enum OscType{
  sine,
  square,
  triangle,
  sawtooth
}

class OscNode extends Node {
  OscType method;
  late TimerNode timeNode;

	OscNode([this.method = OscType.sine, TimerNode? timeNode]):super(){
    this.timeNode = timeNode??TimerNode();
  }

	String? getNodeType([NodeBuilder? builder, output]) {
		return this.timeNode.getNodeType( builder );
	}

	String? generate([NodeBuilder? builder, output]) {
		final method = this.method;
		final timeNode = this.timeNode;

		dynamic outputNode = null;

		if ( method == OscType.sine ) {
			outputNode = add( mul( sin( mul( add( timeNode, .75 ), PI2 ) ), .5 ), .5 );
		} 
    else if ( method == OscType.square ) {
			outputNode = round( fract( timeNode ) );
		} 
    else if ( method == OscType.triangle ) {
			outputNode = abs( sub( 1, mul( fract( add( timeNode, .5 ) ), 2 ) ) );
		} 
    else if ( method == OscType.sawtooth ) {
			outputNode = fract( timeNode );
		}

		return outputNode.build( builder );
	}
}
