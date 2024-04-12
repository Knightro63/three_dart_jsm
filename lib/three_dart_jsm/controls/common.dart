part of jsm_controls;

final _changeEvent = Event(type: 'change');
final _startEvent = Event(type: 'start');
final _endEvent = Event(type: 'end');

final infinity = Math.infinity;

final _euler = Euler(0, 0, 0, 'YXZ');
final _vector = Vector3();

final _lockEvent = Event(type: 'lock');
final _unlockEvent = Event(type: 'unlock');

final _pi2 = Math.pi / 2;

final _raycaster = Raycaster();

final _plane = Plane();

final _pointer = Vector2();
final _offset = Vector3();
final _intersection = Vector3();
final _worldPosition = Vector3();
final _inverseMatrix = Matrix4();
