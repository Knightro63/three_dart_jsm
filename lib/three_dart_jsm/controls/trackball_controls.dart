part of jsm_controls;

class TrackballControls with EventDispatcher {
  late TrackballControls scope;
  late Camera object;

  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get domElement => listenableKey.currentState!;

  bool enabled = true;

  Map screen = {'left': 0, 'top': 0, 'width': 0, 'height': 0};

  double rotateSpeed = 1.0;
  double zoomSpeed = 1.2;
  double panSpeed = 0.3;

  bool noRotate = false;
  bool noZoom = false;
  bool noPan = false;

  bool staticMoving = false;
  double dynamicDampingFactor = 0.2;

  double minDistance = 0;
  double maxDistance = Math.infinity;

  List<String> keys = ['KeyA' /*A*/, 'KeyS' /*S*/, 'KeyD' /*D*/];

  Map mouseButtons = {
    'LEFT': Mouse.rotate,
    'MIDDLE': Mouse.dolly,
    'RIGHT': Mouse.pan
  };

  // internals

  Vector3 target = Vector3();

  final eps = 0.000001;

  final lastPosition = Vector3();
  double lastZoom = 1.0;

  int _state = OrbitState.none,
      _keyState = OrbitState.none;
  double _touchZoomDistanceStart = 0.0,
      _touchZoomDistanceEnd = 0.0,
      _lastAngle = 0.0;

  final _eye = Vector3(),
    _movePrev = Vector2(),
    _moveCurr = Vector2(),
    _lastAxis = Vector3(),
    _zoomStart = Vector2(),
    _zoomEnd = Vector2(),
    _panStart = Vector2(),
    _panEnd = Vector2(),
    _pointers = [],
    _pointerPositions = {};

  late Vector3 target0;
  late Vector3 position0;
  late Vector3 up0;
  late double zoom0;

  TrackballControls(this.object, this.listenableKey): super() {
    scope = this;

    this.target0 = this.target.clone();
    this.position0 = this.object.position.clone();
    this.up0 = this.object.up.clone();
    this.zoom0 = this.object.zoom;

    this.domElement.addEventListener('contextmenu', contextmenu);

    this.domElement.addEventListener('pointerdown', onPointerDown);
    this.domElement.addEventListener('pointercancel', onPointerCancel);
    this.domElement.addEventListener('wheel', onMouseWheel);

    this.handleResize();
    this.update();
  }

  // methods

  void handleResize() {
    RenderBox getBox = this.listenableKey.currentContext?.findRenderObject() as RenderBox;
    var size = getBox.size;
    var local = getBox.globalToLocal(Offset(0, 0));

    screen['left'] = local.dx;
    screen['top'] = local.dy;
    screen['width'] = size.width;
    screen['height'] = size.height;
  }

  final vector = Vector2();

  Vector2 getMouseOnScreen(num pageX, num pageY) {
    vector.set((pageX - scope.screen['left']) / scope.screen['width'],
        (pageY - scope.screen['top']) / scope.screen['height']);

    return vector;
  }

  Vector2 getMouseOnCircle(num pageX, num pageY) {
    vector.set(
        ((pageX - scope.screen['width'] * 0.5 - scope.screen['left']) /
            (scope.screen['width'] * 0.5)),
        ((scope.screen['height'] + 2 * (scope.screen['top'] - pageY)) /
            scope.screen['width']) // screen.width intentional
        );

    return vector;
  }

  final axis = Vector3(),
      quaternion = Quaternion(),
      eyeDirection = Vector3(),
      objectUpDirection = Vector3(),
      objectSidewaysDirection = Vector3(),
      moveDirection = Vector3();

  void rotateCamera() {
    moveDirection.set(_moveCurr.x - _movePrev.x, _moveCurr.y - _movePrev.y, 0);
    double angle = moveDirection.length();

    if (angle != 0) {
      _eye.copy(scope.object.position).sub(scope.target);

      eyeDirection.copy(_eye).normalize();
      objectUpDirection.copy(scope.object.up).normalize();
      objectSidewaysDirection
          .crossVectors(objectUpDirection, eyeDirection)
          .normalize();

      objectUpDirection.setLength(_moveCurr.y - _movePrev.y);
      objectSidewaysDirection.setLength(_moveCurr.x - _movePrev.x);

      moveDirection.copy(objectUpDirection.add(objectSidewaysDirection));

      axis.crossVectors(moveDirection, _eye).normalize();

      angle *= scope.rotateSpeed;
      quaternion.setFromAxisAngle(axis, angle);

      _eye.applyQuaternion(quaternion);
      scope.object.up.applyQuaternion(quaternion);

      _lastAxis.copy(axis);
      _lastAngle = angle;
    } else if (!scope.staticMoving && _lastAngle != 0) {
      _lastAngle *= Math.sqrt(1.0 - scope.dynamicDampingFactor);
      _eye.copy(scope.object.position).sub(scope.target);
      quaternion.setFromAxisAngle(_lastAxis, _lastAngle);
      _eye.applyQuaternion(quaternion);
      scope.object.up.applyQuaternion(quaternion);
    }

    _movePrev.copy(_moveCurr);
  }

