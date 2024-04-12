part of jsm_controls;

//trackball state
class State2 {
  static const int idle = 0;
  static const int rotate = 1;
  static const int pan = 2;
  static const int scale = 3;
  static const int fov = 4;
  static const int focus = 5;
  static const int zRotate = 6;
  static const int touchMulti = 7;
  static const int animationFocus = 8;
  static const int animationRotate = 9;
}

class Input {
  static const int none = 0;
  static const int oneFinger = 1;
  static const int oneFingerSwitched = 2;
  static const int twoFinger = 3;
  static const int multiFinger = 4;
  static const int cursor = 5;
}

//cursor center coordinates
Vector2 _center = Vector2(0, 0);

//transformation matrices for gizmos and camera
Map<String,Matrix4> _transformation = {'camera': Matrix4(), 'gizmos': Matrix4()};

Matrix4 _gizmoMatrixStateTemp = Matrix4();
Matrix4 _cameraMatrixStateTemp = Matrix4();
Vector3 _scalePointTemp = Vector3();

/// *
/// *
/// * @param {Camera} camera Virtual camera used in the scene
/// * @param {HTMLElement} domElement Renderer's dom element
/// * @param {Scene} scene The scene to be rendered
/// *
class ArcballControls with EventDispatcher {
  Vector3 target = Vector3();
  Vector3 _currentTarget = Vector3();
  double radiusFactor = 0.67;

  final mouseActions = [];
  String? _mouseOp;

  //global vectors and matrices that are used in some operations to avoid creating objects every time (e.g. every time cursor moves)
  Vector2 _v2_1 = Vector2();
  Vector3 _v3_1 = Vector3();
  Vector3 _v3_2 = Vector3();

  Matrix4 _m4_1 = Matrix4();
  Matrix4 _m4_2 = Matrix4();

  Quaternion _quat = Quaternion();

  //transformation matrices
  Matrix4 _translationMatrix = Matrix4(); //matrix for translation operation
  Matrix4 _rotationMatrix = Matrix4(); //matrix for rotation operation
  Matrix4 _scaleMatrix = Matrix4(); //matrix for scaling operation

  Vector3 _rotationAxis = Vector3(); //axis for rotate operation

  //camera state
  Matrix4 _cameraMatrixState = Matrix4();
  Matrix4 _cameraProjectionState = Matrix4();

  num _fovState = 1;
  Vector3 _upState = Vector3();
  double _zoomState = 1;
  num _nearPos = 0;
  num _farPos = 0;

  Matrix4 _gizmoMatrixState = Matrix4();

  //initial values
  Vector3 _up0 = Vector3();
  double _zoom0 = 1;
  num _fov0 = 0;
  num _initialNear = 0;
  num _nearPos0 = 0;
  num _initialFar = 0;
  num _farPos0 = 0;
  Matrix4 _cameraMatrixState0 = Matrix4();
  Matrix4 _gizmoMatrixState0 = Matrix4();

  //pointers array
  int _button = -1;
  final _touchStart = [];
  final _touchCurrent = [];
  int _input = Input.none;

  //two fingers touch interaction
  int _switchSensibility = 32; //minimum movement to be performed to fire single pan start after the second finger has been released
  num _startFingerDistance = 0; //distance between two fingers
  num _currentFingerDistance = 0;
  num _startFingerRotation = 0; //amount of rotation performed with two fingers
  num _currentFingerRotation = 0;

  //double tap
  double _devPxRatio = 0;
  bool _downValid = true;
  int _nclicks = 0;
  final _downEvents = [];
  //int _downStart = 0; //pointerDown time
  int _clickStart = 0; //first click time
  int _maxDownTime = 250;
  int _maxInterval = 300;
  int _posThreshold = 24;
  int _movementThreshold = 24;

  //cursor positions
  final _currentCursorPosition = Vector3();
  final _startCursorPosition = Vector3();

  //grid
  GridHelper? _grid; //grid to be visualized during pan operation
  final _gridPosition = Vector3();

  //gizmos
  final _gizmos = Group();
  int _curvePts = 128;

  //animations
  int _timeStart = -1; //initial time
  int _animationId = -1;

  //focus animation
  final focusAnimationTime = 500; //duration of focus animation in ms

  //rotate animation
  int _timePrev = 0; //time at which previous rotate operation has been detected
  int _timeCurrent = 0; //time at which current rotate operation has been detected
  num _anglePrev = 0; //angle of previous rotation
  num _angleCurrent = 0; //angle of current rotation
  final _cursorPosPrev = Vector3(); //cursor position when previous rotate operation has been detected
  final _cursorPosCurr = Vector3(); //cursor position when current rotate operation has been detected
  num _wPrev = 0; //angular velocity of the previous rotate operation
  num _wCurr = 0; //angular velocity of the current rotate operation

  //parameters
  bool adjustNearFar = false;
  double scaleFactor = 1.1; //zoom/distance multiplier
  int dampingFactor = 25;
  int wMax = 20; //maximum angular velocity allowed
  bool enableAnimations = true; //if animations should be performed
  bool enableGrid = false; //if grid should be showed during pan operation
  bool cursorZoom = false; //if wheel zoom should be cursor centered
  double minFov = 5;
  double maxFov = 90;

  bool enabled = true;
  bool enablePan = true;
  bool enableRotate = true;
  bool enableZoom = true;
  bool enableGizmos = true;

  double minDistance = 0;
  double maxDistance = infinity;
  double minZoom = 0;
  double maxZoom = infinity;

  //trackball parameters
  num _tbRadius = 1;

  late OrbitControls scope;
  late Camera camera;

  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get domElement => listenableKey.currentState!;

  Scene? scene;
  dynamic _state;

  ArcballControls(this.camera, this.listenableKey, [this.scene, double devicePixelRatio = 1.0]): super() {
    //FSA
    this._state = State2.idle;

    this.setCamera(camera);

    if (this.scene != null) {
      this.scene!.add(this._gizmos);
    }

    // this.domElement.style.touchAction = 'none';
    this._devPxRatio = devicePixelRatio;

    this.initializeMouseActions();

    this.domElement.addEventListener('contextmenu', this.onContextMenu);
    this.domElement.addEventListener('wheel', this.onWheel);
    this.domElement.addEventListener('pointerdown', this.onPointerDown);
    this.domElement.addEventListener('pointercancel', this.onPointerCancel);

    // window.addEventListener( 'resize', this.onWindowResize );
  }

  //listeners

  void onWindowResize() {
    final scale = (this._gizmos.scale.x + this._gizmos.scale.y + this._gizmos.scale.z) /3;
    this._tbRadius = this.calculateTbRadius(this.camera);

    final newRadius = this._tbRadius / scale;
    final curve = EllipseCurve(0, 0, newRadius, newRadius);
    final points = curve.getPoints(this._curvePts);
    final curveGeometry = BufferGeometry().setFromPoints(points);

    for (Object3D gizmo in this._gizmos.children) {
      // this._gizmos.children[ gizmo ].geometry = curveGeometry;
      gizmo.geometry = curveGeometry;
    }

    this.dispatchEvent(_changeEvent);
  }

  void onContextMenu(event) {
    if (!this.enabled) {
      return;
    }

    for (int i = 0; i < this.mouseActions.length; i++) {
      if (this.mouseActions[i]['mouse'] == 2) {
        //prevent only if button 2 is actually used
        event.preventDefault();
        break;
      }
    }
  }

  void onPointerCancel() {
    this._touchStart.splice(0, this._touchStart.length);
    this._touchCurrent.splice(0, this._touchCurrent.length);
    this._input = Input.none;
  }

  void onPointerDown(event) {
    if (event.button == 0 && event.isPrimary) {
      this._downValid = true;
      this._downEvents.add(event);
      //this._downStart = DateTime.now().millisecondsSinceEpoch;
    } 
    else {
      this._downValid = false;
    }

    if (event.pointerType == 'touch' && this._input != Input.cursor) {
      this._touchStart.add(event);
      this._touchCurrent.add(event);

      switch (this._input) {
        case Input.none:

          //singleStart
          this._input = Input.oneFinger;
          this.onSinglePanStart(event, 'rotate');

          domElement.addEventListener('pointermove', this.onPointerMove);
          domElement.addEventListener('pointerup', this.onPointerUp);

          break;

        case Input.oneFinger:
        case Input.oneFingerSwitched:

          //doubleStart
          this._input = Input.twoFinger;

          this.onRotateStart();
          this.onPinchStart();
          this.onDoublePanStart();

          break;

        case Input.twoFinger:

          //multipleStart
          this._input = Input.multiFinger;
          this.onTriplePanStart(event);
          break;
      }
    } 
    else if (event.pointerType != 'touch' && this._input == Input.none) {
      String? modifier;

      if (event.ctrlKey || event.metaKey) {
        modifier = 'CTRL';
      } 
      else if (event.shiftKey) {
        modifier = 'SHIFT';
      }

      this._mouseOp = this.getOpFromAction(event.button, modifier);

      if (this._mouseOp != null) {
        domElement.addEventListener('pointermove', this.onPointerMove);
        domElement.addEventListener('pointerup', this.onPointerUp);

        //singleStart
        this._input = Input.cursor;
        this._button = event.button;
        this.onSinglePanStart(event, this._mouseOp);
      }
    }
  }

  void onPointerMove(event) {
    if (event.pointerType == 'touch' && this._input != Input.cursor) {
      switch (this._input) {
        case Input.oneFinger:

          //singleMove
          this.updateTouchEvent(event);

          this.onSinglePanMove(event, State2.rotate);
          break;

        case Input.oneFingerSwitched:
          final movement =
              this.calculatePointersDistance(this._touchCurrent[0], event) *
                  this._devPxRatio;

          if (movement >= this._switchSensibility) {
            //singleMove
            this._input = Input.oneFinger;
            this.updateTouchEvent(event);

            this.onSinglePanStart(event, 'rotate');
            break;
          }

          break;

        case Input.twoFinger:

          //rotate/pan/pinchMove
          this.updateTouchEvent(event);

          this.onRotateMove();
          this.onPinchMove();
          this.onDoublePanMove();

          break;

        case Input.multiFinger:

          //multMove
          this.updateTouchEvent(event);

          this.onTriplePanMove(event);
          break;
      }
    } 
    else if (event.pointerType != 'touch' && this._input == Input.cursor) {
      String? modifier;

      if (event.ctrlKey || event.metaKey) {
        modifier = 'CTRL';
      } else if (event.shiftKey) {
        modifier = 'SHIFT';
      }

      final mouseOpState = this.getOpStateFromAction(this._button, modifier);

      if (mouseOpState != null) {
        this.onSinglePanMove(event, mouseOpState);
      }
    }

    //checkDistance
    if (this._downValid) {
      final movement = this.calculatePointersDistance(
              this._downEvents[this._downEvents.length - 1], event) *
          this._devPxRatio;
      if (movement > this._movementThreshold) {
        this._downValid = false;
      }
    }
  }

