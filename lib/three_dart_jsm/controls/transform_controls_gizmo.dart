part of jsm_controls;
// Reusable utility variables

final _tempEuler = Euler(0, 0, 0);
final _alignVector = Vector3(0, 1, 0);
final _zeroVector = Vector3(0, 0, 0);
final _lookAtMatrix = Matrix4();
final _tempQuaternion2 = Quaternion();
final _identityQuaternion = Quaternion();
final _dirVector = Vector3();
final _tempMatrix = Matrix4();

final _unitX = Vector3(1, 0, 0);
final _unitY = Vector3(0, 1, 0);
final _unitZ = Vector3(0, 0, 1);

final _v1 = Vector3();
final _v2 = Vector3();
final _v3 = Vector3();

class TransformControlsGizmo extends Object3D {
  bool isTransformControlsGizmo = true;
  String type = 'TransformControlsGizmo';

  Camera? camera;
  Object3D? object;
  bool enabled = true;
  String? axis;
  String mode = "translate";
  String space = "world";
  int size = 1;
  bool dragging = false;
  bool showX = true;
  bool showY = true;
  bool showZ = true;

  // final worldPosition = Vector3();
  // final worldPositionStart = Vector3();
  // final worldQuaternion = Quaternion();
  // final worldQuaternionStart = Quaternion();
  // final cameraPosition = Vector3();
  // final cameraQuaternion = Quaternion();
  // final pointStart = Vector3();
  // final pointEnd = Vector3();
  // final rotationAxis = Vector3();
  // num rotationAngle = 0;
  // final eye = Vector3();

  get eye {
    return controls.eye;
  }

  get cameraPosition {
    return controls.cameraPosition;
  }

  get cameraQuaternion {
    return controls.cameraQuaternion;
  }

  get worldPosition {
    return controls.worldPosition;
  }

  get rotationAngle {
    return controls.rotationAngle;
  }

  get rotationSnap {
    return controls.rotationSnap;
  }

  get translationSnap {
    return controls.translationSnap;
  }

  get scaleSnap {
    return controls.scaleSnap;
  }

  get worldPositionStart {
    return controls.worldPositionStart;
  }

  get worldQuaternion {
    return controls.worldQuaternion;
  }

  get worldQuaternionStart {
    return controls.worldQuaternionStart;
  }

  get pointStart {
    return controls.pointStart;
  }

  get pointEnd {
    return controls.pointEnd;
  }

  get rotationAxis {
    return controls.rotationAxis;
  }

  final gizmo = {};
  final picker = {};
  final helper = {};

  late TransformControls controls;