  void zoomCamera() {
    final factor;

    if (_state == OrbitState.touchZoomPan) {
      factor = _touchZoomDistanceStart / _touchZoomDistanceEnd;
      _touchZoomDistanceStart = _touchZoomDistanceEnd;

      if (scope.object is PerspectiveCamera) {
        _eye.multiplyScalar(factor);
      } else if (scope.object is OrthographicCamera) {
        scope.object.zoom /= factor;
        scope.object.updateProjectionMatrix();
      } else {
        print('THREE.TrackballControls: Unsupported camera type');
      }
    } else {
      factor = 1.0 + (_zoomEnd.y - _zoomStart.y) * scope.zoomSpeed;

      if (factor != 1.0 && factor > 0.0) {
        if (scope.object is PerspectiveCamera) {
          _eye.multiplyScalar(factor);
        } else if (scope.object is OrthographicCamera) {
          scope.object.zoom /= factor;
          scope.object.updateProjectionMatrix();
        } else {
          print('THREE.TrackballControls: Unsupported camera type');
        }
      }

      if (scope.staticMoving) {
        _zoomStart.copy(_zoomEnd);
      } else {
        _zoomStart.y += (_zoomEnd.y - _zoomStart.y) * this.dynamicDampingFactor;
      }
    }
  }

  final mouseChange = Vector2(),
      objectUp = Vector3(),
      pan = Vector3();

  void panCamera() {
    mouseChange.copy(_panEnd).sub(_panStart);

    if (mouseChange.lengthSq() != 0) {
      if (scope.object is OrthographicCamera) {
        final scaleX = (scope.object.right - scope.object.left) /
            scope.object.zoom /
            scope.domElement.clientWidth;
        final scaleY = (scope.object.top - scope.object.bottom) /
            scope.object.zoom /
            scope.domElement.clientWidth;

        mouseChange.x *= scaleX;
        mouseChange.y *= scaleY;
      }

      mouseChange.multiplyScalar(_eye.length() * scope.panSpeed);

      pan.copy(_eye).cross(scope.object.up).setLength(mouseChange.x);
      pan.add(objectUp.copy(scope.object.up).setLength(mouseChange.y));

      scope.object.position.add(pan);
      scope.target.add(pan);

      if (scope.staticMoving) {
        _panStart.copy(_panEnd);
      } else {
        _panStart.add(mouseChange
            .subVectors(_panEnd, _panStart)
            .multiplyScalar(scope.dynamicDampingFactor));
      }
    }
  }

  void checkDistances() {
    if (!scope.noZoom || !scope.noPan) {
      if (_eye.lengthSq() > scope.maxDistance * scope.maxDistance) {
        scope.object.position
            .addVectors(scope.target, _eye.setLength(scope.maxDistance));
        _zoomStart.copy(_zoomEnd);
      }

      if (_eye.lengthSq() < scope.minDistance * scope.minDistance) {
        scope.object.position
            .addVectors(scope.target, _eye.setLength(scope.minDistance));
        _zoomStart.copy(_zoomEnd);
      }
    }
  }

  void update() {
    _eye.subVectors(scope.object.position, scope.target);

    if (!scope.noRotate) {
      scope.rotateCamera();
    }

    if (!scope.noZoom) {
      scope.zoomCamera();
    }

    if (!scope.noPan) {
      scope.panCamera();
    }

    scope.object.position.addVectors(scope.target, _eye);

    if (scope.object is PerspectiveCamera) {
      scope.checkDistances();

      scope.object.lookAt(scope.target);

      if (lastPosition.distanceToSquared(scope.object.position) > eps) {
        scope.dispatchEvent(_changeEvent);

        lastPosition.copy(scope.object.position);
      }
    } else if (scope.object is OrthographicCamera) {
      scope.object.lookAt(scope.target);

      if (lastPosition.distanceToSquared(scope.object.position) > eps ||
          lastZoom != scope.object.zoom) {
        scope.dispatchEvent(_changeEvent);

        lastPosition.copy(scope.object.position);
        lastZoom = scope.object.zoom;
      }
    } else {
      print('THREE.TrackballControls: Unsupported camera type');
    }
  }

