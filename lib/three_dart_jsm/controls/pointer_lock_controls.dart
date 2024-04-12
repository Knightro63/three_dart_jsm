part of jsm_controls;

class PointerLockControls with EventDispatcher {
  bool isLocked = false;

  // Set to constrain the pitch of the camera
  // Range is 0 to Math.pi radians
  double minPolarAngle = 0; // radians
  double maxPolarAngle = Math.pi; // radians

  double pointerSpeed = 1.0;

  late Camera camera;
  late PointerLockControls scope;

  late GlobalKey<DomLikeListenableState> listenableKey;
  DomLikeListenableState get domElement => listenableKey.currentState!;

  PointerLockControls(this.camera, this.listenableKey) : super() {
    scope = this;
    this.connect();
  }

  void onMouseMove(event) {
    print("onMouseMove event: $event isLocked ${scope.isLocked} ");
    if (scope.isLocked == false) return;

    var movementX =
        event.movementX ?? event.mozMovementX ?? event.webkitMovementX ?? 0;
    var movementY =
        event.movementY ?? event.mozMovementY ?? event.webkitMovementY ?? 0;

    _euler.setFromQuaternion(camera.quaternion);

    _euler.y -= movementX * 0.002 * scope.pointerSpeed;
    _euler.x -= movementY * 0.002 * scope.pointerSpeed;

    _euler.x = Math.max(_pi2 - scope.maxPolarAngle,
        Math.min(_pi2 - scope.minPolarAngle, _euler.x));

    camera.quaternion.setFromEuler(_euler);

    scope.dispatchEvent(_changeEvent);
  }

  void onPointerlockChange() {
    if (scope.domElement.pointerLockElement == scope.domElement) {
      scope.dispatchEvent(_lockEvent);

      scope.isLocked = true;
    } else {
      scope.dispatchEvent(_unlockEvent);

      scope.isLocked = false;
    }
  }

  void onPointerlockError() {
    print('THREE.PointerLockControls: Unable to use Pointer Lock API');
  }

  void connect() {
    scope.domElement.addEventListener('mousemove', onMouseMove);
    scope.domElement.addEventListener('touchmove', onMouseMove);
    scope.domElement.addEventListener('pointerlockchange', onPointerlockChange);
    scope.domElement.addEventListener('pointerlockerror', onPointerlockError);
  }

  void disconnect() {
    scope.domElement.removeEventListener('mousemove', onMouseMove);
    scope.domElement
        .removeEventListener('pointerlockchange', onPointerlockChange);
    scope.domElement
        .removeEventListener('pointerlockerror', onPointerlockError);
  }

  void dispose() {
    this.disconnect();
  }

  Camera get getObject => camera;

  final direction = Vector3(0, 0, -1);

  Vector3 getDirection(Vector3 v) {
    return v.copy(direction).applyQuaternion(camera.quaternion);
  }

  void moveForward(distance) {
    // move forward parallel to the xz-plane
    // assumes camera.up is y-up

    _vector.setFromMatrixColumn(camera.matrix, 0);

    _vector.crossVectors(camera.up, _vector);

    camera.position.addScaledVector(_vector, distance);
  }

  void moveRight(distance) {
    _vector.setFromMatrixColumn(camera.matrix, 0);

    camera.position.addScaledVector(_vector, distance);
  }

  void lock() {
    this.isLocked = true;
    this.domElement.requestPointerLock();
  }

  void unlock() {
    scope.domElement.exitPointerLock();
  }
}
