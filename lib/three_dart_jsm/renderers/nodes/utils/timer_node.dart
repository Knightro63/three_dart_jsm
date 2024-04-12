part of renderer_nodes;

enum TimerType{
  local,
  global,
  delta
}

class TimerNode extends FloatNode {
  TimerType scope;
  double scale = 1;

	TimerNode([this.scope = TimerType.local ]):super() {
		this.scope = scope;
		this.updateType = NodeUpdateType.Frame;
	}
  
  @override
	void update([ frame ]) {
		final scope = this.scope;
		final scale = this.scale;

		if ( scope == TimerType.local ) {
			this.value += frame.deltaTime * scale;
		} 
    else if ( scope == TimerType.delta ) {
			this.value = frame.deltaTime * scale;
		} 
    else {
			this.value = frame.time * scale;
		}
	}
}