  void reset() {
    _state = OrbitState.none;
    _keyState = OrbitState.none;

    scope.target.copy(scope.target0);
    scope.object.position.copy(scope.position0);
    scope.object.up.copy(scope.up0);
    scope.object.zoom = scope.zoom0;

    scope.object.updateProjectionMatrix();

    _eye.subVectors(scope.object.position, scope.target);

    scope.object.lookAt(scope.target);

    scope.dispatchEvent(_changeEvent);

    lastPosition.copy(scope.object.position);
    lastZoom = scope.object.zoom;
  }

  // listeners

  void onPointerDown(event) {
    if (scope.enabled == false) return;

    if (_pointers.length == 0) {
      scope.domElement.setPointerCapture(event.pointerId);

      scope.domElement.addEventListener('pointermove', onPointerMove);
      scope.domElement.addEventListener('pointerup', onPointerUp);
    }

    //

    addPointer(event);

    if (event.pointerType == 'touch') {
      onTouchStart(event);
    } else {
      onMouseDown(event);
    }
  }

  void onPointerMove(event) {
    if (scope.enabled == false) return;

    if (event.pointerType == 'touch') {
      onTouchMove(event);
    } else {
      onMouseMove(event);
    }
  }

  void onPointerUp(event) {
    if (scope.enabled == false) return;

    if (event.pointerType == 'touch') {
      onTouchEnd(event);
    } else {
      onMouseUp();
    }

    //

    removePointer(event);

    if (_pointers.length == 0) {
      scope.domElement.releasePointerCapture(event.pointerId);

      scope.domElement.removeEventListener('pointermove', onPointerMove);
      scope.domElement.removeEventListener('pointerup', onPointerUp);
    }
  }

  void onPointerCancel(event) {
    removePointer(event);
  }

  void keydown(event) {
    if (scope.enabled == false) return;

    if (_keyState != OrbitState.none) {
      return;
    } else if (event.code == scope.keys[OrbitState.rotate] && !scope.noRotate) {
      _keyState = OrbitState.rotate;
    } else if (event.code == scope.keys[OrbitState.zoom] && !scope.noZoom) {
      _keyState = OrbitState.zoom;
    } else if (event.code == scope.keys[OrbitState.pan] && !scope.noPan) {
      _keyState = OrbitState.pan;
    }
  }

  void keyup() {
    if (scope.enabled == false) return;
    _keyState = OrbitState.none;
  }

  void onMouseDown(event) {
    if (_state == OrbitState.none) {
      if (event.button == scope.mouseButtons['LEFT']) {
        _state = OrbitState.rotate;
      } else if (event.button == scope.mouseButtons['MIDDLE']) {
        _state = OrbitState.zoom;
      } else if (event.button == scope.mouseButtons['RIGHT']) {
        _state = OrbitState.pan;
      }
    }

    final state = (_keyState != OrbitState.none) ? _keyState : _state;

    if (state == OrbitState.rotate && !scope.noRotate) {
      _moveCurr.copy(getMouseOnCircle(event.pageX, event.pageY));
      _movePrev.copy(_moveCurr);
    } else if (state == OrbitState.zoom && !scope.noZoom) {
      _zoomStart.copy(getMouseOnScreen(event.pageX, event.pageY));
      _zoomEnd.copy(_zoomStart);
    } else if (state == OrbitState.pan && !scope.noPan) {
      _panStart.copy(getMouseOnScreen(event.pageX, event.pageY));
      _panEnd.copy(_panStart);
    }

    scope.dispatchEvent(_startEvent);
  }

  void onMouseMove(event) {
    final state = (_keyState != OrbitState.none) ? _keyState : _state;

    if (state == OrbitState.rotate && !scope.noRotate) {
      _movePrev.copy(_moveCurr);
      _moveCurr.copy(getMouseOnCircle(event.pageX, event.pageY));
    } else if (state == OrbitState.zoom && !scope.noZoom) {
      _zoomEnd.copy(getMouseOnScreen(event.pageX, event.pageY));
    } else if (state == OrbitState.pan && !scope.noPan) {
      _panEnd.copy(getMouseOnScreen(event.pageX, event.pageY));
    }
  }