  void onPointerUp(event) {
    if (event.pointerType == 'touch' && this._input != Input.cursor) {
      final nTouch = this._touchCurrent.length;

      for (int i = 0; i < nTouch; i++) {
        if (this._touchCurrent[i].pointerId == event.pointerId) {
          this._touchCurrent.splice(i, 1);
          this._touchStart.splice(i, 1);
          break;
        }
      }

      switch (this._input) {
        case Input.oneFinger:
        case Input.oneFingerSwitched:

          //singleEnd
          domElement.removeEventListener('pointermove', this.onPointerMove);
          domElement.removeEventListener('pointerup', this.onPointerUp);

          this._input = Input.none;
          this.onSinglePanEnd();

          break;

        case Input.twoFinger:

          //doubleEnd
          this.onDoublePanEnd(event);
          this.onPinchEnd(event);
          this.onRotateEnd(event);

          //switching to singleStart
          this._input = Input.oneFingerSwitched;

          break;

        case Input.multiFinger:
          if (this._touchCurrent.length == 0) {
            domElement.removeEventListener('pointermove', this.onPointerMove);
            domElement.removeEventListener('pointerup', this.onPointerUp);

            //multCancel
            this._input = Input.none;
            this.onTriplePanEnd();
          }

          break;
      }
    } else if (event.pointerType != 'touch' && this._input == Input.cursor) {
      domElement.removeEventListener('pointermove', this.onPointerMove);
      domElement.removeEventListener('pointerup', this.onPointerUp);

      this._input = Input.none;
      this.onSinglePanEnd();
      this._button = -1;
    }

    if (event.isPrimary) {
      if (this._downValid) {
        final downTime = event.timeStamp -
            this._downEvents[this._downEvents.length - 1].timeStamp;

        if (downTime <= this._maxDownTime) {
          if (this._nclicks == 0) {
            //first valid click detected
            this._nclicks = 1;
            this._clickStart = DateTime.now().millisecondsSinceEpoch;
          } else {
            final clickInterval = event.timeStamp - this._clickStart;
            final movement = this.calculatePointersDistance(
                    this._downEvents[1], this._downEvents[0]) *
                this._devPxRatio;

            if (clickInterval <= this._maxInterval &&
                movement <= this._posThreshold) {
              //second valid click detected
              //fire double tap and reset values
              this._nclicks = 0;
              this._downEvents.splice(0, this._downEvents.length);
              this.onDoubleTap(event);
            } else {
              //'first click'
              this._nclicks = 1;
              this._downEvents.removeAt(0);
              this._clickStart = DateTime.now().millisecondsSinceEpoch;
            }
          }
        } else {
          this._downValid = false;
          this._nclicks = 0;
          this._downEvents.splice(0, this._downEvents.length);
        }
      } else {
        this._nclicks = 0;
        this._downEvents.splice(0, this._downEvents.length);
      }
    }
  }

  void onWheel(event) {
    if (this.enabled && this.enableZoom) {
      String? modifier;

      if (event.ctrlKey || event.metaKey) {
        modifier = 'CTRL';
      } else if (event.shiftKey) {
        modifier = 'SHIFT';
      }

      final mouseOp = this.getOpFromAction(3, modifier);

      if (mouseOp != null) {
        event.preventDefault();
        this.dispatchEvent(_startEvent);

        final notchDeltaY = 125; //distance of one notch of mouse wheel
        num sgn = event.deltaY / notchDeltaY;

        double size = 1;

        if (sgn > 0) {
          size = 1 / this.scaleFactor;
        } else if (sgn < 0) {
          size = this.scaleFactor;
        }

        switch (mouseOp) {
          case 'ZOOM':
            this.updateTbState(State2.scale, true);

            if (sgn > 0) {
              size = 1 / (Math.pow(this.scaleFactor, sgn));
            } else if (sgn < 0) {
              size = Math.pow(this.scaleFactor, -sgn) + 0.0;
            }

            if (this.cursorZoom && this.enablePan) {
              Vector3? scalePoint;

              if (this.camera is OrthographicCamera) {
                scalePoint = this
                    .unprojectOnTbPlane(this.camera, event.clientX,event.clientY)
                    .applyQuaternion(this.camera.quaternion)
                    .multiplyScalar(1 / this.camera.zoom)
                    .add(this._gizmos.position);
              } 
              else if (this.camera is PerspectiveCamera) {
                scalePoint = this
                    .unprojectOnTbPlane(this.camera, event.clientX, event.clientY)
                    .applyQuaternion(this.camera.quaternion)
                    .add(this._gizmos.position);
              }

              this.applyTransformMatrix(this.scale(size, scalePoint));
            } 
            else {
              this.applyTransformMatrix(
                  this.scale(size, this._gizmos.position));
            }

            if (this._grid != null) {
              this.disposeGrid();
              this.drawGrid();
            }

            this.updateTbState(State2.idle, false);

            this.dispatchEvent(_changeEvent);
            this.dispatchEvent(_endEvent);

            break;

          case 'fov':
            if (this.camera is PerspectiveCamera) {
              this.updateTbState(State2.fov, true);

              //Vertigo effect

              //	  fov / 2
              //		|\
              //		| \
              //		|  \
              //	x	|	\
              //		| 	 \
              //		| 	  \
              //		| _ _ _\
              //			y

              //check for iOs shift shortcut
              if (event.deltaX != 0) {
                sgn = event.deltaX / notchDeltaY;

                size = 1;

                if (sgn > 0) {
                  size = 1 / (Math.pow(this.scaleFactor, sgn));
                } else if (sgn < 0) {
                  size = Math.pow(this.scaleFactor, -sgn) + 0.0;
                }
              }

              this._v3_1.setFromMatrixPosition(this._cameraMatrixState);
              final x = this._v3_1.distanceTo(this._gizmos.position);
              double xNew = x /size; //distance between camera and gizmos if scale(size, scalepoint) would be performed

              //check min and max distance
              xNew = MathUtils.clamp(xNew, this.minDistance, this.maxDistance);

              final y = x * Math.tan(MathUtils.deg2rad * this.camera.fov * 0.5);

              //calculate fov
              double newFov = MathUtils.rad2deg * (Math.atan(y / xNew) * 2);

              //check min and max fov
              if (newFov > this.maxFov) {
                newFov = this.maxFov;
              } 
              else if (newFov < this.minFov) {
                newFov = this.minFov;
              }

              final newDistance = y / Math.tan(MathUtils.deg2rad * (newFov / 2));
              size = x / newDistance;

              this.setFov(newFov);
              this.applyTransformMatrix(
                  this.scale(size, this._gizmos.position, false));
            }

            if (this._grid != null) {
              this.disposeGrid();
              this.drawGrid();
            }

            this.updateTbState(State2.idle, false);

            this.dispatchEvent(_changeEvent);
            this.dispatchEvent(_endEvent);

            break;
        }
      }
    }
  }

  void onSinglePanStart(event, operation) {
    if (this.enabled) {
      this.dispatchEvent(_startEvent);

      this.setCenter(event.clientX, event.clientY);

      switch (operation) {
        case 'pan':
          if (!this.enablePan) {
            return;
          }

          if (this._animationId != -1) {
            cancelAnimationFrame(this._animationId);
            this._animationId = -1;
            this._timeStart = -1;

            this.activateGizmos(false);
            this.dispatchEvent(_changeEvent);
          }

          this.updateTbState(State2.pan, true);
          this._startCursorPosition.copy(this.unprojectOnTbPlane(this.camera, _center.x, _center.y));
          if (this.enableGrid) {
            this.drawGrid();
            this.dispatchEvent(_changeEvent);
          }

          break;

        case 'rotate':
          if (!this.enableRotate) {
            return;
          }

          if (this._animationId != -1) {
            cancelAnimationFrame(this._animationId);
            this._animationId = -1;
            this._timeStart = -1;
          }

          this.updateTbState(State2.rotate, true);
          this._startCursorPosition.copy(this.unprojectOnTbSurface(this.camera,
              _center.x, _center.y,this._tbRadius));
          this.activateGizmos(true);
          if (this.enableAnimations) {
            this._timePrev = this._timeCurrent = DateTime.now().millisecondsSinceEpoch;
            this._angleCurrent = this._anglePrev = 0;
            this._cursorPosPrev.copy(this._startCursorPosition);
            this._cursorPosCurr.copy(this._cursorPosPrev);
            this._wCurr = 0;
            this._wPrev = this._wCurr;
          }

          this.dispatchEvent(_changeEvent);
          break;

        case 'fov':
          if (this.camera is! PerspectiveCamera || !this.enableZoom) {
            return;
          }

          if (this._animationId != -1) {
            cancelAnimationFrame(this._animationId);
            this._animationId = -1;
            this._timeStart = -1;

            this.activateGizmos(false);
            this.dispatchEvent(_changeEvent);
          }

          this.updateTbState(State2.fov, true);
          this._startCursorPosition.setY(
              this.getCursorNDC(_center.x, _center.y).y * 0.5);
          this._currentCursorPosition.copy(this._startCursorPosition);
          break;

        case 'ZOOM':
          if (!this.enableZoom) {
            return;
          }

          if (this._animationId != -1) {
            cancelAnimationFrame(this._animationId);
            this._animationId = -1;
            this._timeStart = -1;

            this.activateGizmos(false);
            this.dispatchEvent(_changeEvent);
          }

          this.updateTbState(State2.scale, true);
          this._startCursorPosition.setY(
              this.getCursorNDC(_center.x, _center.y).y * 0.5);
          this._currentCursorPosition.copy(this._startCursorPosition);
          break;
      }
    }
  }

