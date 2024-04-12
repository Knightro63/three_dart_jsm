part of jsm_controls;

final _tempVector = Vector3();
final _tempVector2 = Vector3();
final _tempQuaternion = Quaternion();
final _unit = {
  "X": Vector3(1, 0, 0),
  "Y": Vector3(0, 1, 0),
  "Z": Vector3(0, 0, 1)
};

final _mouseDownEvent = Event(type: 'mouseDown');
final _mouseUpEvent = Event(type: 'mouseUp', mode: null);
final _objectChangeEvent = Event(type: 'objectChange');

Pointer? _pointer0;

class TransformControls extends Object3D {
  bool isTransformControls = true;

  late dynamic domKey;
  dynamic domElement;

  late TransformControlsGizmo _gizmo;
  late TransformControlsPlane _plane;

  dynamic scope;

  Camera? _camera;
  Camera? get camera => _camera;

  set camera(Camera? value) {
    if (value != _camera) {
      _camera = value;
      _plane.camera = value;
      _gizmo.camera = value;

      scope.dispatchEvent(Event(type: 'camera-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Object3D? _object;
  Object3D? get object => _object;

  set object(Object3D? value) {
    if (value != _object) {
      _object = value;
      _plane.object = value;
      _gizmo.object = value;

      scope.dispatchEvent(Event(type: 'object-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  bool _enabled = true;
  bool get enabled => _enabled;

  set enabled(bool value) {
    if (value != _enabled) {
      _enabled = value;
      _plane.enabled = value;
      _gizmo.enabled = value;

      scope.dispatchEvent(Event(type: 'enabled-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  String? _axis;
  String? get axis => _axis;

  set axis(String? value) {
    if (value != _axis) {
      _axis = value;
      _plane.axis = value;
      _gizmo.axis = value;

      scope.dispatchEvent(Event(type: 'axis-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  String _mode = "translate";
  String get mode => _mode;

  set mode(String value) {
    if (value != _mode) {
      _mode = value;
      _plane.mode = value;
      _gizmo.mode = value;

      scope.dispatchEvent(Event(type: 'mode-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  double? _translationSnap;
  double? get translationSnap => _translationSnap;

  set translationSnap(double? value) {
    if (value != _translationSnap) {
      _translationSnap = value;

      scope.dispatchEvent(
          Event(type: 'translationSnap-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  num? _rotationSnap;
  num? get rotationSnap => _rotationSnap;

  set rotationSnap(num? value) {
    if (value != _rotationSnap) {
      _rotationSnap = value;

      scope.dispatchEvent(
          Event(type: 'rotationSnap-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  double? _scaleSnap;
  double? get scaleSnap => _scaleSnap;

  set scaleSnap(double? value) {
    if (value != _scaleSnap) {
      _scaleSnap = value;

      scope.dispatchEvent(Event(type: 'scaleSnap-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  String _space = "world";
  String get space => _space;

  set space(String value) {
    if (value != _space) {
      _space = value;
      _plane.space = value;
      _gizmo.space = value;

      scope.dispatchEvent(Event(type: 'space-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  int _size = 1;
  int get size => _size;

  set size(int value) {
    if (value != _size) {
      _size = value;
      _plane.size = value;
      _gizmo.size = value;

      scope.dispatchEvent(Event(type: 'size-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  bool _dragging = false;
  bool get dragging => _dragging;

  set dragging(bool value) {
    if (value != _dragging) {
      _dragging = value;
      _plane.dragging = value;
      _gizmo.dragging = value;

      scope.dispatchEvent(Event(type: 'dragging-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  bool _showX = true;
  bool get showX => _showX;

  set showX(bool value) {
    if (value != _showX) {
      _showX = value;
      _plane.showX = value;
      _gizmo.showX = value;

      scope.dispatchEvent(Event(type: 'showX-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  bool _showY = true;
  bool get showY => _showY;

  set showY(bool value) {
    if (value != _showY) {
      _showY = value;
      _plane.showY = value;
      _gizmo.showY = value;

      scope.dispatchEvent(Event(type: 'showY-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  bool _showZ = true;
  bool get showZ => _showZ;

  set showZ(bool value) {
    if (value != _showZ) {
      _showZ = value;
      _plane.showZ = value;
      _gizmo.showZ = value;

      scope.dispatchEvent(Event(type: 'showZ-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  // Reusable utility variables

  // final worldPosition = Vector3();
  // final worldPositionStart = Vector3();
  // final worldQuaternion = Quaternion();
  // final worldQuaternionStart = Quaternion();
  // final cameraPosition = Vector3();
  // final cameraQuaternion = Quaternion();
  // final pointStart = Vector3();
  // final pointEnd = Vector3();
  // final rotationAxis = Vector3();
  // final rotationAngle = 0;
  // final eye = Vector3();

  Vector3 _worldPosition = Vector3();
  Vector3 get worldPosition => _worldPosition;

  set worldPosition(Vector3 value) {
    if (value != _worldPosition) {
      _worldPosition = value;

      scope.dispatchEvent(
          Event(type: 'worldPosition-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _worldPositionStart = Vector3();
  Vector3 get worldPositionStart => _worldPositionStart;

  set worldPositionStart(Vector3 value) {
    if (value != _worldPositionStart) {
      _worldPositionStart = value;

      scope.dispatchEvent(
          Event(type: 'worldPositionStart-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Quaternion _worldQuaternion = Quaternion();
  Quaternion get worldQuaternion => _worldQuaternion;

  set worldQuaternion(Quaternion value) {
    if (value != _worldQuaternion) {
      _worldQuaternion = value;

      scope.dispatchEvent(
          Event(type: 'worldQuaternion-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Quaternion _worldQuaternionStart = Quaternion();
  Quaternion get worldQuaternionStart => _worldQuaternionStart;

  set worldQuaternionStart(Quaternion value) {
    if (value != _worldQuaternionStart) {
      _worldQuaternionStart = value;

      scope.dispatchEvent(
          Event(type: 'worldQuaternionStart-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _cameraPosition = Vector3();
  Vector3 get cameraPosition => _cameraPosition;

  set cameraPosition(Vector3 value) {
    if (value != _cameraPosition) {
      _cameraPosition = value;

      scope.dispatchEvent(
          Event(type: 'cameraPosition-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Quaternion _cameraQuaternion = Quaternion();
  Quaternion get cameraQuaternion => _cameraQuaternion;

  set cameraQuaternion(Quaternion value) {
    if (value != _cameraQuaternion) {
      _cameraQuaternion = value;

      scope.dispatchEvent(
          Event(type: 'cameraQuaternion-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _pointStart = Vector3();
  Vector3 get pointStart => _pointStart;

  set pointStart(Vector3 value) {
    if (value != _pointStart) {
      _pointStart = value;

      scope
          .dispatchEvent(Event(type: 'pointStart-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _pointEnd = Vector3();
  Vector3 get pointEnd => _pointEnd;

  set pointEnd(Vector3 value) {
    if (value != _pointEnd) {
      _pointEnd = value;

      scope.dispatchEvent(Event(type: 'pointEnd-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _rotationAxis = Vector3();
  Vector3 get rotationAxis => _rotationAxis;

  set rotationAxis(Vector3 value) {
    if (value != _rotationAxis) {
      _rotationAxis = value;

      scope.dispatchEvent(
          Event(type: 'rotationAxis-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  num _rotationAngle = 0;
  num get rotationAngle => _rotationAngle;

  set rotationAngle(num value) {
    if (value != _rotationAngle) {
      _rotationAngle = value;

      scope.dispatchEvent(
          Event(type: 'rotationAngle-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  Vector3 _eye = Vector3();
  Vector3 get eye => _eye;

  set eye(Vector3 value) {
    if (value != _eye) {
      _eye = value;

      scope.dispatchEvent(Event(type: 'eye-changed', value: value));
      scope.dispatchEvent(_changeEvent);
    }
  }

  final _offset = Vector3();
  final _startNorm = Vector3();
  final _endNorm = Vector3();
  final _cameraScale = Vector3();

  final _parentPosition = Vector3();
  final _parentQuaternion = Quaternion();
  final _parentQuaternionInv = Quaternion();
  final _parentScale = Vector3();

  final _worldScaleStart = Vector3();
  final _worldQuaternionInv = Quaternion();
  final _worldScale = Vector3();

  final _positionStart = Vector3();
  final _quaternionStart = Quaternion();
  final _scaleStart = Vector3();

  TransformControls(Camera? camera, this.domKey) : super() {
    scope = this;

    this.visible = false;
    this.domElement = domKey.currentState;
    _camera = camera;
    // this.domElement.style.touchAction = 'none'; // disable touch scroll

    _gizmo = TransformControlsGizmo(this);
    _gizmo.name = "TransformControlsGizmo";

    _plane = TransformControlsPlane(this);
    _plane.name = "TransformControlsPlane";

    this.add(_gizmo);
    this.add(_plane);

    this.domElement.addEventListener('pointerdown', this._onPointerDown, false);
    this.domElement.addEventListener('pointermove', this._onPointerHover, false);
    this.domElement.addEventListener('pointerup', this._onPointerUp, false);
  }

  // updateMatrixWorld  updates key transformation variables
  void updateMatrixWorld([bool force = false]) {
    if (this.object != null) {
      this.object?.updateMatrixWorld(force);

      if (this.object?.parent == null) {
        print(
            'TransformControls: The attached 3D object must be a part of the scene graph.');
      } 
      else {
        this.object?.parent?.matrixWorld.decompose(this._parentPosition, this._parentQuaternion, this._parentScale);
      }

      this.object?.matrixWorld.decompose(this.worldPosition, this.worldQuaternion, this._worldScale);

      this._parentQuaternionInv.copy(this._parentQuaternion).invert();
      this._worldQuaternionInv.copy(this.worldQuaternion).invert();
    }

    this.camera?.updateMatrixWorld(force);

    this.camera
        ?.matrixWorld
        .decompose(this.cameraPosition, this.cameraQuaternion, _cameraScale);

    this.eye.copy(this.cameraPosition).sub(this.worldPosition).normalize();

    super.updateMatrixWorld(force);
  }

  void pointerHover(Pointer pointer) {
    if (this.object == null || this.dragging == true) return;

    _raycaster.setFromCamera(Vector2(pointer.x, pointer.y), this.camera!);

    final intersect = intersectObjectWithRay(
        this._gizmo.picker[this.mode], _raycaster, false);

    if (intersect != null) {
      this.axis = intersect.object?.name;
    } 
    else {
      this.axis = null;
    }
  }

  void pointerDown(Pointer pointer) {
    _pointer0 = pointer;


    if (this.object == null || this.dragging == true || pointer.button != 1)
      return;

    if (this.axis != null) {
      _raycaster.setFromCamera(Vector2(pointer.x, pointer.y), this.camera!);

      final planeIntersect =
          intersectObjectWithRay(this._plane, _raycaster, true);

      if (planeIntersect != null) {
        this.object?.updateMatrixWorld(false);
        this.object?.parent?.updateMatrixWorld(false);

        this._positionStart.copy(this.object!.position);
        this._quaternionStart.copy(this.object!.quaternion);
        this._scaleStart.copy(this.object!.scale);

        this.object?.matrixWorld.decompose(this.worldPositionStart,this.worldQuaternionStart, this._worldScaleStart);

        this.pointStart.copy(planeIntersect.point!).sub(this.worldPositionStart);
      }

      this.dragging = true;
      _mouseDownEvent.mode = this.mode;
      this.dispatchEvent(_mouseDownEvent);
    }
  }

  void pointerMove(Pointer pointer) {
    if (pointer.x == _pointer0?.x &&
        pointer.y == _pointer0?.y &&
        pointer.button == _pointer0?.button) {
      return;
    }
    _pointer0 = pointer;

    final axis = this.axis;
    final mode = this.mode;
    final object = this.object;
    String space = this.space;

    if (mode == 'scale') {
      space = 'local';
    } 
    else if (axis == 'E' || axis == 'XYZE' || axis == 'XYZ') {
      space = 'world';
    }

    if (object == null ||
        axis == null ||
        this.dragging == false ||
        pointer.button != 1) return;

    _raycaster.setFromCamera(Vector2(pointer.x, pointer.y), this.camera!);

    final planeIntersect = intersectObjectWithRay(this._plane, _raycaster, true);

    if (planeIntersect == null) return;

    this.pointEnd.copy(planeIntersect.point!).sub(this.worldPositionStart);

    if (mode == 'translate') {
      // Apply translate

      this._offset.copy(this.pointEnd).sub(this.pointStart);

      if (space == 'local' && axis != 'XYZ') {
        this._offset.applyQuaternion(this._worldQuaternionInv);
      }

      if (axis.indexOf('X') == -1) this._offset.x = 0;
      if (axis.indexOf('Y') == -1) this._offset.y = 0;
      if (axis.indexOf('Z') == -1) this._offset.z = 0;

      if (space == 'local' && axis != 'XYZ') {
        this
            ._offset
            .applyQuaternion(this._quaternionStart)
            .divide(this._parentScale);
      } else {
        this
            ._offset
            .applyQuaternion(this._parentQuaternionInv)
            .divide(this._parentScale);
      }

      object.position.copy(this._offset).add(this._positionStart);

      // Apply translation snap

      if (this.translationSnap != null) {
        if (space == 'local') {
          object.position.applyQuaternion(
              _tempQuaternion.copy(this._quaternionStart).invert());

          if (axis.indexOf('X') != -1) {
            object.position.x =
                Math.round(object.position.x / this.translationSnap!) * this.translationSnap!;
          }

          if (axis.indexOf('Y') != -1) {
            object.position.y =
                Math.round(object.position.y / this.translationSnap!) * this.translationSnap!;
          }

          if (axis.indexOf('Z') != -1) {
            object.position.z =
                Math.round(object.position.z / this.translationSnap!) * this.translationSnap!;
          }

          object.position.applyQuaternion(this._quaternionStart);
        }

        if (space == 'world') {
          if (object.parent != null) {
            //final _vec = _tempVector.setFromMatrixPosition(object.parent?.matrixWorld);
            object.position.add(_tempVector.setFromMatrixPosition(object.parent?.matrixWorld));
          }

          if (axis.indexOf('X') != -1) {
            object.position.x =
                Math.round(object.position.x / this.translationSnap!) * this.translationSnap!;
          }

          if (axis.indexOf('Y') != -1) {
            object.position.y =
                Math.round(object.position.y / this.translationSnap!) *this.translationSnap!;
          }

          if (axis.indexOf('Z') != -1) {
            object.position.z =
                Math.round(object.position.z / this.translationSnap!) * this.translationSnap!;
          }

          if (object.parent != null) {
            object.position.sub(
                _tempVector.setFromMatrixPosition(object.parent?.matrixWorld));
          }
        }
      }
    } 
    else if (mode == 'scale') {
      if (axis.indexOf('XYZ') != -1) {
        num d = this.pointEnd.length() / this.pointStart.length();

        if (this.pointEnd.dot(this.pointStart) < 0){ 
          d *= -1;
        }

        _tempVector2.set(d, d, d);
      } 
      else {
        _tempVector.copy(this.pointStart);
        _tempVector2.copy(this.pointEnd);

        _tempVector.applyQuaternion(this._worldQuaternionInv);
        _tempVector2.applyQuaternion(this._worldQuaternionInv);

        _tempVector2.divide(_tempVector);

        if (axis.indexOf('X') == -1) {
          _tempVector2.x = 1;
        }

        if (axis.indexOf('Y') == -1) {
          _tempVector2.y = 1;
        }

        if (axis.indexOf('Z') == -1) {
          _tempVector2.z = 1;
        }
      }

      // Apply scale

      object.scale.copy(this._scaleStart).multiply(_tempVector2);

      if (this.scaleSnap != null) {
        if (axis.indexOf('X') != -1) {
          double _x = Math.round(object.scale.x / this.scaleSnap!) * this.scaleSnap!;
          object.scale.x = _x != 0 ? _x : this.scaleSnap!;
        }

        if (axis.indexOf('Y') != -1) {
          double _y = Math.round(object.scale.y / this.scaleSnap!) * this.scaleSnap!;
          object.scale.y = _y != 0 ? _y : this.scaleSnap!;
        }

        if (axis.indexOf('Z') != -1) {
          double _z = Math.round(object.scale.z / this.scaleSnap!) * this.scaleSnap!;
          object.scale.z = _z != 0 ? _z : this.scaleSnap!;
        }
      }
    } 
    else if (mode == 'rotate') {
      this._offset.copy(this.pointEnd).sub(this.pointStart);

      final rotationSpeed = 20 /
          this.worldPosition.distanceTo(
              _tempVector.setFromMatrixPosition(this.camera?.matrixWorld));

      if (axis == 'E') {
        this.rotationAxis.copy(this.eye);
        this.rotationAngle = this.pointEnd.angleTo(this.pointStart);

        this._startNorm.copy(this.pointStart).normalize();
        this._endNorm.copy(this.pointEnd).normalize();

        this.rotationAngle *=
            (this._endNorm.cross(this._startNorm).dot(this.eye) < 0 ? 1 : -1);
      } 
      else if (axis == 'XYZE') {
        this.rotationAxis.copy(this._offset).cross(this.eye).normalize();
        this.rotationAngle = this._offset
            .dot(_tempVector.copy(this.rotationAxis).cross(this.eye)) *
            rotationSpeed;
      } 
      else if (axis == 'X' || axis == 'Y' || axis == 'Z') {
        this.rotationAxis.copy(_unit[axis]!);

        _tempVector.copy(_unit[axis]!);

        if (space == 'local') {
          _tempVector.applyQuaternion(this.worldQuaternion);
        }

        this.rotationAngle =
            this._offset.dot(_tempVector.cross(this.eye).normalize()) *
                rotationSpeed;
      }

      // Apply rotation snap

      if (this.rotationSnap != null)
        this.rotationAngle = Math.round(this.rotationAngle / this.rotationSnap!) * this.rotationSnap!;

      // Apply rotate
      if (space == 'local' && axis != 'E' && axis != 'XYZE') {
        object.quaternion.copy(this._quaternionStart);
        object.quaternion
            .multiply(_tempQuaternion.setFromAxisAngle(
                this.rotationAxis, this.rotationAngle))
            .normalize();
      } else {
        this.rotationAxis.applyQuaternion(this._parentQuaternionInv);
        object.quaternion.copy(_tempQuaternion.setFromAxisAngle(
            this.rotationAxis, this.rotationAngle));
        object.quaternion.multiply(this._quaternionStart).normalize();
      }
    }

    this.dispatchEvent(_changeEvent);
    this.dispatchEvent(_objectChangeEvent);
  }

  void pointerUp(Pointer pointer) {
    if (pointer.button != 0) return;

    if (this.dragging && (this.axis != null)) {
      _mouseUpEvent.mode = this.mode;
      this.dispatchEvent(_mouseUpEvent);
    }

    this.dragging = false;
    this.axis = null;
  }

  void dispose() {
    this.domElement.removeEventListener('pointerdown', this._onPointerDown);
    this.domElement.removeEventListener('pointermove', this._onPointerHover);
    this.domElement.removeEventListener('pointermove', this._onPointerMove);
    this.domElement.removeEventListener('pointerup', this._onPointerUp);

    this.traverse((child) {
      child.geometry?.dispose();
      child.material?.dispose();
    });
  }

  // Set current object
  TransformControls attach(Object3D? object) {
    this.object = object;
    this.visible = true;

    return this;
  }

  // Detatch from object
  TransformControls detach() {
    this.object = null;
    this.visible = false;
    this.axis = null;

    return this;
  }

  Raycaster getRaycaster() {
    return _raycaster;
  }

  String getMode() {
    return this.mode;
  }

  void setMode(mode) {
    this.mode = mode;
  }

  void setTranslationSnap(translationSnap) {
    this.translationSnap = translationSnap;
  }

  void setRotationSnap(rotationSnap) {
    this.rotationSnap = rotationSnap;
  }

  void setScaleSnap(scaleSnap) {
    this.scaleSnap = scaleSnap;
  }

  void setSize(size) {
    this.size = size;
  }

  void setSpace(space) {
    this.space = space;
  }

  void update() {
    print(
        'THREE.TransformControls: update function has no more functionality and therefore has been deprecated.');
  }

  // mouse / touch event handlers
  Pointer _getPointer(event) {
    return getPointer(event);
  }

  void _onPointerDown(event) {
    return onPointerDown(event);
  }

  void _onPointerHover(event) {
    return onPointerHover(event);
  }

  void _onPointerMove(event) {
    return onPointerMove(event);
  }

  void _onPointerUp(event) {
    return onPointerUp(event);
  }

  Pointer getPointer(event) {
    final RenderBox renderBox = domKey.currentContext!.findRenderObject();
    final size = renderBox.size;
    final rect = size;
    int left = 0;
    int top = 0;

    final _x = (event.clientX - left) / rect.width * 2 - 1;
    final _y = -(event.clientY - top) / rect.height * 2 + 1;
    final _button = event.button;

    return Pointer(_x, _y, _button);
  }

  void onPointerHover(event) {
    if (!this.enabled) return;

    switch (event.pointerType) {
      case 'mouse':
      case 'pen':
        this.pointerHover(this._getPointer(event));
        break;
    }
  }

  void onPointerDown(event) {
    if (!this.enabled) return;

    // this.domElement.setPointerCapture( event.pointerId );

    this.domElement.addEventListener('pointermove', this._onPointerMove);

    this.pointerHover(this._getPointer(event));
    this.pointerDown(this._getPointer(event));
  }

  void onPointerMove(event) {
    if (!this.enabled) return;

    this.pointerMove(this._getPointer(event));
  }

  void onPointerUp(event) {
    if (!this.enabled) return;

    // this.domElement.releasePointerCapture( event.pointerId );

    this.domElement.removeEventListener('pointermove', this._onPointerMove);

    this.pointerUp(this._getPointer(event));
  }

  Intersection? intersectObjectWithRay(Object3D object, Raycaster raycaster, bool includeInvisible) {
    final allIntersections = raycaster.intersectObject(object, true, null);

    for (int i = 0; i < allIntersections.length; i++) {
      if (allIntersections[i].object!.visible || includeInvisible) {
        return allIntersections[i];
      }
    }

    return null;
  }
}

class Pointer {
  late double x;
  late double y;
  late int button;
  Pointer(double x, double y, int button) {
    this.x = x;
    this.y = y;
    this.button = button;
  }

  Map<String,dynamic> toJSON() {
    return {"x": x, "y": y, "button": button};
  }
}