  void onMouseUp() {
    _state = OrbitState.none;
    scope.dispatchEvent(_endEvent);
  }

  void onMouseWheel(event) {
    if (scope.enabled == false) return;

    if (scope.noZoom == true) return;

    event.preventDefault();

    switch (event.deltaMode) {
      case 2:
        // Zoom in pages
        _zoomStart.y -= event.deltaY * 0.025;
        break;

      case 1:
        // Zoom in lines
        _zoomStart.y -= event.deltaY * 0.01;
        break;

      default:
        // undefined, 0, assume pixels
        _zoomStart.y -= event.deltaY * 0.00025;
        break;
    }

    scope.dispatchEvent(_startEvent);
    scope.dispatchEvent(_endEvent);
  }

  void onTouchStart(event) {
    trackPointer(event);

    switch (_pointers.length) {
      case 1:
        _state = OrbitState.touchRotate;
        _moveCurr
            .copy(getMouseOnCircle(_pointers[0].pageX, _pointers[0].pageY));
        _movePrev.copy(_moveCurr);
        break;

      default: // 2 or more
        _state = OrbitState.touchZoomPan;
        final dx = _pointers[0].pageX - _pointers[1].pageX;
        final dy = _pointers[0].pageY - _pointers[1].pageY;
        _touchZoomDistanceEnd =
            _touchZoomDistanceStart = Math.sqrt(dx * dx + dy * dy);

        final x = (_pointers[0].pageX + _pointers[1].pageX) / 2;
        final y = (_pointers[0].pageY + _pointers[1].pageY) / 2;
        _panStart.copy(getMouseOnScreen(x, y));
        _panEnd.copy(_panStart);
        break;
    }

    scope.dispatchEvent(_startEvent);
  }

  void onTouchMove(event) {
    trackPointer(event);

    switch (_pointers.length) {
      case 1:
        _movePrev.copy(_moveCurr);
        _moveCurr.copy(getMouseOnCircle(event.pageX, event.pageY));
        break;

      default: // 2 or more

        final position = getSecondPointerPosition(event);

        final dx = event.pageX - position.x;
        final dy = event.pageY - position.y;
        _touchZoomDistanceEnd = Math.sqrt(dx * dx + dy * dy);

        final x = (event.pageX + position.x) / 2;
        final y = (event.pageY + position.y) / 2;
        _panEnd.copy(getMouseOnScreen(x, y));
        break;
    }
  }

  void onTouchEnd(event) {
    switch (_pointers.length) {
      case 0:
        _state = OrbitState.none;
        break;

      case 1:
        _state = OrbitState.touchRotate;
        _moveCurr.copy(getMouseOnCircle(event.pageX, event.pageY));
        _movePrev.copy(_moveCurr);
        break;

      case 2:
        _state = OrbitState.touchZoomPan;
        _moveCurr.copy(getMouseOnCircle(
            event.pageX - _movePrev.x, event.pageY - _movePrev.y));
        _movePrev.copy(_moveCurr);
        break;
    }

    scope.dispatchEvent(_endEvent);
  }

  void contextmenu(event) {
    if (scope.enabled == false) return;
    event.preventDefault();
  }

  void addPointer(event) {
    _pointers.add(event);
  }

  void removePointer(event) {
    _pointerPositions.remove(event.pointerId);

    for (int i = 0; i < _pointers.length; i++) {
      if (_pointers[i].pointerId == event.pointerId) {
        _pointers.splice(i, 1);
        return;
      }
    }
  }

  void trackPointer(event) {
    Vector2? position = _pointerPositions[event.pointerId];

    if (position == null) {
      position = Vector2();
      _pointerPositions[event.pointerId] = position;
    }

    position.set(event.pageX, event.pageY);
  }

  Vector2 getSecondPointerPosition(event) {
    final pointer = (event.pointerId == _pointers[0].pointerId)
        ? _pointers[1]
        : _pointers[0];

    return _pointerPositions[pointer.pointerId];
  }

  void dispose() {
    scope.domElement.removeEventListener('contextmenu', contextmenu);

    scope.domElement.removeEventListener('pointerdown', onPointerDown);
    scope.domElement.removeEventListener('pointercancel', onPointerCancel);
    scope.domElement.removeEventListener('wheel', onMouseWheel);

    scope.domElement.removeEventListener('pointermove', onPointerMove);
    scope.domElement.removeEventListener('pointerup', onPointerUp);
  }
}