  void onSinglePanMove(event, opState) {
    if (this.enabled) {
      final restart = opState != this._state;
      this.setCenter(event.clientX, event.clientY);

      switch (opState) {
        case State2.pan:
          if (this.enablePan) {
            if (restart) {
              //switch to pan operation

              this.dispatchEvent(_endEvent);
              this.dispatchEvent(_startEvent);

              this.updateTbState(opState, true);
              this._startCursorPosition.copy(this.unprojectOnTbPlane(this.camera, _center.x, _center.y));
              if (this.enableGrid) {
                this.drawGrid();
              }

              this.activateGizmos(false);
            } else {
              //continue with pan operation
              this._currentCursorPosition.copy(this.unprojectOnTbPlane(this.camera, _center.x, _center.y));
              this.applyTransformMatrix(this
                  .pan(this._startCursorPosition, this._currentCursorPosition));
            }
          }

          break;

        case State2.rotate:
          if (this.enableRotate) {
            if (restart) {
              //switch to rotate operation

              this.dispatchEvent(_endEvent);
              this.dispatchEvent(_startEvent);

              this.updateTbState(opState, true);
              this._startCursorPosition.copy(
                this.unprojectOnTbSurface(
                  this.camera,
                  _center.x,
                  _center.y,
                  this._tbRadius
                )
              );

              if (this.enableGrid) {
                this.disposeGrid();
              }

              this.activateGizmos(true);
            } else {
              //continue with rotate operation
              this._currentCursorPosition.copy(
                this.unprojectOnTbSurface(
                  this.camera,
                  _center.x,
                  _center.y,
                  this._tbRadius
                )
              );

              final distance = this
                  ._startCursorPosition
                  .distanceTo(this._currentCursorPosition);
              final angle = this
                  ._startCursorPosition
                  .angleTo(this._currentCursorPosition);
              final amount = Math.max(
                  distance / this._tbRadius, angle); //effective rotation angle

              this.applyTransformMatrix(this.rotate(
                  this.calculateRotationAxis(
                      this._startCursorPosition, this._currentCursorPosition),
                  amount));

              if (this.enableAnimations) {
                this._timePrev = this._timeCurrent;
                this._timeCurrent = DateTime.now().millisecondsSinceEpoch;
                this._anglePrev = this._angleCurrent;
                this._angleCurrent = amount;
                this._cursorPosPrev.copy(this._cursorPosCurr);
                this._cursorPosCurr.copy(this._currentCursorPosition);
                this._wPrev = this._wCurr;
                this._wCurr = this.calculateAngularSpeed(
                  this._anglePrev,
                  this._angleCurrent, 
                  this._timePrev, 
                  this._timeCurrent
                );
              }
            }
          }

          break;

        case State2.scale:
          if (this.enableZoom) {
            if (restart) {
              //switch to zoom operation

              this.dispatchEvent(_endEvent);
              this.dispatchEvent(_startEvent);

              this.updateTbState(opState, true);
              this._startCursorPosition.setY(
                  this.getCursorNDC(_center.x, _center.y).y *
                      0.5);
              this._currentCursorPosition.copy(this._startCursorPosition);

              if (this.enableGrid) {
                this.disposeGrid();
              }

              this.activateGizmos(false);
            } else {
              //continue with zoom operation
              final screenNotches =
                  8; //how many wheel notches corresponds to a full screen pan
              this._currentCursorPosition.setY(
                  this.getCursorNDC(_center.x, _center.y).y *
                      0.5);

              final movement =
                  this._currentCursorPosition.y - this._startCursorPosition.y;

              num size = 1;

              if (movement < 0) {
                size =
                    1 / (Math.pow(this.scaleFactor, -movement * screenNotches));
              } else if (movement > 0) {
                size = Math.pow(this.scaleFactor, movement * screenNotches);
              }

              this.applyTransformMatrix(
                  this.scale(size, this._gizmos.position));
            }
          }

          break;

        case State2.fov:
          if (this.enableZoom && this.camera is PerspectiveCamera) {
            if (restart) {
              //switch to fov operation

              this.dispatchEvent(_endEvent);
              this.dispatchEvent(_startEvent);

              this.updateTbState(opState, true);
              this._startCursorPosition.setY(
                  this.getCursorNDC(_center.x, _center.y).y *
                      0.5);
              this._currentCursorPosition.copy(this._startCursorPosition);

              if (this.enableGrid) {
                this.disposeGrid();
              }

              this.activateGizmos(false);
            } else {
              //continue with fov operation
              final screenNotches =
                  8; //how many wheel notches corresponds to a full screen pan
              this._currentCursorPosition.setY(
                  this.getCursorNDC(_center.x, _center.y).y *
                      0.5);

              final movement =
                  this._currentCursorPosition.y - this._startCursorPosition.y;

              num size = 1;

              if (movement < 0) {
                size =
                    1 / (Math.pow(this.scaleFactor, -movement * screenNotches));
              } else if (movement > 0) {
                size = Math.pow(this.scaleFactor, movement * screenNotches);
              }

              this._v3_1.setFromMatrixPosition(this._cameraMatrixState);
              final x = this._v3_1.distanceTo(this._gizmos.position);
              double xNew = x /size; //distance between camera and gizmos if scale(size, scalepoint) would be performed

              //check min and max distance
              xNew = MathUtils.clamp(xNew, this.minDistance, this.maxDistance);

              final y = x * Math.tan(MathUtils.deg2rad * this._fovState * 0.5);

              //calculate fov
              double newFov = MathUtils.rad2deg * (Math.atan(y / xNew) * 2);

              //check min and max fov
              newFov = MathUtils.clamp(newFov, this.minFov, this.maxFov);

              final newDistance = y / Math.tan(MathUtils.deg2rad * (newFov / 2));
              size = x / newDistance;
              this._v3_2.setFromMatrixPosition(this._gizmoMatrixState);

              this.setFov(newFov);
              this.applyTransformMatrix(this.scale(size, this._v3_2, false));

              //adjusting distance
              _offset
                  .copy(this._gizmos.position)
                  .sub(this.camera.position)
                  .normalize()
                  .multiplyScalar(newDistance / x);
              this._m4_1.makeTranslation(_offset.x, _offset.y, _offset.z);
            }
          }

          break;
      }

      this.dispatchEvent(_changeEvent);
    }
  }

  void onSinglePanEnd() {
    if (this._state == State2.rotate) {
      if (!this.enableRotate) {
        return;
      }

      if (this.enableAnimations) {
        //perform rotation animation
        final deltaTime =
            (DateTime.now().millisecondsSinceEpoch - this._timeCurrent);
        if (deltaTime < 120) {
          final w = Math.abs((this._wPrev + this._wCurr) / 2);

          final self = this;
          this._animationId = requestAnimationFrame((t) {
            self.updateTbState(State2.animationRotate, true);
            final rotationAxis = self.calculateRotationAxis(
                self._cursorPosPrev, self._cursorPosCurr);

            self.onRotationAnim(t, rotationAxis, Math.min(w, self.wMax));
          });
        } else {
          //cursor has been standing still for over 120 ms since last movement
          this.updateTbState(State2.idle, false);
          this.activateGizmos(false);
          this.dispatchEvent(_changeEvent);
        }
      } else {
        this.updateTbState(State2.idle, false);
        this.activateGizmos(false);
        this.dispatchEvent(_changeEvent);
      }
    } else if (this._state == State2.pan || this._state == State2.idle) {
      this.updateTbState(State2.idle, false);

      if (this.enableGrid) {
        this.disposeGrid();
      }

      this.activateGizmos(false);
      this.dispatchEvent(_changeEvent);
    }

    this.dispatchEvent(_endEvent);
  }

  void onDoubleTap(event) {
    if (this.enabled && this.enablePan && this.scene != null) {
      this.dispatchEvent(_startEvent);

      this.setCenter(event.clientX, event.clientY);
      final hitP = this.unprojectOnObj(
          this.getCursorNDC(_center.x, _center.y),
          this.camera);

      if (hitP != null && this.enableAnimations) {
        final self = this;
        if (this._animationId != -1) {
          cancelAnimationFrame(this._animationId);
        }

        this._timeStart = -1;
        this._animationId = requestAnimationFrame((t) {
          self.updateTbState(State2.animationFocus, true);
          self.onFocusAnim(
              t, hitP, self._cameraMatrixState, self._gizmoMatrixState);
        });
      } else if (hitP != null && !this.enableAnimations) {
        this.updateTbState(State2.focus, true);
        this.focus(hitP, this.scaleFactor);
        this.updateTbState(State2.idle, false);
        this.dispatchEvent(_changeEvent);
      }
    }

    this.dispatchEvent(_endEvent);
  }

  void onDoublePanStart() {
    if (this.enabled && this.enablePan) {
      this.dispatchEvent(_startEvent);

      this.updateTbState(State2.pan, true);

      this.setCenter(
          (this._touchCurrent[0].clientX + this._touchCurrent[1].clientX) / 2,
          (this._touchCurrent[0].clientY + this._touchCurrent[1].clientY) / 2);
      this._startCursorPosition.copy(
        this.unprojectOnTbPlane(
          this.camera, _center.x, _center.y, true
        )
      );
      this._currentCursorPosition.copy(this._startCursorPosition);

      this.activateGizmos(false);
    }
  }

  void onDoublePanMove() {
    if (this.enabled && this.enablePan) {
      this.setCenter(
          (this._touchCurrent[0].clientX + this._touchCurrent[1].clientX) / 2,
          (this._touchCurrent[0].clientY + this._touchCurrent[1].clientY) / 2);

      if (this._state != State2.pan) {
        this.updateTbState(State2.pan, true);
        this._startCursorPosition.copy(this._currentCursorPosition);
      }

      this._currentCursorPosition.copy(
        this.unprojectOnTbPlane(
          this.camera, _center.x, _center.y, true
        )
      );
      this.applyTransformMatrix(this
          .pan(this._startCursorPosition, this._currentCursorPosition, true));
      this.dispatchEvent(_changeEvent);
    }
  }

  void onDoublePanEnd(event) {
    this.updateTbState(State2.idle, false);
    this.dispatchEvent(_endEvent);
  }

  void onRotateStart() {
    if (this.enabled && this.enableRotate) {
      this.dispatchEvent(_startEvent);

      this.updateTbState(State2.zRotate, true);

      //this._startFingerRotation = event.rotation;

      this._startFingerRotation =
          this.getAngle(this._touchCurrent[1], this._touchCurrent[0]) +
              this.getAngle(this._touchStart[1], this._touchStart[0]);
      this._currentFingerRotation = this._startFingerRotation;

      this.camera.getWorldDirection(this._rotationAxis); //rotation axis

      if (!this.enablePan && !this.enableZoom) {
        this.activateGizmos(true);
      }
    }
  }

  void onRotateMove() {
    if (this.enabled && this.enableRotate) {
      this.setCenter(
          (this._touchCurrent[0].clientX + this._touchCurrent[1].clientX) / 2,
          (this._touchCurrent[0].clientY + this._touchCurrent[1].clientY) / 2);
      final rotationPoint;

      if (this._state != State2.zRotate) {
        this.updateTbState(State2.zRotate, true);
        this._startFingerRotation = this._currentFingerRotation;
      }

      //this._currentFingerRotation = event.rotation;
      this._currentFingerRotation =
          this.getAngle(this._touchCurrent[1], this._touchCurrent[0]) +
              this.getAngle(this._touchStart[1], this._touchStart[0]);

      if (!this.enablePan) {
        rotationPoint =
            Vector3().setFromMatrixPosition(this._gizmoMatrixState);
      } else {
        this._v3_2.setFromMatrixPosition(this._gizmoMatrixState);
        rotationPoint = this
            .unprojectOnTbPlane(this.camera, _center.x, _center.y)
            .applyQuaternion(this.camera.quaternion)
            .multiplyScalar(1 / this.camera.zoom)
            .add(this._v3_2);
      }

      final amount = MathUtils.deg2rad *
          (this._startFingerRotation - this._currentFingerRotation);

      this.applyTransformMatrix(this.zRotate(rotationPoint, amount));
      this.dispatchEvent(_changeEvent);
    }
  }

  onRotateEnd(event) {
    this.updateTbState(State2.idle, false);
    this.activateGizmos(false);
    this.dispatchEvent(_endEvent);
  }