  TransformControlsGizmo(controls) : super() {
    this.controls = controls;
    // shared materials

    final gizmoMaterial = MeshBasicMaterial({
      "depthTest": false,
      "depthWrite": false,
      "fog": false,
      "toneMapped": false,
      "transparent": true
    });

    final gizmoLineMaterial = LineBasicMaterial({
      "depthTest": false,
      "depthWrite": false,
      "fog": false,
      "toneMapped": false,
      "transparent": true
    });

    // Make unique material for each axis/color

    final matInvisible = gizmoMaterial.clone();
    matInvisible.opacity = 0.15;

    final matHelper = gizmoLineMaterial.clone();
    matHelper.opacity = 0.5;

    final matRed = gizmoMaterial.clone();
    matRed.color.setHex(0xff0000);

    final matGreen = gizmoMaterial.clone();
    matGreen.color.setHex(0x00ff00);

    final matBlue = gizmoMaterial.clone();
    matBlue.color.setHex(0x0000ff);

    final matRedTransparent = gizmoMaterial.clone();
    matRedTransparent.color.setHex(0xff0000);
    matRedTransparent.opacity = 0.5;

    final matGreenTransparent = gizmoMaterial.clone();
    matGreenTransparent.color.setHex(0x00ff00);
    matGreenTransparent.opacity = 0.5;

    final matBlueTransparent = gizmoMaterial.clone();
    matBlueTransparent.color.setHex(0x0000ff);
    matBlueTransparent.opacity = 0.5;

    final matWhiteTransparent = gizmoMaterial.clone();
    matWhiteTransparent.opacity = 0.25;

    final matYellowTransparent = gizmoMaterial.clone();
    matYellowTransparent.color.setHex(0xffff00);
    matYellowTransparent.opacity = 0.25;

    final matYellow = gizmoMaterial.clone();
    matYellow.color.setHex(0xffff00);

    final matGray = gizmoMaterial.clone();
    matGray.color.setHex(0x787878);

    // reusable geometry

    final arrowGeometry = CylinderGeometry(0, 0.04, 0.1, 12);
    arrowGeometry.translate(0, 0.05, 0);

    final scaleHandleGeometry = BoxGeometry(0.08, 0.08, 0.08);
    scaleHandleGeometry.translate(0, 0.04, 0);

    final lineGeometry = BufferGeometry();
    lineGeometry.setAttribute(
        'position', Float32BufferAttribute(Float32Array.from([0.0, 0.0, 0.0, 1.0, 0.0, 0.0]), 3));

    final lineGeometry2 = CylinderGeometry(0.0075, 0.0075, 0.5, 3);
    lineGeometry2.translate(0, 0.25, 0);

    // final circleGeometry = (radius, arc) {
    //   final geometry = TorusGeometry(radius, 0.0075, 3, 64, arc * Math.pi * 2);
    //   geometry.rotateY(Math.pi / 2);
    //   geometry.rotateX(Math.pi / 2);
    //   return geometry;
    // };

    // Special geometry for transform helper. If scaled with position vector it spans from [0,0,0] to position

    final translateHelperGeometry = () {
      final geometry = BufferGeometry();

      geometry.setAttribute(
          'position', Float32BufferAttribute(Float32Array.fromList([0.0, 0.0, 0.0, 1.0, 1.0, 1.0]), 3));

      return geometry;
    };

    // Gizmo definitions - custom hierarchy definitions for setupGizmo() function

    final gizmoTranslate = {
      "X": [
        [
          Mesh(arrowGeometry, matRed),
          [0.5, 0.0, 0.0],
          [0.0, 0.0, -Math.pi / 2]
        ],
        [
          Mesh(arrowGeometry, matRed),
          [-0.5, 0.0, 0.0],
          [0.0, 0.0, Math.pi / 2]
        ],
        [
          Mesh(lineGeometry2, matRed),
          [0.0, 0.0, 0.0],
          [0.0, 0.0, -Math.pi / 2]
        ]
      ],
      "Y": [
        [
          Mesh(arrowGeometry, matGreen),
          [0, 0.5, 0]
        ],
        [
          Mesh(arrowGeometry, matGreen),
          [0, -0.5, 0],
          [Math.pi, 0, 0]
        ],
        [Mesh(lineGeometry2, matGreen)]
      ],
      "Z": [
        [
          Mesh(arrowGeometry, matBlue),
          [0, 0, 0.5],
          [Math.pi / 2, 0, 0]
        ],
        [
          Mesh(arrowGeometry, matBlue),
          [0, 0, -0.5],
          [-Math.pi / 2, 0, 0]
        ],
        [
          Mesh(lineGeometry2, matBlue),
          null,
          [Math.pi / 2, 0, 0]
        ]
      ],
      "XYZ": [
        [
          Mesh(OctahedronGeometry(0.1, 0), matWhiteTransparent.clone()),
          [0, 0, 0]
        ]
      ],
      "XY": [
        [
          Mesh(
              BoxGeometry(0.15, 0.15, 0.01), matBlueTransparent.clone()),
          [0.15, 0.15, 0]
        ]
      ],
      "YZ": [
        [
          Mesh(
              BoxGeometry(0.15, 0.15, 0.01), matRedTransparent.clone()),
          [0, 0.15, 0.15],
          [0, Math.pi / 2, 0]
        ]
      ],
      "XZ": [
        [
          Mesh(
              BoxGeometry(0.15, 0.15, 0.01), matGreenTransparent.clone()),
          [0.15, 0, 0.15],
          [-Math.pi / 2, 0, 0]
        ]
      ]
    };

    final pickerTranslate = {
      "X": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0.3, 0, 0],
          [0, 0, -Math.pi / 2]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [-0.3, 0, 0],
          [0, 0, Math.pi / 2]
        ]
      ],
      "Y": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0.3, 0]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, -0.3, 0],
          [0, 0, Math.pi]
        ]
      ],
      "Z": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0, 0.3],
          [Math.pi / 2, 0, 0]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0, -0.3],
          [-Math.pi / 2, 0, 0]
        ]
      ],
      "XYZ": [
        [Mesh(OctahedronGeometry(0.2, 0), matInvisible)]
      ],
      "XY": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0.15, 0.15, 0]
        ]
      ],
      "YZ": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0, 0.15, 0.15],
          [0, Math.pi / 2, 0]
        ]
      ],
      "XZ": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0.15, 0, 0.15],
          [-Math.pi / 2, 0, 0]
        ]
      ]
    };

    final helperTranslate = {
      "START": [
        [
          Mesh(OctahedronGeometry(0.01, 2), matHelper),
          null,
          null,
          null,
          'helper'
        ]
      ],
      "END": [
        [
          Mesh(OctahedronGeometry(0.01, 2), matHelper),
          null,
          null,
          null,
          'helper'
        ]
      ],
      "DELTA": [
        [
          Line(translateHelperGeometry(), matHelper),
          null,
          null,
          null,
          'helper'
        ]
      ],
      "X": [
        [
          Line(lineGeometry, matHelper.clone()),
          [-1e3, 0, 0],
          null,
          [1e6, 1, 1],
          'helper'
        ]
      ],
      "Y": [
        [
          Line(lineGeometry, matHelper.clone()),
          [0, -1e3, 0],
          [0, 0, Math.pi / 2],
          [1e6, 1, 1],
          'helper'
        ]
      ],
      "Z": [
        [
          Line(lineGeometry, matHelper.clone()),
          [0, 0, -1e3],
          [0, -Math.pi / 2, 0],
          [1e6, 1, 1],
          'helper'
        ]
      ]
    };

    final gizmoRotate = {
      "XYZE": [
        [
          Mesh(CircleGeometry(radius: 0.5, thetaLength:1), matGray),
          null,
          [0, Math.pi / 2, 0]
        ]
      ],
      "X": [
        [Mesh(CircleGeometry(radius: 0.5, thetaLength:0.5), matRed)]
      ],
      "Y": [
        [
          Mesh(CircleGeometry(radius: 0.5, thetaLength:0.5), matGreen),
          null,
          [0, 0, -Math.pi / 2]
        ]
      ],
      "Z": [
        [
          Mesh(CircleGeometry(radius: 0.5, thetaLength:0.5), matBlue),
          null,
          [0, Math.pi / 2, 0]
        ]
      ],
      "E": [
        [
          Mesh(CircleGeometry(radius: 0.75, thetaLength:1), matYellowTransparent),
          null,
          [0, Math.pi / 2, 0]
        ]
      ]
    };

    final helperRotate = {
      "AXIS": [
        [
          Line(lineGeometry, matHelper.clone()),
          [-1e3, 0, 0],
          null,
          [1e6, 1, 1],
          'helper'
        ]
      ]
    };

    final pickerRotate = {
      "XYZE": [
        [Mesh(SphereGeometry(0.25, 10, 8), matInvisible)]
      ],
      "X": [
        [
          Mesh(TorusGeometry(0.5, 0.1, 4, 24), matInvisible),
          [0, 0, 0],
          [0, -Math.pi / 2, -Math.pi / 2]
        ],
      ],
      "Y": [
        [
          Mesh(TorusGeometry(0.5, 0.1, 4, 24), matInvisible),
          [0, 0, 0],
          [Math.pi / 2, 0, 0]
        ],
      ],
      "Z": [
        [
          Mesh(TorusGeometry(0.5, 0.1, 4, 24), matInvisible),
          [0, 0, 0],
          [0, 0, -Math.pi / 2]
        ],
      ],
      "E": [
        [Mesh(TorusGeometry(0.75, 0.1, 2, 24), matInvisible)]
      ]
    };

    final gizmoScale = {
      "X": [
        [
          Mesh(scaleHandleGeometry, matRed),
          [0.5, 0, 0],
          [0, 0, -Math.pi / 2]
        ],
        [
          Mesh(lineGeometry2, matRed),
          [0, 0, 0],
          [0, 0, -Math.pi / 2]
        ],
        [
          Mesh(scaleHandleGeometry, matRed),
          [-0.5, 0, 0],
          [0, 0, Math.pi / 2]
        ],
      ],
      "Y": [
        [
          Mesh(scaleHandleGeometry, matGreen),
          [0, 0.5, 0]
        ],
        [Mesh(lineGeometry2, matGreen)],
        [
          Mesh(scaleHandleGeometry, matGreen),
          [0, -0.5, 0],
          [0, 0, Math.pi]
        ],
      ],
      "Z": [
        [
          Mesh(scaleHandleGeometry, matBlue),
          [0, 0, 0.5],
          [Math.pi / 2, 0, 0]
        ],
        [
          Mesh(lineGeometry2, matBlue),
          [0, 0, 0],
          [Math.pi / 2, 0, 0]
        ],
        [
          Mesh(scaleHandleGeometry, matBlue),
          [0, 0, -0.5],
          [-Math.pi / 2, 0, 0]
        ]
      ],
      "XY": [
        [
          Mesh(BoxGeometry(0.15, 0.15, 0.01), matBlueTransparent),
          [0.15, 0.15, 0]
        ]
      ],
      "YZ": [
        [
          Mesh(BoxGeometry(0.15, 0.15, 0.01), matRedTransparent),
          [0, 0.15, 0.15],
          [0, Math.pi / 2, 0]
        ]
      ],
      "XZ": [
        [
          Mesh(BoxGeometry(0.15, 0.15, 0.01), matGreenTransparent),
          [0.15, 0, 0.15],
          [-Math.pi / 2, 0, 0]
        ]
      ],
      "XYZ": [
        [Mesh(BoxGeometry(0.1, 0.1, 0.1), matWhiteTransparent.clone())],
      ]
    };

    final pickerScale = {
      "X": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0.3, 0, 0],
          [0, 0, -Math.pi / 2]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [-0.3, 0, 0],
          [0, 0, Math.pi / 2]
        ]
      ],
      "Y": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0.3, 0]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, -0.3, 0],
          [0, 0, Math.pi]
        ]
      ],
      "Z": [
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0, 0.3],
          [Math.pi / 2, 0, 0]
        ],
        [
          Mesh(CylinderGeometry(0.2, 0, 0.6, 4), matInvisible),
          [0, 0, -0.3],
          [-Math.pi / 2, 0, 0]
        ]
      ],
      "XY": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0.15, 0.15, 0]
        ],
      ],
      "YZ": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0, 0.15, 0.15],
          [0, Math.pi / 2, 0]
        ],
      ],
      "XZ": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.01), matInvisible),
          [0.15, 0, 0.15],
          [-Math.pi / 2, 0, 0]
        ],
      ],
      "XYZ": [
        [
          Mesh(BoxGeometry(0.2, 0.2, 0.2), matInvisible),
          [0, 0, 0]
        ],
      ]
    };

    final helperScale = {
      "X": [
        [
          Line(lineGeometry, matHelper.clone()),
          [-1e3, 0, 0],
          null,
          [1e6, 1, 1],
          'helper'
        ]
      ],
      "Y": [
        [
          Line(lineGeometry, matHelper.clone()),
          [0, -1e3, 0],
          [0, 0, Math.pi / 2],
          [1e6, 1, 1],
          'helper'
        ]
      ],
      "Z": [
        [
          Line(lineGeometry, matHelper.clone()),
          [0, 0, -1e3],
          [0, -Math.pi / 2, 0],
          [1e6, 1, 1],
          'helper'
        ]
      ]
    };

    // Creates an Object3D with gizmos described in custom hierarchy definition.

    final setupGizmo = (gizmoMap) {
      final gizmo = Object3D();

      for (final name in gizmoMap.keys) {
        final _len = gizmoMap[name].length;

        for (int i = (_len - 1); i >= 0; i--) {
          final _gi = gizmoMap[name][i];

          dynamic object;
          if (_gi.length > 0) {
            object = _gi[0].clone();
          }

          List<num>? position;
          if (_gi.length > 1) {
            position = _gi[1];
          }

          List<num>? rotation;
          if (_gi.length > 2) {
            rotation = _gi[2];
          }

          List<num>? scale;
          if (_gi.length > 3) {
            scale = _gi[3];
          }

          dynamic tag ;
          if (_gi.length > 4) {
            tag = _gi[4];
          }

          // name and tag properties are essential for picking and updating logic.
          object.name = name;
          object.tag = tag;

          if (position != null) {
            object.position.set(position[0].toDouble(), position[1].toDouble(), position[2].toDouble());
          }

          if (rotation != null) {
            object.rotation.set(rotation[0].toDouble(), rotation[1].toDouble(), rotation[2].toDouble());
          }

          if (scale != null) {
            object.scale.set(scale[0].toDouble(), scale[1].toDouble(), scale[2].toDouble());
          }

          object.updateMatrix();

          final tempGeometry = object.geometry.clone();
          tempGeometry.applyMatrix4(object.matrix);
          object.geometry = tempGeometry;
          object.renderOrder = Math.infinity;

          object.position.set(0.0, 0.0, 0.0);
          object.rotation.set(0.0, 0.0, 0.0);
          object.scale.set(1.0, 1.0, 1.0);

          gizmo.add(object);
        }
      }

      return gizmo;
    };

    // Gizmo creation

    this.gizmo['translate'] = setupGizmo(gizmoTranslate);
    this.gizmo['rotate'] = setupGizmo(gizmoRotate);
    this.gizmo['scale'] = setupGizmo(gizmoScale);
    this.picker['translate'] = setupGizmo(pickerTranslate);
    this.picker['rotate'] = setupGizmo(pickerRotate);
    this.picker['scale'] = setupGizmo(pickerScale);
    this.helper['translate'] = setupGizmo(helperTranslate);
    this.helper['rotate'] = setupGizmo(helperRotate);
    this.helper['scale'] = setupGizmo(helperScale);

    this.add(this.gizmo['translate']);
    this.add(this.gizmo['rotate']);
    this.add(this.gizmo['scale']);
    this.add(this.picker['translate']);
    this.add(this.picker['rotate']);
    this.add(this.picker['scale']);
    this.add(this.helper['translate']);
    this.add(this.helper['rotate']);
    this.add(this.helper['scale']);

    // Pickers should be hidden always

    this.picker['translate'].visible = false;
    this.picker['rotate'].visible = false;
    this.picker['scale'].visible = false;
  }

  // updateMatrixWorld will update transformations and appearance of individual handles

  void updateMatrixWorld([bool force = false]) {
    final space = (this.mode == 'scale')
        ? 'local'
        : this.space; // scale always oriented to local rotation

    final quaternion =
        (space == 'local') ? this.worldQuaternion : _identityQuaternion;

    // Show only gizmos for current transform mode

    this.gizmo['translate'].visible = this.mode == 'translate';
    this.gizmo['rotate'].visible = this.mode == 'rotate';
    this.gizmo['scale'].visible = this.mode == 'scale';

    this.helper['translate'].visible = this.mode == 'translate';
    this.helper['rotate'].visible = this.mode == 'rotate';
    this.helper['scale'].visible = this.mode == 'scale';

    final handles = [];
    handles.addAll(this.picker[this.mode].children);
    handles.addAll(this.gizmo[this.mode].children);
    handles.addAll(this.helper[this.mode].children);

    // print("TransformControlsGizmo cameraQuaternion ${this.cameraQuaternion.toJSON()} ");

    // print("TransformControlsGizmo updateMatrixWorld mode: ${this.mode} handles: ${handles.length}  ");

    for (int i = 0; i < handles.length; i++) {
      final handle = handles[i];

      // hide aligned to camera

      handle.visible = true;
      handle.rotation.set(0.0, 0.0, 0.0);
      handle.position.copy(this.worldPosition);

      final factor;

      if (this.camera! is OrthographicCamera) {
        factor = (this.camera!.top - this.camera!.bottom) / this.camera!.zoom;
      } else {
        factor = this.worldPosition.distanceTo(this.cameraPosition) *
            Math.min(
                1.9 *
                    Math.tan(Math.pi * this.camera!.fov / 360) /
                    this.camera!.zoom,
                7);
      }

      handle.scale.set(1.0, 1.0, 1.0).multiplyScalar(factor * this.size / 4);

      if (handle.tag == 'helper') {
        handle.visible = false;

        if (handle.name == 'AXIS') {
          handle.position.copy(this.worldPositionStart);
          handle.visible = this.axis != null;

          if (this.axis == 'X') {
            _tempQuaternion.setFromEuler(_tempEuler.set(0, 0, 0), false);
            handle.quaternion.copy(quaternion).multiply(_tempQuaternion);

            if (Math.abs(_alignVector
                    .copy(_unitX)
                    .applyQuaternion(quaternion)
                    .dot(this.eye)) >
                0.9) {
              handle.visible = false;
            }
          }

          if (this.axis == 'Y') {
            _tempQuaternion.setFromEuler(
                _tempEuler.set(0, 0, Math.pi / 2), false);
            handle.quaternion.copy(quaternion).multiply(_tempQuaternion);

            if (Math.abs(_alignVector
                    .copy(_unitY)
                    .applyQuaternion(quaternion)
                    .dot(this.eye)) >
                0.9) {
              handle.visible = false;
            }
          }

          if (this.axis == 'Z') {
            _tempQuaternion.setFromEuler(
                _tempEuler.set(0, Math.pi / 2, 0), false);
            handle.quaternion.copy(quaternion).multiply(_tempQuaternion);

            if (Math.abs(_alignVector
                    .copy(_unitZ)
                    .applyQuaternion(quaternion)
                    .dot(this.eye)) >
                0.9) {
              handle.visible = false;
            }
          }

          if (this.axis == 'XYZE') {
            _tempQuaternion.setFromEuler(
                _tempEuler.set(0, Math.pi / 2, 0), false);
            _alignVector.copy(this.rotationAxis);
            handle.quaternion.setFromRotationMatrix(
                _lookAtMatrix.lookAt(_zeroVector, _alignVector, _unitY));
            handle.quaternion.multiply(_tempQuaternion);
            handle.visible = this.dragging;
          }

          if (this.axis == 'E') {
            handle.visible = false;
          }
        } else if (handle.name == 'START') {
          handle.position.copy(this.worldPositionStart);
          handle.visible = this.dragging;
        } else if (handle.name == 'END') {
          handle.position.copy(this.worldPosition);
          handle.visible = this.dragging;
        } else if (handle.name == 'DELTA') {
          handle.position.copy(this.worldPositionStart);
          handle.quaternion.copy(this.worldQuaternionStart);
          _tempVector
              .set(1e-10, 1e-10, 1e-10)
              .add(this.worldPositionStart)
              .sub(this.worldPosition)
              .multiplyScalar(-1);
          _tempVector
              .applyQuaternion(this.worldQuaternionStart.clone().invert());
          handle.scale.copy(_tempVector);
          handle.visible = this.dragging;
        } else {
          handle.quaternion.copy(quaternion);

          if (this.dragging) {
            handle.position.copy(this.worldPositionStart);
          } else {
            handle.position.copy(this.worldPosition);
          }

          if (this.axis != null) {
            handle.visible = this.axis!.indexOf(handle.name) != -1;
          }
        }

        // If updating helper, skip rest of the loop
        continue;
      }

      // Align handles to current local or world rotation

      handle.quaternion.copy(quaternion);

      if (this.mode == 'translate' || this.mode == 'scale') {
        // Hide translate and scale axis facing the camera

        final axisHideTreshold = 0.99;
        final planeHideTreshold = 0.2;

        if (handle.name == 'X') {
          if (Math.abs(_alignVector
                  .copy(_unitX)
                  .applyQuaternion(quaternion)
                  .dot(this.eye)) >
              axisHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }

        if (handle.name == 'Y') {
          if (Math.abs(_alignVector
                  .copy(_unitY)
                  .applyQuaternion(quaternion)
                  .dot(this.eye)) >
              axisHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }

        if (handle.name == 'Z') {
          if (Math.abs(_alignVector
                  .copy(_unitZ)
                  .applyQuaternion(quaternion)
                  .dot(this.eye)) >
              axisHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }

        if (handle.name == 'XY') {
          final ll = Math.abs(_alignVector
              .copy(_unitZ)
              .applyQuaternion(quaternion)
              .dot(this.eye));

          if (ll < planeHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }

        if (handle.name == 'YZ') {
          if (Math.abs(_alignVector
                  .copy(_unitX)
                  .applyQuaternion(quaternion)
                  .dot(this.eye)) <
              planeHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }

        if (handle.name == 'XZ') {
          if (Math.abs(_alignVector
                  .copy(_unitY)
                  .applyQuaternion(quaternion)
                  .dot(this.eye)) <
              planeHideTreshold) {
            handle.scale.set(1e-10, 1e-10, 1e-10);
            handle.visible = false;
          }
        }
      } else if (this.mode == 'rotate') {
        // Align handles to current local or world rotation

        _tempQuaternion2.copy(quaternion);
        _alignVector
            .copy(this.eye)
            .applyQuaternion(_tempQuaternion.copy(quaternion).invert());

        if (handle.name.indexOf('E') != -1) {
          handle.quaternion.setFromRotationMatrix(
              _lookAtMatrix.lookAt(this.eye, _zeroVector, _unitY));
        }

        if (handle.name == 'X') {
          _tempQuaternion.setFromAxisAngle(
              _unitX, Math.atan2(-_alignVector.y, _alignVector.z));
          _tempQuaternion.multiplyQuaternions(
              _tempQuaternion2, _tempQuaternion);
          handle.quaternion.copy(_tempQuaternion);
        }

        if (handle.name == 'Y') {
          _tempQuaternion.setFromAxisAngle(
              _unitY, Math.atan2(_alignVector.x, _alignVector.z));
          _tempQuaternion.multiplyQuaternions(
              _tempQuaternion2, _tempQuaternion);
          handle.quaternion.copy(_tempQuaternion);
        }

        if (handle.name == 'Z') {
          _tempQuaternion.setFromAxisAngle(
              _unitZ, Math.atan2(_alignVector.y, _alignVector.x));
          _tempQuaternion.multiplyQuaternions(
              _tempQuaternion2, _tempQuaternion);
          handle.quaternion.copy(_tempQuaternion);
        }
      }

      // Hide disabled axes
      handle.visible =
          handle.visible && (handle.name.indexOf('X') == -1 || this.showX);
      handle.visible =
          handle.visible && (handle.name.indexOf('Y') == -1 || this.showY);
      handle.visible =
          handle.visible && (handle.name.indexOf('Z') == -1 || this.showZ);
      handle.visible = handle.visible &&
          (handle.name.indexOf('E') == -1 ||
              (this.showX && this.showY && this.showZ));

      // highlight selected axis

      handle.material.userData["_color"] =
          handle.material.userData["_color"] ?? handle.material.color.clone();
      handle.material.userData["_opacity"] =
          handle.material.userData["_opacity"] ?? handle.material.opacity;

      handle.material.color.copy(handle.material.userData["_color"]);
      handle.material.opacity = handle.material.userData["_opacity"];

      if (this.enabled && this.axis != null) {
        if (handle.name == this.axis) {
          handle.material.color.setHex(0xffff00);
          handle.material.opacity = 1.0;
        } else if (this
                .axis!
                .split('')
                .where((a) {
                  return handle.name == a;
                })
                .toList()
                .length >
            0) {
          handle.material.color.setHex(0xffff00);
          handle.material.opacity = 1.0;
        }
      }
    }

    super.updateMatrixWorld(force);
  }
}
