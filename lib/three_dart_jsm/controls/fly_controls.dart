part of jsm_controls;

class FlyMoveState{
  double up = 0; 
  double down =  0; 
  double left =  0; 
  double right =  0; 
  double forward =  0; 
  double back =  0; 
  double pitchUp =  0; 
  double pitchDown =  0; 
  double yawLeft =  0; 
  double yawRight =  0; 
  double rollLeft =  0; 
  double rollRight =  0;
}

class _ContainerDimensions{
  _ContainerDimensions({
    required this.size,
    required this.offset
  });
  Size size;
  Offset offset;
}

class FlyControls{
  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get domElement => listenableKey.currentState!;
	Camera object;

  FlyControls(this.object, this.listenableKey ) {
    //if(domElement) this.domElement.setAttribute( 'tabindex', - 1 );

    this.domElement.addEventListener( 'contextmenu', contextmenu, false );
    this.domElement.addEventListener( 'mousemove', mousemove, false );
    this.domElement.addEventListener( 'mousedown', mousedown, false );
    this.domElement.addEventListener( 'mouseup', mouseup, false );
    this.domElement.addEventListener( 'keydown', keydown, false );
    this.domElement.addEventListener( 'keyup', keyup, false );

    this.updateMovementVector();
    this.updateRotationVector();
  }

	double movementSpeed = 1.0;
  double movementSpeedMultiplier = 1.0;
	double rollSpeed = 0.005;
	bool dragToLook = false;
	bool autoForward = false;

	//var changeEvent = {type: 'change' };
	double EPS = 0.000001;

	Quaternion tmpQuaternion = new Quaternion();

	int mouseStatus = 0;

	FlyMoveState moveState = FlyMoveState();
	Vector3 moveVector = Vector3( 0, 0, 0 );
	Vector3 rotationVector = Vector3( 0, 0, 0 );

	void keydown ( event ) {
		if ( event.altKey ) {
			return;
		}

		//event.preventDefault();

		switch ( event.keyCode ) {
			case 16: /* shift */ this.movementSpeedMultiplier = .1; break;

			case 87: /*W*/ this.moveState.forward = 1; break;
			case 83: /*S*/ this.moveState.back = 1; break;

			case 65: /*A*/ this.moveState.left = 1; break;
			case 68: /*D*/ this.moveState.right = 1; break;

			case 82: /*R*/ this.moveState.up = 1; break;
			case 70: /*F*/ this.moveState.down = 1; break;

			case 38: /*up*/ this.moveState.pitchUp = 1; break;
			case 40: /*down*/ this.moveState.pitchDown = 1; break;

			case 37: /*left*/ this.moveState.yawLeft = 1; break;
			case 39: /*right*/ this.moveState.yawRight = 1; break;

			case 81: /*Q*/ this.moveState.rollLeft = 1; break;
			case 69: /*E*/ this.moveState.rollRight = 1; break;

		}

		this.updateMovementVector();
		this.updateRotationVector();
	}

	void keyup( event ) {
		switch ( event.keyCode ) {
			case 16: /* shift */ this.movementSpeedMultiplier = 1; break;

			case 87: /*W*/ this.moveState.forward = 0; break;
			case 83: /*S*/ this.moveState.back = 0; break;

			case 65: /*A*/ this.moveState.left = 0; break;
			case 68: /*D*/ this.moveState.right = 0; break;

			case 82: /*R*/ this.moveState.up = 0; break;
			case 70: /*F*/ this.moveState.down = 0; break;

			case 38: /*up*/ this.moveState.pitchUp = 0; break;
			case 40: /*down*/ this.moveState.pitchDown = 0; break;

			case 37: /*left*/ this.moveState.yawLeft = 0; break;
			case 39: /*right*/ this.moveState.yawRight = 0; break;

			case 81: /*Q*/ this.moveState.rollLeft = 0; break;
			case 69: /*E*/ this.moveState.rollRight = 0; break;
		}

		this.updateMovementVector();
		this.updateRotationVector();
	}