  onPinchStart() {
    if (this.enabled && this.enableZoom) {
      this.dispatchEvent(_startEvent);
      this.updateTbState(State2.scale, true);

      this._startFingerDistance = this.calculatePointersDistance(
          this._touchCurrent[0], this._touchCurrent[1]);
      this._currentFingerDistance = this._startFingerDistance;

      this.activateGizmos(false);
    }
  }

  void onPinchMove() {
    if (this.enabled && this.enableZoom) {
      this.setCenter(
          (this._touchCurrent[0].clientX + this._touchCurrent[1].clientX) / 2,
          (this._touchCurrent[0].clientY + this._touchCurrent[1].clientY) / 2);
      final minDistance = 12; //minimum distance between fingers (in css pixels)

      if (this._state != State2.scale) {
        this._startFingerDistance = this._currentFingerDistance;
        this.updateTbState(State2.scale, true);
      }

      this._currentFingerDistance = Math.max(
          this.calculatePointersDistance(
            this._touchCurrent[0], 
            this._touchCurrent[1]
          ),
          minDistance * this._devPxRatio
        );
      final amount = this._currentFingerDistance / this._startFingerDistance;

      Vector3? scalePoint;

      if (!this.enablePan) {
        scalePoint = this._gizmos.position;
      } 
      else {
        if (this.camera is OrthographicCamera) {
          scalePoint = this
              .unprojectOnTbPlane(this.camera, _center.x, _center.y)
              .applyQuaternion(this.camera.quaternion)
              .multiplyScalar(1 / this.camera.zoom)
              .add(this._gizmos.position);
        } 
        else if (this.camera is PerspectiveCamera) {
          scalePoint = this
              .unprojectOnTbPlane(this.camera, _center.x, _center.y)
              .applyQuaternion(this.camera.quaternion)
              .add(this._gizmos.position);
        }
      }

      this.applyTransformMatrix(this.scale(amount, scalePoint));
      this.dispatchEvent(_changeEvent);
    }
  }

  void onPinchEnd(event) {
    this.updateTbState(State2.idle, false);
    this.dispatchEvent(_endEvent);
  }

  void onTriplePanStart(event) {
    if (this.enabled && this.enableZoom) {
      this.dispatchEvent(_startEvent);

      this.updateTbState(State2.scale, true);

      //final center = event.center;
      num clientX = 0;
      num clientY = 0;
      final nFingers = this._touchCurrent.length;

      for (int i = 0; i < nFingers; i++) {
        clientX += this._touchCurrent[i]!.clientX;
        clientY += this._touchCurrent[i]!.clientY;
      }

      this.setCenter(clientX / nFingers, clientY / nFingers);

      this._startCursorPosition.setY(
          this.getCursorNDC(_center.x, _center.y).y * 0.5);
      this._currentCursorPosition.copy(this._startCursorPosition);
    }
  }

  void onTriplePanMove(event) {
    if (this.enabled && this.enableZoom) {
      //	  fov / 2
      //		|\
      //		| \
      //		|  \
      //	x	|	\
      //		| 	 \
      //		| 	  \
      //		| _ _ _\
      //			y

      //final center = event.center;
      num clientX = 0;
      num clientY = 0;
      final nFingers = this._touchCurrent.length;

      for (int i = 0; i < nFingers; i++) {
        clientX += this._touchCurrent[i].clientX;
        clientY += this._touchCurrent[i].clientY;
      }

      this.setCenter(clientX / nFingers, clientY / nFingers);

      final screenNotches =
          8; //how many wheel notches corresponds to a full screen pan
      this._currentCursorPosition.setY(
          this.getCursorNDC(_center.x, _center.y).y * 0.5);

      final movement =
          this._currentCursorPosition.y - this._startCursorPosition.y;

      num size = 1;

      if (movement < 0) {
        size = 1 / (Math.pow(this.scaleFactor, -movement * screenNotches));
      } 
      else if (movement > 0) {
        size = Math.pow(this.scaleFactor, movement * screenNotches);
      }

      this._v3_1.setFromMatrixPosition(this._cameraMatrixState);
      final x = this._v3_1.distanceTo(this._gizmos.position);
      num xNew = x /size; //distance between camera and gizmos if scale(size, scalepoint) would be performed

      //check min and max distance
      xNew = MathUtils.clamp(xNew, this.minDistance, this.maxDistance);

      final y = x * Math.tan(MathUtils.deg2rad * this._fovState * 0.5);

      //calculate fov
      double newFov = MathUtils.rad2deg * (Math.atan(y / xNew) * 2);

      //check min and max fov
      newFov = MathUtils.clamp(newFov, this.minFov, this.maxFov);

      final newDistance = y / Math.tan(MathUtils.deg2rad * (newFov / 2));
      size = x / newDistance;
      this._v3_2.setFromMatrixPosition(this._gizmoMatrixState);

      this.setFov(newFov);
      this.applyTransformMatrix(this.scale(size, this._v3_2, false));

      //adjusting distance
      _offset
          .copy(this._gizmos.position)
          .sub(this.camera.position)
          .normalize()
          .multiplyScalar(newDistance / x);
      this._m4_1.makeTranslation(_offset.x, _offset.y, _offset.z);

      this.dispatchEvent(_changeEvent);
    }
  }

  void onTriplePanEnd() {
    this.updateTbState(State2.idle, false);
    this.dispatchEvent(_endEvent);
    //this.dispatchEvent( _changeEvent );
  }

  /// *
	/// * Set _center's x/y coordinates
	/// * @param {Number} clientX
	/// * @param {Number} clientY
	/// *
  void setCenter(double clientX, double clientY) {
    _center.x = clientX;
    _center.y = clientY;
  }

  /// *
	/// * Set default mouse actions
	/// *
  void initializeMouseActions() {
    this.setMouseAction('pan', 0, 'CTRL');
    this.setMouseAction('pan', 2);

    this.setMouseAction('rotate', 0);

    this.setMouseAction('ZOOM', 3);
    this.setMouseAction('ZOOM', 1);

    this.setMouseAction('fov', 3, 'SHIFT');
    this.setMouseAction('fov', 1, 'SHIFT');
  }