  void mousedown( event ) {
		event.preventDefault();
		event.stopPropagation();

		if ( this.dragToLook ) {
			this.mouseStatus ++;
		} else {
			switch ( event.button ) {
				case 0: this.moveState.forward = 1; break;
				case 2: this.moveState.back = 1; break;
			}

			this.updateMovementVector();
		}
	}

	void mousemove( event ) {
		if ( ! this.dragToLook || this.mouseStatus > 0 ) {
			var container = this.getContainerDimensions();
			var halfWidth = container.size.width / 2;
			var halfHeight = container.size.height / 2;

			this.moveState.yawLeft = - ( ( event.pageX - container.offset.dx ) - halfWidth ) / halfWidth;
			this.moveState.pitchDown = ( ( event.pageY - container.offset.dy ) - halfHeight ) / halfHeight;

			this.updateRotationVector();
		}
	}

	void mouseup( event ) {
		event.preventDefault();
		event.stopPropagation();

		if ( this.dragToLook ) {
			this.mouseStatus --;
			this.moveState.yawLeft = this.moveState.pitchDown = 0;
		} 
    else {
			switch ( event.button ) {
				case 0: this.moveState.forward = 0; break;
				case 2: this.moveState.back = 0; break;
			}

			this.updateMovementVector();
		}

		this.updateRotationVector();
	}

  final _lastQuaternion = new Quaternion();
  final _lastPosition = new Vector3();
  double delta = 1;

	void update() {
    final moveMult = delta * movementSpeed;
    final rotMult = delta * rollSpeed;

    object.translateX( moveVector.x * moveMult );
    object.translateY( moveVector.y * moveMult );
    object.translateZ( moveVector.z * moveMult );

    tmpQuaternion.set( rotationVector.x * rotMult, rotationVector.y * rotMult, rotationVector.z * rotMult, 1 ).normalize();
    object.quaternion.multiply( tmpQuaternion );

    if (
      _lastPosition.distanceToSquared( object.position ) > EPS ||
      8 * ( 1 - _lastQuaternion.dot( object.quaternion ) ) > EPS
    ) {

      // dispatchEvent( changeEvent );
      _lastQuaternion.copy( object.quaternion );
      _lastPosition.copy( object.position );

    }
	}

	void updateMovementVector() {
		final forward = (this.moveState.forward > 0 || (this.autoForward && this.moveState.back == 0)) ? 1 : 0;

		this.moveVector.x = ( - this.moveState.left + this.moveState.right );
		this.moveVector.y = ( - this.moveState.down + this.moveState.up );
		this.moveVector.z = ( - forward + this.moveState.back );
	}

	void updateRotationVector () {
		this.rotationVector.x = ( - this.moveState.pitchDown + this.moveState.pitchUp );
		this.rotationVector.y = ( - this.moveState.yawRight + this.moveState.yawLeft );
		this.rotationVector.z = ( - this.moveState.rollRight + this.moveState.rollLeft );
	}

	_ContainerDimensions getContainerDimensions () {
		// if ( this.domElement != document ) {
			return _ContainerDimensions(
				size: Size(this.domElement.clientWidth, this.domElement.clientHeight),
				offset: Offset(this.domElement.offsetLeft, this.domElement.offsetTop)
      );
		// }
    // else {
		// 	return _ContainerDimensions(
		// 		size: Size(window.innerWidth, window.innerHeight),
		// 		offset: Offset(0,0,)
    //   );
		// }
	}

	void contextmenu( event ) {
		event.preventDefault();
	}

	void dispose(){
		this.domElement.removeEventListener( 'contextmenu', contextmenu, false );
		this.domElement.removeEventListener( 'mousedown', mousedown, false );
		this.domElement.removeEventListener( 'mousemove', mousemove, false );
		this.domElement.removeEventListener( 'mouseup', mouseup, false );
		this.domElement.removeEventListener( 'keydown', keydown, false );
		this.domElement.removeEventListener( 'keyup', keyup, false );
	}
}