  /// *
	/// * Compare two mouse actions
	/// * @param {Object} action1
	/// * @param {Object} action2
	/// * @returns {Boolean} True if action1 and action 2 are the same mouse action, false otherwise
	/// *
  bool compareMouseAction(action1, action2) {
    if (action1['operation'] == action2['operation']) {
      if (action1['mouse'] == action2['mouse'] &&
          action1['key'] == action2['key']) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  /// *
	/// * Set a mouse action by specifying the operation to be performed and a mouse/key combination. In case of conflict, replaces the existing one
	/// * @param {String} operation The operation to be performed ('pan', 'rotate', 'ZOOM', 'fov)
	/// * @param {*} mouse A mouse button (0, 1, 2, 3) or for wheel notches
	/// * @param {*} key The keyboard modifier ('CTRL', 'SHIFT') or null if key is not needed
	/// * @returns {Boolean} True if the mouse action has been successfully added, false otherwise
	/// *
  bool setMouseAction(String operation, int mouse, [String? key]) {
    final operationInput = ['pan', 'rotate', 'ZOOM', 'fov'];
    final mouseInput = ['0', '1', '2', '3'];
    final keyInput = ['CTRL', 'SHIFT', null];
    int? state;

    if (
      !operationInput.contains(operation) ||
      !mouseInput.contains(mouse.toString()) ||
      !keyInput.contains(key)
    ) {
      //invalid parameters
      return false;
    }

    if (mouse == 3) {
      if (operation != 'ZOOM' && operation != 'fov') {
        //cannot associate 2D operation to 1D input
        return false;
      }
    }

    switch (operation) {
      case 'pan':
        state = State2.pan;
        break;

      case 'rotate':
        state = State2.rotate;
        break;

      case 'ZOOM':
        state = State2.scale;
        break;

      case 'fov':
        state = State2.fov;
        break;
    }

    final action = {
      'operation': operation,
      'mouse': mouse,
      'key': key,
      'state': state
    };

    for (int i = 0; i < this.mouseActions.length; i++) {
      if (
        this.mouseActions[i]['mouse'] == action['mouse'] &&
        this.mouseActions[i]['key'] == action['key']
      ) {
        this.mouseActions.splice(i, 1, action);
        return true;
      }
    }

    this.mouseActions.add(action);
    return true;
  }

  /// *
	/// * Remove a mouse action by specifying its mouse/key combination
	/// * @param {*} mouse A mouse button (0, 1, 2, 3) 3 for wheel notches
	/// * @param {*} key The keyboard modifier ('CTRL', 'SHIFT') or null if key is not needed
	/// * @returns {Boolean} True if the operation has been succesfully removed, false otherwise
	/// *
  bool unsetMouseAction(mouse, [String? key]) {
    for (int i = 0; i < this.mouseActions.length; i++) {
      if (
        this.mouseActions[i]['mouse'] == mouse &&
        this.mouseActions[i]['key'] == key
      ) {
        this.mouseActions.splice(i, 1);
        return true;
      }
    }

    return false;
  }

  /// *
	/// * Return the operation associated to a mouse/keyboard combination
	/// * @param {*} mouse A mouse button (0, 1, 2, 3) 3 for wheel notches
	/// * @param {*} key The keyboard modifier ('CTRL', 'SHIFT') or null if key is not needed
	/// * @returns The operation if it has been found, null otherwise
	/// *
  String? getOpFromAction(int mouse, String? key) {
    Map<String,dynamic> action;

    for (int i = 0; i < this.mouseActions.length; i++) {
      action = this.mouseActions[i];
      if (action['mouse'] == mouse && action['key'] == key) {
        return action['operation'];
      }
    }

    if (key != null) {
      for (int i = 0; i < this.mouseActions.length; i++) {
        action = this.mouseActions[i];
        if (action['mouse'] == mouse && action['key'] == null) {
          return action['operation'];
        }
      }
    }

    return null;
  }

  /// *
	/// * Get the operation associated to mouse and key combination and returns the corresponding FSA state
	/// * @param {Number} mouse Mouse button
	/// * @param {String} key Keyboard modifier
	/// * @returns The FSA state obtained from the operation associated to mouse/keyboard combination
	/// *
  int? getOpStateFromAction(int mouse, String? key) {
    Map<String,dynamic> action;

    for (int i = 0; i < this.mouseActions.length; i++) {
      action = this.mouseActions[i];
      if (action['mouse'] == mouse && action['key'] == key) {
        return action['state'];
      }
    }

    if (key != null) {
      for (int i = 0; i < this.mouseActions.length; i++) {
        action = this.mouseActions[i];
        if (action['mouse'] == mouse && action['key'] == null) {
          return action['state'];
        }
      }
    }

    return null;
  }

  /// *
	/// * Calculate the angle between two pointers
	/// * @param {PointerEvent} p1
	/// * @param {PointerEvent} p2
	/// * @returns {Number} The angle between two pointers in degrees
	/// *
  num getAngle(p1, p2) {
    return Math.atan2(p2.clientY - p1.clientY, p2.clientX - p1.clientX) *180 /Math.pi;
  }

  /// *
	/// * Update a PointerEvent inside current pointerevents array
	/// * @param {PointerEvent} event
	/// *
  void updateTouchEvent(event) {
    for (int i = 0; i < this._touchCurrent.length; i++) {
      if (this._touchCurrent[i].pointerId == event.pointerId) {
        this._touchCurrent.splice(i, 1, event);
        break;
      }
    }
  }

  /// *
	/// * Apply a transformation matrix, to the camera and gizmos
	/// * @param {Object} transformation Object containing matrices to apply to camera and gizmos
	/// */
  void applyTransformMatrix(Map<String, Matrix4>? transformation) {
    if (transformation?['camera'] != null) {
      this._m4_1.copy(this._cameraMatrixState)
          .premultiply(transformation!['camera']!);
      this._m4_1.decompose(
          this.camera.position, this.camera.quaternion, this.camera.scale);
      this.camera.updateMatrix();

      //update camera up vector
      if (
        this._state == State2.rotate ||
        this._state == State2.zRotate ||
        this._state == State2.animationRotate
      ){
        this.camera.up.copy(this._upState).applyQuaternion(this.camera.quaternion);
      }
    }

    if (transformation?['gizmos'] != null) {
      this._m4_1
          .copy(this._gizmoMatrixState)
          .premultiply(transformation!['gizmos']!);
      this._m4_1.decompose(
          this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);
      this._gizmos.updateMatrix();
    }

    if (this._state == State2.scale ||
        this._state == State2.focus ||
        this._state == State2.animationFocus) {
      this._tbRadius = this.calculateTbRadius(this.camera);

      if (this.adjustNearFar) {
        final cameraDistance =
            this.camera.position.distanceTo(this._gizmos.position);

        final bb = Box3();
        bb.setFromObject(this._gizmos);
        final sphere = Sphere();
        bb.getBoundingSphere(sphere);

        final adjustedNearPosition =
            Math.max(this._nearPos0, sphere.radius + sphere.center.length());
        final regularNearPosition = cameraDistance - this._initialNear;

        final minNearPos = Math.min(adjustedNearPosition, regularNearPosition);
        this.camera.near = cameraDistance - minNearPos;

        final adjustedFarPosition =
            Math.min(this._farPos0, -sphere.radius + sphere.center.length());
        final regularFarPosition = cameraDistance - this._initialFar;

        final minFarPos = Math.min(adjustedFarPosition, regularFarPosition);
        this.camera.far = cameraDistance - minFarPos;

        this.camera.updateProjectionMatrix();
      } 
      else {
        bool update = false;

        if (this.camera.near != this._initialNear) {
          this.camera.near = this._initialNear;
          update = true;
        }

        if (this.camera.far != this._initialFar) {
          this.camera.far = this._initialFar;
          update = true;
        }

        if (update) {
          this.camera.updateProjectionMatrix();
        }
      }
    }
  }

  /// *
	/// * Calculate the angular speed
	/// * @param {Number} p0 Position at t0
	/// * @param {Number} p1 Position at t1
	/// * @param {Number} t0 Initial time in milliseconds
	/// * @param {Number} t1 Ending time in milliseconds
	/// *
  num calculateAngularSpeed(p0, p1, t0, t1) {
    final s = p1 - p0;
    final t = (t1 - t0) / 1000;
    if (t == 0) {
      return 0;
    }

    return s / t;
  }

  /// *
	/// * Calculate the distance between two pointers
	/// * @param {PointerEvent} p0 The first pointer
	/// * @param {PointerEvent} p1 The second pointer
	/// * @returns {number} The distance between the two pointers
	/// *
  double calculatePointersDistance(p0, p1) {
    return Math.sqrt(Math.pow(p1.clientX - p0.clientX, 2) +
        Math.pow(p1.clientY - p0.clientY, 2));
  }

  /// *
	/// * Calculate the rotation axis as the vector perpendicular between two vectors
	/// * @param {Vector3} vec1 The first vector
	/// * @param {Vector3} vec2 The second vector
	/// * @returns {Vector3} The normalized rotation axis
	/// *
  Vector3 calculateRotationAxis(Vector3 vec1, Vector3 vec2) {
    this._rotationMatrix.extractRotation(this._cameraMatrixState);
    this._quat.setFromRotationMatrix(this._rotationMatrix);

    this._rotationAxis.crossVectors(vec1, vec2).applyQuaternion(this._quat);
    return this._rotationAxis.normalize().clone();
  }

  /// *
	/// * Calculate the trackball radius so that gizmo's diamater will be 2/3 of the minimum side of the camera frustum
	/// * @param {Camera} camera
	/// * @returns {Number} The trackball radius
	/// *
  num calculateTbRadius(Camera camera) {
    final distance = camera.position.distanceTo(this._gizmos.position);

    if (camera is PerspectiveCamera) {
      final halfFovV = MathUtils.deg2rad * camera.fov * 0.5; //vertical fov/2 in radians
      final halfFovH = Math.atan((camera.aspect) * Math.tan(halfFovV)); //horizontal fov/2 in radians
      return Math.tan(Math.min(halfFovV, halfFovH)) *distance *this.radiusFactor;
    } 
    else if (camera is OrthographicCamera) {
      return Math.min(camera.top, camera.right) * this.radiusFactor;
    }

    return 0;
  }

  /// *
	/// * Focus operation consist of positioning the point of interest in front of the camera and a slightly zoom in
	/// * @param {Vector3} point The point of interest
	/// * @param {Number} size Scale factor
	/// * @param {Number} amount Amount of operation to be completed (used for focus animations, default is complete full operation)
	/// *
  void focus(point, size, [num amount = 1]) {
    //move center of camera (along with gizmos) towards point of interest
    _offset.copy(point).sub(this._gizmos.position).multiplyScalar(amount);
    this._translationMatrix.makeTranslation(_offset.x, _offset.y, _offset.z);

    _gizmoMatrixStateTemp.copy(this._gizmoMatrixState);
    this._gizmoMatrixState.premultiply(this._translationMatrix);
    this._gizmoMatrixState.decompose(
        this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);

    _cameraMatrixStateTemp.copy(this._cameraMatrixState);
    this._cameraMatrixState.premultiply(this._translationMatrix);
    this._cameraMatrixState.decompose(
        this.camera.position, this.camera.quaternion, this.camera.scale);

    //apply zoom
    if (this.enableZoom) {
      this.applyTransformMatrix(this.scale(size, this._gizmos.position));
    }

    this._gizmoMatrixState.copy(_gizmoMatrixStateTemp);
    this._cameraMatrixState.copy(_cameraMatrixStateTemp);
  }

	/// Draw a grid and add it to the scene
	/// 
  void drawGrid() {
    if (this.scene != null) {
      final color = 0x888888;
      final multiplier = 3;
      num? size;
      num? divisions;
      num maxLength;
      num tick;

      if (this.camera is OrthographicCamera) {
        final width = this.camera.right - this.camera.left;
        final height = this.camera.bottom - this.camera.top;

        maxLength = Math.max(width, height);
        tick = maxLength / 20;

        size = maxLength / this.camera.zoom * multiplier;
        divisions = size / tick * this.camera.zoom;
      } 
      else if (this.camera is PerspectiveCamera) {
        final distance = this.camera.position.distanceTo(this._gizmos.position);
        final halfFovV = MathUtils.deg2rad * this.camera.fov * 0.5;
        final halfFovH = Math.atan((this.camera.aspect) * Math.tan(halfFovV));

        maxLength = Math.tan(Math.max(halfFovV, halfFovH)) * distance * 2;
        tick = maxLength / 20;

        size = maxLength * multiplier;
        divisions = size / tick;
      }

      if (this._grid == null && size != null && divisions != null) {
        this._grid = GridHelper(size, divisions.toInt(), color, color);
        this._grid!.position.copy(this._gizmos.position);
        this._gridPosition.copy(this._grid!.position);
        this._grid!.quaternion.copy(this.camera.quaternion);
        this._grid!.rotateX(Math.pi * 0.5);

        this.scene!.add(this._grid);
      }
    }
  }

	/// Remove all listeners, stop animations and clean scene
	///
  void dispose() {
    if (this._animationId != -1) {
      cancelAnimationFrame(this._animationId);
    }

    this.domElement.removeEventListener('pointerdown', this.onPointerDown);
    this.domElement.removeEventListener('pointercancel', this.onPointerCancel);
    this.domElement.removeEventListener('wheel', this.onWheel);
    this.domElement.removeEventListener('contextmenu', this.onContextMenu);

    domElement.removeEventListener('pointermove', this.onPointerMove);
    domElement.removeEventListener('pointerup', this.onPointerUp);

    domElement.removeEventListener('resize', this.onWindowResize);

    if (this.scene != null) this.scene!.remove(this._gizmos);
    this.disposeGrid();
  }
	/// remove the grid from the scene
	///
  void disposeGrid() {
    if (this._grid != null && this.scene != null) {
      this.scene!.remove(this._grid!);
      this._grid = null;
    }
  }

  /// *
	/// * Compute the easing out cubic function for ease out effect in animation
	/// * @param {Number} t The absolute progress of the animation in the bound of 0 (beginning of the) and 1 (ending of animation)
	/// * @returns {Number} Result of easing out cubic at time t
	/// *
  num easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  }

  /// *
	/// * Make rotation gizmos more or less visible
	/// * @param {Boolean} isActive If true, make gizmos more visible
	/// *
  void activateGizmos(isActive) {
    final gizmoX = this._gizmos.children[0];
    final gizmoY = this._gizmos.children[1];
    final gizmoZ = this._gizmos.children[2];

    if (isActive) {
      gizmoX.material.setValues({'opacity': 1});
      gizmoY.material.setValues({'opacity': 1});
      gizmoZ.material.setValues({'opacity': 1});
    } else {
      gizmoX.material.setValues({'opacity': 0.6});
      gizmoY.material.setValues({'opacity': 0.6});
      gizmoZ.material.setValues({'opacity': 0.6});
    }
  }

  /// *
	/// * Calculate the cursor position in NDC
	/// * @param {number} x Cursor horizontal coordinate within the canvas
	/// * @param {number} y Cursor vertical coordinate within the canvas
	/// * @param {HTMLElement} canvas The canvas where the renderer draws its output
	/// * @returns {Vector2} Cursor normalized position inside the canvas
	/// *
  Vector2 getCursorNDC(double cursorX, double cursorY) {
    // final canvasRect = canvas.getBoundingClientRect();

    final box = listenableKey.currentContext!.findRenderObject() as RenderBox;
    final canvasRect = box.size;
    final local = box.globalToLocal(Offset(0, 0));

    this._v2_1.setX(((cursorX - local.dx) / canvasRect.width) * 2 - 1);
    this._v2_1.setY((((local.dy + canvasRect.height) - cursorY) / canvasRect.height) * 2 - 1);
    return this._v2_1.clone();
  }

  /// *
	/// * Calculate the cursor position inside the canvas x/y coordinates with the origin being in the center of the canvas
	/// * @param {Number} x Cursor horizontal coordinate within the canvas
	/// * @param {Number} y Cursor vertical coordinate within the canvas
	/// * @param {HTMLElement} canvas The canvas where the renderer draws its output
	/// * @returns {Vector2} Cursor position inside the canvas
	/// *
  Vector2 getCursorPosition(double cursorX, double cursorY) {
    this._v2_1.copy(this.getCursorNDC(cursorX, cursorY));
    this._v2_1.x *= (this.camera.right - this.camera.left) * 0.5;
    this._v2_1.y *= (this.camera.top - this.camera.bottom) * 0.5;
    return this._v2_1.clone();
  }

  /// *
	/// * Set the camera to be controlled
	/// * @param {Camera} camera The virtual camera to be controlled
	/// *
  void setCamera(camera) {
    camera.lookAt(this.target);
    camera.updateMatrix();

    //setting state
    if (camera.type == 'PerspectiveCamera') {
      this._fov0 = camera.fov;
      this._fovState = camera.fov;
    }

    this._cameraMatrixState0.copy(camera.matrix);
    this._cameraMatrixState.copy(this._cameraMatrixState0);
    this._cameraProjectionState.copy(camera.projectionMatrix);
    this._zoom0 = camera.zoom;
    this._zoomState = this._zoom0;

    this._initialNear = camera.near;
    this._nearPos0 = camera.position.distanceTo(this.target) - camera.near;
    this._nearPos = this._initialNear;

    this._initialFar = camera.far;
    this._farPos0 = camera.position.distanceTo(this.target) - camera.far;
    this._farPos = this._initialFar;

    this._up0.copy(camera.up);
    this._upState.copy(camera.up);

    this.camera = camera;
    this.camera.updateProjectionMatrix();

    //making gizmos
    this._tbRadius = this.calculateTbRadius(camera);
    this.makeGizmos(this.target, this._tbRadius);
  }

  /// *
	/// * Set gizmos visibility
	/// * @param {Boolean} value Value of gizmos visibility
	/// *
  void setGizmosVisible(value) {
    this._gizmos.visible = value;
    this.dispatchEvent(_changeEvent);
  }

  /// *
	/// * Set gizmos radius factor and redraws gizmos
	/// * @param {Float} value Value of radius factor
	/// *
  void setTbRadius(value) {
    this.radiusFactor = value;
    this._tbRadius = this.calculateTbRadius(this.camera);

    final curve = EllipseCurve(0, 0, this._tbRadius, this._tbRadius);
    final points = curve.getPoints(this._curvePts);
    final curveGeometry = BufferGeometry().setFromPoints(points);

    for (final gizmo in this._gizmos.children) {
      // this._gizmos.children[ gizmo ].geometry = curveGeometry;
      gizmo.geometry = curveGeometry;
    }

    this.dispatchEvent(_changeEvent);
  }

  /// *
	/// * Creates the rotation gizmos matching trackball center and radius
	/// * @param {Vector3} tbCenter The trackball center
	/// * @param {number} tbRadius The trackball radius
	/// *
  void makeGizmos(tbCenter, tbRadius) {
    final curve = EllipseCurve(0, 0, tbRadius, tbRadius);
    final points = curve.getPoints(this._curvePts);

    //geometry
    final curveGeometry = BufferGeometry().setFromPoints(points);

    //material
    final curveMaterialX = LineBasicMaterial(
        {'color': 0xff8080, 'fog': false, 'transparent': true, 'opacity': 0.6});
    final curveMaterialY = LineBasicMaterial(
        {'color': 0x80ff80, 'fog': false, 'transparent': true, 'opacity': 0.6});
    final curveMaterialZ = LineBasicMaterial(
        {'color': 0x8080ff, 'fog': false, 'transparent': true, 'opacity': 0.6});

    //line
    final gizmoX = Line(curveGeometry, curveMaterialX);
    final gizmoY = Line(curveGeometry, curveMaterialY);
    final gizmoZ = Line(curveGeometry, curveMaterialZ);

    final rotation = Math.pi * 0.5;
    gizmoX.rotation.x = rotation;
    gizmoY.rotation.y = rotation;

    //setting state
    this
        ._gizmoMatrixState0
        .identity()
        .setPosition(tbCenter.x, tbCenter.y, tbCenter.z);
    this._gizmoMatrixState.copy(this._gizmoMatrixState0);

    if (this.camera.zoom != 1) {
      //adapt gizmos size to camera zoom
      final size = 1 / this.camera.zoom;
      this._scaleMatrix.makeScale(size, size, size);
      this
          ._translationMatrix
          .makeTranslation(-tbCenter.x, -tbCenter.y, -tbCenter.z);

      this
          ._gizmoMatrixState
          .premultiply(this._translationMatrix)
          .premultiply(this._scaleMatrix);
      this
          ._translationMatrix
          .makeTranslation(tbCenter.x, tbCenter.y, tbCenter.z);
      this._gizmoMatrixState.premultiply(this._translationMatrix);
    }

    this._gizmoMatrixState.decompose(
        this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);

    this._gizmos.clear();

    this._gizmos.add(gizmoX);
    this._gizmos.add(gizmoY);
    this._gizmos.add(gizmoZ);
  }

  /// *
	/// * Perform animation for focus operation
	/// * @param {Number} time Instant in which this function is called as performance.now()
	/// * @param {Vector3} point Point of interest for focus operation
	/// * @param {Matrix4} cameraMatrix Camera matrix
	/// * @param {Matrix4} gizmoMatrix Gizmos matrix
	/// *
  void onFocusAnim(time, point, cameraMatrix, gizmoMatrix) {
    if (this._timeStart == -1) {
      //animation start
      this._timeStart = time;
    }

    if (this._state == State2.animationFocus) {
      final deltaTime = time - this._timeStart;
      final animTime = deltaTime / this.focusAnimationTime;

      this._gizmoMatrixState.copy(gizmoMatrix);

      if (animTime >= 1) {
        //animation end

        this._gizmoMatrixState.decompose(
            this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);

        this.focus(point, this.scaleFactor);

        this._timeStart = -1;
        this.updateTbState(State2.idle, false);
        this.activateGizmos(false);

        this.dispatchEvent(_changeEvent);
      } 
      else {
        num amount = this.easeOutCubic(animTime);
        final size = ((1 - amount) + (this.scaleFactor * amount));

        this._gizmoMatrixState.decompose(
            this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);
        this.focus(point, size, amount);

        this.dispatchEvent(_changeEvent);
        final self = this;
        this._animationId = requestAnimationFrame((t) {
          self.onFocusAnim(t, point, cameraMatrix, gizmoMatrix.clone());
        });
      }
    } else {
      //interrupt animation

      this._animationId = -1;
      this._timeStart = -1;
    }
  }

  /// *
	/// * Perform animation for rotation operation
	/// * @param {Number} time Instant in which this function is called as performance.now()
	/// * @param {Vector3} rotationAxis Rotation axis
	/// * @param {number} w0 Initial angular velocity
	/// *
  void onRotationAnim(time, rotationAxis, w0) {
    if (this._timeStart == -1) {
      //animation start
      this._anglePrev = 0;
      this._angleCurrent = 0;
      this._timeStart = time;
    }

    if (this._state == State2.animationRotate) {
      //w = w0 + alpha * t
      final deltaTime = (time - this._timeStart) / 1000;
      final w = w0 + ((-this.dampingFactor) * deltaTime);

      if (w > 0) {
        //tetha = 0.5 * alpha * t^2 + w0 * t + tetha0
        this._angleCurrent =
            0.5 * (-this.dampingFactor) * Math.pow(deltaTime, 2) +
                w0 * deltaTime +
                0;
        this.applyTransformMatrix(this.rotate(rotationAxis, this._angleCurrent));
        this.dispatchEvent(_changeEvent);
        final self = this;
        this._animationId = requestAnimationFrame((t) {
          self.onRotationAnim(t, rotationAxis, w0);
        });
      } else {
        this._animationId = -1;
        this._timeStart = -1;

        this.updateTbState(State2.idle, false);
        this.activateGizmos(false);

        this.dispatchEvent(_changeEvent);
      }
    } else {
      //interrupt animation

      this._animationId = -1;
      this._timeStart = -1;

      if (this._state != State2.rotate) {
        this.activateGizmos(false);
        this.dispatchEvent(_changeEvent);
      }
    }
  }

  /// *
	/// * Perform pan operation moving camera between two points
	/// * @param {Vector3} p0 Initial point
	/// * @param {Vector3} p1 Ending point
	/// * @param {Boolean} adjust If movement should be adjusted considering camera distance (Perspective only)
	/// *
  Map<String, Matrix4> pan(Vector3 p0, Vector3 p1, [bool adjust = false]) {
    final movement = p0.clone().sub(p1);

    if (this.camera is OrthographicCamera) {
      //adjust movement amount
      movement.multiplyScalar(1 / this.camera.zoom);
    } 
    else if (this.camera is PerspectiveCamera && adjust) {
      //adjust movement amount
      this._v3_1.setFromMatrixPosition(
          this._cameraMatrixState0); //camera's initial position
      this._v3_2.setFromMatrixPosition(
          this._gizmoMatrixState0); //gizmo's initial position
      final distanceFactor = this._v3_1.distanceTo(this._v3_2) /
          this.camera.position.distanceTo(this._gizmos.position);
      movement.multiplyScalar(1 / distanceFactor);
    }

    this._v3_1
        .set(movement.x, movement.y, 0)
        .applyQuaternion(this.camera.quaternion);

    this._m4_1.makeTranslation(this._v3_1.x, this._v3_1.y, this._v3_1.z);

    this.setTransformationMatrices(this._m4_1, this._m4_1);
    return _transformation;
  }

	/// Reset trackball
	///
  void reset() {
    this.camera.zoom = this._zoom0;

    if (this.camera is PerspectiveCamera) {
      this.camera.fov = this._fov0;
    }

    this.camera.near = this._nearPos;
    this.camera.far = this._farPos;
    this._cameraMatrixState.copy(this._cameraMatrixState0);
    this._cameraMatrixState.decompose(
        this.camera.position, this.camera.quaternion, this.camera.scale);
    this.camera.up.copy(this._up0);

    this.camera.updateMatrix();
    this.camera.updateProjectionMatrix();

    this._gizmoMatrixState.copy(this._gizmoMatrixState0);
    this._gizmoMatrixState0.decompose(
        this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale);
    this._gizmos.updateMatrix();

    this._tbRadius = this.calculateTbRadius(this.camera);
    this.makeGizmos(this._gizmos.position, this._tbRadius);

    this.camera.lookAt(this._gizmos.position);

    this.updateTbState(State2.idle, false);

    this.dispatchEvent(_changeEvent);
  }

  /// *
	/// * Rotate the camera around an axis passing by trackball's center
	/// * @param {Vector3} axis Rotation axis
	/// * @param {number} angle Angle in radians
	/// * @returns {Object} Object with 'camera' field containing transformation matrix resulting from the operation to be applied to the camera
	/// *
  Map<String, Matrix4> rotate(Vector3 axis, num angle) {
    final point = this._gizmos.position; //rotation center
    this._translationMatrix.makeTranslation(-point.x, -point.y, -point.z);
    this._rotationMatrix.makeRotationAxis(axis, -angle);

    //rotate camera
    this._m4_1.makeTranslation(point.x, point.y, point.z);
    this._m4_1.multiply(this._rotationMatrix);
    this._m4_1.multiply(this._translationMatrix);

    this.setTransformationMatrices(this._m4_1);

    return _transformation;
  }

  void copyState() {
    // final state;
    // if ( this.camera is OrthographicCamera ) {

    // 	state = JSON.stringify( { 'arcballState': {

    // 		'cameraFar': this.camera.far,
    // 		'cameraMatrix': this.camera.matrix,
    // 		'cameraNear': this.camera.near,
    // 		'cameraUp': this.camera.up,
    // 		'cameraZoom': this.camera.zoom,
    // 		'gizmoMatrix': this._gizmos.matrix

    // 	} } );

    // } else if ( this.camera is PerspectiveCamera ) {

    // 	state = JSON.stringify( { 'arcballState': {
    // 		'cameraFar': this.camera.far,
    // 		'cameraFov': this.camera.fov,
    // 		'cameraMatrix': this.camera.matrix,
    // 		'cameraNear': this.camera.near,
    // 		'cameraUp': this.camera.up,
    // 		'cameraZoom': this.camera.zoom,
    // 		'gizmoMatrix': this._gizmos.matrix

    // 	} } );

    // }

    // navigator.clipboard.writeText( state );
  }

  void pasteState() {
    // final self = this;
    // navigator.clipboard.readText().then( function resolved( value ) {

    // 	self.setStateFromJSON( value );

    // } );
  }

	/// Save the current state of the control. This can later be recover with .reset
	///
  void saveState() {
    this._cameraMatrixState0.copy(this.camera.matrix);
    this._gizmoMatrixState0.copy(this._gizmos.matrix);
    this._nearPos = this.camera.near;
    this._farPos = this.camera.far;
    this._zoom0 = this.camera.zoom;
    this._up0.copy(this.camera.up);

    if (this.camera is PerspectiveCamera) {
      this._fov0 = this.camera.fov;
    }
  }

  /// *
	/// * Perform uniform scale operation around a given point
	/// * @param {Number} size Scale factor
	/// * @param {Vector3} point Point around which scale
	/// * @param {Boolean} scaleGizmos If gizmos should be scaled (Perspective only)
	/// * @returns {Object} Object with 'camera' and 'gizmo' fields containing transformation matrices resulting from the operation to be applied to the camera and gizmos
	/// *
  Map<String, Matrix4>? scale(num size, Vector? point, [bool scaleGizmos = true]) {
    _scalePointTemp.copy(point ?? Vector3());
    num sizeInverse = 1 / size;

    if (this.camera is OrthographicCamera) {
      //camera zoom
      this.camera.zoom = this._zoomState;
      this.camera.zoom *= size;

      //check min and max zoom
      if (this.camera.zoom > this.maxZoom) {
        this.camera.zoom = this.maxZoom;
        sizeInverse = this._zoomState / this.maxZoom;
      } 
      else if (this.camera.zoom < this.minZoom) {
        this.camera.zoom = this.minZoom;
        sizeInverse = this._zoomState / this.minZoom;
      }

      this.camera.updateProjectionMatrix();

      this._v3_1
          .setFromMatrixPosition(this._gizmoMatrixState); //gizmos position

      //scale gizmos so they appear in the same spot having the same dimension
      this._scaleMatrix.makeScale(sizeInverse, sizeInverse, sizeInverse);
      this._translationMatrix
          .makeTranslation(-this._v3_1.x, -this._v3_1.y, -this._v3_1.z);

      this._m4_2
          .makeTranslation(this._v3_1.x, this._v3_1.y, this._v3_1.z)
          .multiply(this._scaleMatrix);
      this._m4_2.multiply(this._translationMatrix);

      //move camera and gizmos to obtain pinch effect
      _scalePointTemp.sub(this._v3_1);

      final amount = _scalePointTemp.clone().multiplyScalar(sizeInverse);
      _scalePointTemp.sub(amount);

      this._m4_1.makeTranslation(
          _scalePointTemp.x, _scalePointTemp.y, _scalePointTemp.z);
      this._m4_2.premultiply(this._m4_1);

      this.setTransformationMatrices(this._m4_1, this._m4_2);
      return _transformation;
    } 
    else if (this.camera is PerspectiveCamera) {
      this._v3_1.setFromMatrixPosition(this._cameraMatrixState);
      this._v3_2.setFromMatrixPosition(this._gizmoMatrixState);

      //move camera
      num distance = this._v3_1.distanceTo(_scalePointTemp);
      num amount = distance - (distance * sizeInverse);

      //check min and max distance
      final newDistance = distance - amount;
      if (newDistance < this.minDistance) {
        sizeInverse = this.minDistance / distance;
        amount = distance - (distance * sizeInverse);
      } else if (newDistance > this.maxDistance) {
        sizeInverse = this.maxDistance / distance;
        amount = distance - (distance * sizeInverse);
      }

      _offset
          .copy(_scalePointTemp)
          .sub(this._v3_1)
          .normalize()
          .multiplyScalar(amount);

      this._m4_1.makeTranslation(_offset.x, _offset.y, _offset.z);

      if (scaleGizmos) {
        //scale gizmos so they appear in the same spot having the same dimension
        final pos = this._v3_2;

        distance = pos.distanceTo(_scalePointTemp);
        amount = distance - (distance * sizeInverse);
        _offset
            .copy(_scalePointTemp)
            .sub(this._v3_2)
            .normalize()
            .multiplyScalar(amount);

        this._translationMatrix.makeTranslation(pos.x, pos.y, pos.z);
        this._scaleMatrix.makeScale(sizeInverse, sizeInverse, sizeInverse);

        this._m4_2
            .makeTranslation(_offset.x, _offset.y, _offset.z)
            .multiply(this._translationMatrix);
        this._m4_2.multiply(this._scaleMatrix);

        this._translationMatrix.makeTranslation(-pos.x, -pos.y, -pos.z);

        this._m4_2.multiply(this._translationMatrix);
        this.setTransformationMatrices(this._m4_1, this._m4_2);
      } else {
        this.setTransformationMatrices(this._m4_1);
      }

      return _transformation;
    }

    return null;
  }

  /// *
	/// * Set camera fov
	/// * @param {Number} value fov to be setted
	/// *
  void setFov(double value) {
    if (this.camera is PerspectiveCamera) {
      this.camera.fov = MathUtils.clamp(value, this.minFov, this.maxFov);
      this.camera.updateProjectionMatrix();
    }
  }

  /// *
	/// * Set values in transformation object
	/// * @param {Matrix4} camera Transformation to be applied to the camera
	/// * @param {Matrix4} gizmos Transformation to be applied to gizmos
	/// *
  void setTransformationMatrices([Matrix4? camera, Matrix4? gizmos]) {
    if (camera != null) {
      if (_transformation['camera'] != null) {
        _transformation['camera']!.copy(camera);
      } 
      else {
        _transformation['camera'] = camera.clone();
      }
    } 
    else {
      _transformation.remove('camera');
    }

    if (gizmos != null) {
      if (_transformation['gizmos'] != null) {
        _transformation['gizmos']!.copy(gizmos);
      } 
      else {
        _transformation['gizmos'] = gizmos.clone();
      }
    } 
    else {
      _transformation.remove('gizmos');
    }
  }

  /// *
	/// * Rotate camera around its direction axis passing by a given point by a given angle
	/// * @param {Vector3} point The point where the rotation axis is passing trough
	/// * @param {Number} angle Angle in radians
	/// * @returns The computed transormation matix
	/// *
  Map<String, Matrix4> zRotate(Vector3 point, num angle) {
    this._rotationMatrix.makeRotationAxis(this._rotationAxis, angle);
    this._translationMatrix.makeTranslation(-point.x, -point.y, -point.z);

    this._m4_1.makeTranslation(point.x, point.y, point.z);
    this._m4_1.multiply(this._rotationMatrix);
    this._m4_1.multiply(this._translationMatrix);

    this._v3_1
        .setFromMatrixPosition(this._gizmoMatrixState)
        .sub(point); //vector from rotation center to gizmos position
    this._v3_2
        .copy(this._v3_1)
        .applyAxisAngle(this._rotationAxis, angle); //apply rotation
    this._v3_2.sub(this._v3_1);

    this._m4_2.makeTranslation(this._v3_2.x, this._v3_2.y, this._v3_2.z);

    this.setTransformationMatrices(this._m4_1, this._m4_2);
    return _transformation;
  }

  Raycaster getRaycaster() {
    return _raycaster;
  }

  /// *
	/// * Unproject the cursor on the 3D object surface
	/// * @param {Vector2} cursor Cursor coordinates in NDC
	/// * @param {Camera} camera Virtual camera
	/// * @returns {Vector3} The point of intersection with the model, if exist, null otherwise
	/// *
  Vector3? unprojectOnObj(Vector2 cursor, Camera camera) {
    final raycaster = this.getRaycaster();
    raycaster.near = camera.near;
    raycaster.far = camera.far;
    raycaster.setFromCamera(cursor, camera);

    final intersect = raycaster.intersectObjects(this.scene!.children, true);

    for (int i = 0; i < intersect.length; i++) {
      if (intersect[i].object?.uuid != this._gizmos.uuid &&
          intersect[i].face != null) {
        return intersect[i].point?.clone();
      }
    }

    return null;
  }

  /// *
	/// * Unproject the cursor on the trackball surface
	/// * @param {Camera} camera The virtual camera
	/// * @param {Number} cursorX Cursor horizontal coordinate on screen
	/// * @param {Number} cursorY Cursor vertical coordinate on screen
	/// * @param {HTMLElement} canvas The canvas where the renderer draws its output
	/// * @param {number} tbRadius The trackball radius
	/// * @returns {Vector3} The unprojected point on the trackball surface
	/// */
  Vector3 unprojectOnTbSurface(Camera camera, double cursorX, double cursorY, num tbRadius) {
    if (camera is OrthographicCamera) {
      this._v2_1.copy(this.getCursorPosition(cursorX, cursorY));
      this._v3_1.set(this._v2_1.x, this._v2_1.y, 0);

      final x2 = Math.pow(this._v2_1.x, 2);
      final y2 = Math.pow(this._v2_1.y, 2);
      final r2 = Math.pow(this._tbRadius, 2);

      if (x2 + y2 <= r2 * 0.5) {
        //intersection with sphere
        this._v3_1.setZ(Math.sqrt(r2 - (x2 + y2)));
      } else {
        //intersection with hyperboloid
        this._v3_1.setZ((r2 * 0.5) / (Math.sqrt(x2 + y2)));
      }

      return this._v3_1;
    } 
    else if (camera is PerspectiveCamera) {
      //unproject cursor on the near plane
      this._v2_1.copy(this.getCursorNDC(cursorX, cursorY));

      this._v3_1.set(this._v2_1.x, this._v2_1.y, -1);
      this._v3_1.applyMatrix4(camera.projectionMatrixInverse);

      final rayDir = this._v3_1.clone().normalize(); //unprojected ray direction
      final cameraGizmoDistance =
          camera.position.distanceTo(this._gizmos.position);
      final radius2 = Math.pow(tbRadius, 2);

      //	  camera
      //		|\
      //		| \
      //		|  \
      //	h	|	\
      //		| 	 \
      //		| 	  \
      //	_ _ | _ _ _\ _ _  near plane
      //			l

      final h = this._v3_1.z;
      final l = Math.sqrt(Math.pow(this._v3_1.x, 2) + Math.pow(this._v3_1.y, 2));

      if (l == 0) {
        //ray aligned with camera
        rayDir.set(this._v3_1.x, this._v3_1.y, tbRadius);
        return rayDir;
      }

      final m = h / l;
      final q = cameraGizmoDistance;

      /*
			 * calculate intersection point between unprojected ray and trackball surface
			 *|y = m * x + q
			 *|x^2 + y^2 = r^2
			 *
			 * (m^2 + 1) * x^2 + (2 * m * q) * x + q^2 - r^2 = 0
			 */
      num a = Math.pow(m, 2) + 1;
      num b = 2 * m * q;
      num c = Math.pow(q, 2) - radius2;
      num delta = Math.pow(b, 2) - (4 * a * c);

      if (delta >= 0) {
        //intersection with sphere
        this._v2_1.setX((-b - Math.sqrt(delta)) / (2 * a));
        this._v2_1.setY(m * this._v2_1.x + q);

        final angle = MathUtils.rad2deg * this._v2_1.angle();

        if (angle >= 45) {
          //if angle between intersection point and X' axis is >= 45°, return that point
          //otherwise, calculate intersection point with hyperboloid

          final rayLength = Math.sqrt(Math.pow(this._v2_1.x, 2) +
              Math.pow((cameraGizmoDistance - this._v2_1.y), 2));
          rayDir.multiplyScalar(rayLength);
          rayDir.z += cameraGizmoDistance;
          return rayDir;
        }
      }

      //intersection with hyperboloid
      /*
			 *|y = m * x + q
			 *|y = (1 / x) * (r^2 / 2)
			 *
			 * m * x^2 + q * x - r^2 / 2 = 0
			 */

      a = m;
      b = q;
      c = -radius2 * 0.5;
      delta = Math.pow(b, 2) - (4 * a * c);
      this._v2_1.setX((-b - Math.sqrt(delta)) / (2 * a));
      this._v2_1.setY(m * this._v2_1.x + q);

      final rayLength = Math.sqrt(Math.pow(this._v2_1.x, 2) +
          Math.pow((cameraGizmoDistance - this._v2_1.y), 2));

      rayDir.multiplyScalar(rayLength);
      rayDir.z += cameraGizmoDistance;
      return rayDir;
    }

    return Vector3();
  }

  /// *
	/// * Unproject the cursor on the plane passing through the center of the trackball orthogonal to the camera
	/// * @param {Camera} camera The virtual camera
	/// * @param {Number} cursorX Cursor horizontal coordinate on screen
	/// * @param {Number} cursorY Cursor vertical coordinate on screen
	/// * @param {HTMLElement} canvas The canvas where the renderer draws its output
	/// * @param {Boolean} initialDistance If initial distance between camera and gizmos should be used for calculations instead of current (Perspective only)
	/// * @returns {Vector3} The unprojected point on the trackball plane
	/// *
  Vector3 unprojectOnTbPlane(Camera camera, double cursorX, double cursorY,[bool initialDistance = false]) {
    if (camera is OrthographicCamera) {
      this._v2_1.copy(this.getCursorPosition(cursorX, cursorY));
      this._v3_1.set(this._v2_1.x, this._v2_1.y, 0);

      return this._v3_1.clone();
    } 
    else if (camera is PerspectiveCamera) {
      this._v2_1.copy(this.getCursorNDC(cursorX, cursorY));

      //unproject cursor on the near plane
      this._v3_1.set(this._v2_1.x, this._v2_1.y, -1);
      this._v3_1.applyMatrix4(camera.projectionMatrixInverse);

      final rayDir = this._v3_1.clone().normalize(); //unprojected ray direction

      //	  camera
      //		|\
      //		| \
      //		|  \
      //	h	|	\
      //		| 	 \
      //		| 	  \
      //	_ _ | _ _ _\ _ _  near plane
      //			l

      final h = this._v3_1.z;
      final l = Math.sqrt(Math.pow(this._v3_1.x, 2) + Math.pow(this._v3_1.y, 2));
      final cameraGizmoDistance;

      if (initialDistance) {
        cameraGizmoDistance = this
            ._v3_1
            .setFromMatrixPosition(this._cameraMatrixState0)
            .distanceTo(
                this._v3_2.setFromMatrixPosition(this._gizmoMatrixState0));
      } 
      else {
        cameraGizmoDistance = camera.position.distanceTo(this._gizmos.position);
      }

      /*
			 * calculate intersection point between unprojected ray and the plane
			 *|y = mx + q
			 *|y = 0
			 *
			 * x = -q/m
			*/
      if (l == 0) {
        //ray aligned with camera
        rayDir.set(0, 0, 0);
        return rayDir;
      }

      final m = h / l;
      final q = cameraGizmoDistance;
      final x = -q / m;

      final rayLength = Math.sqrt(Math.pow(q, 2) + Math.pow(x, 2));
      rayDir.multiplyScalar(rayLength);
      rayDir.z = 0;
      return rayDir;
    }
    return Vector3();
  }

  
	/// Update camera and gizmos state
  void updateMatrixState() {
    //update camera and gizmos state
    this._cameraMatrixState.copy(this.camera.matrix);
    this._gizmoMatrixState.copy(this._gizmos.matrix);

    if (this.camera is OrthographicCamera) {
      this._cameraProjectionState.copy(this.camera.projectionMatrix);
      this.camera.updateProjectionMatrix();
      this._zoomState = this.camera.zoom;
    } else if (this.camera is PerspectiveCamera) {
      this._fovState = this.camera.fov;
    }
  }

  /// *
	/// * Update the trackball FSA
	/// * @param {State2} newState New state of the FSA
	/// * @param {Boolean} updateMatrices If matriices state should be updated
	/// *
  void updateTbState(newState, bool updateMatrices) {
    this._state = newState;
    if (updateMatrices) {
      this.updateMatrixState();
    }
  }

  void update() {
    final eps = 0.000001;

    if (this.target.equals(this._currentTarget) == false) {
      this._gizmos.position.copy(this.target); //for correct radius calculation
      this._tbRadius = this.calculateTbRadius(this.camera);
      this.makeGizmos(this.target, this._tbRadius);
      this._currentTarget.copy(this.target);
    }

    //check min/max parameters
    if (this.camera is OrthographicCamera) {
      //check zoom
      if (this.camera.zoom > this.maxZoom || this.camera.zoom < this.minZoom) {
        final newZoom =
            MathUtils.clamp(this.camera.zoom, this.minZoom, this.maxZoom);
        this.applyTransformMatrix(this
            .scale(newZoom / this.camera.zoom, this._gizmos.position, true));
      }
    } else if (this.camera is PerspectiveCamera) {
      //check distance
      final distance = this.camera.position.distanceTo(this._gizmos.position);

      if (distance > this.maxDistance + eps ||
          distance < this.minDistance - eps) {
        final newDistance =
            MathUtils.clamp(distance, this.minDistance, this.maxDistance);
        this.applyTransformMatrix(
            this.scale(newDistance / distance, this._gizmos.position));
        this.updateMatrixState();
      }

      //check fov
      if (this.camera.fov < this.minFov || this.camera.fov > this.maxFov) {
        this.camera.fov =
            MathUtils.clamp(this.camera.fov, this.minFov, this.maxFov);
        this.camera.updateProjectionMatrix();
      }

      final oldRadius = this._tbRadius;
      this._tbRadius = this.calculateTbRadius(this.camera);

      if (oldRadius < this._tbRadius - eps || oldRadius > this._tbRadius + eps) {
        final scale = (this._gizmos.scale.x +this._gizmos.scale.y +this._gizmos.scale.z) /3;
        final newRadius = this._tbRadius / scale;
        final curve = EllipseCurve(0, 0, newRadius, newRadius);
        final points = curve.getPoints(this._curvePts);
        final curveGeometry = BufferGeometry().setFromPoints(points);

        for (final gizmo in this._gizmos.children) {
          // this._gizmos.children[ gizmo ].geometry = curveGeometry;
          gizmo.geometry = curveGeometry;
        }
      }
    }

    this.camera.lookAt(this._gizmos.position);
  }

  void setStateFromJSON(Map<String,dynamic> json) {
    // final state = JSON.parse( json );

    // if ( state.arcballState != null ) {

    // 	this._cameraMatrixState.fromArray( state.arcballState.cameraMatrix.elements );
    // 	this._cameraMatrixState.decompose( this.camera.position, this.camera.quaternion, this.camera.scale );

    // 	this.camera.up.copy( state.arcballState.cameraUp );
    // 	this.camera.near = state.arcballState.cameraNear;
    // 	this.camera.far = state.arcballState.cameraFar;

    // 	this.camera.zoom = state.arcballState.cameraZoom;

    // 	if ( this.camera is PerspectiveCamera ) {

    // 		this.camera.fov = state.arcballState.cameraFov;

    // 	}

    // 	this._gizmoMatrixState.fromArray( state.arcballState.gizmoMatrix.elements );
    // 	this._gizmoMatrixState.decompose( this._gizmos.position, this._gizmos.quaternion, this._gizmos.scale );

    // 	this.camera.updateMatrix();
    // 	this.camera.updateProjectionMatrix();

    // 	this._gizmos.updateMatrix();

    // 	this._tbRadius = this.calculateTbRadius( this.camera );
    // 	final gizmoTmp = Matrix4().copy( this._gizmoMatrixState0 );
    // 	this.makeGizmos( this._gizmos.position, this._tbRadius );
    // 	this._gizmoMatrixState0.copy( gizmoTmp );

    // 	this.camera.lookAt( this._gizmos.position );
    // 	this.updateTbState( State2.idle, false );

    // 	this.dispatchEvent( _changeEvent );

    // }
  }

  int cancelAnimationFrame(instance){
    return -1;
  }

  int requestAnimationFrame(Function callback) {
    return -1;
  }
}
