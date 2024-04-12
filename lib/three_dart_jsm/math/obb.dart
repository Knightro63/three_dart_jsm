import 'package:three_dart/three_dart.dart';

// module scope helper variables

class OBBC {
  Vector3? c;
  List<Vector3> u;
  List e;

  OBBC(this.c,this.u,this.e);

  factory OBBC.fromJson(Map<String, dynamic> json) {
    return OBBC(
      json["c"],
      json["u"],
      json["e"]
    );
  }
}

final a = OBBC.fromJson({
  "c": null, // center
  "u": [
    Vector3(),
    Vector3(),
    Vector3()
  ], // basis vectors
  "e": [] // half width
});

final b = OBBC.fromJson({
  "c": null, // center
  "u": [
    Vector3(),
    Vector3(),
    Vector3()
  ], // basis vectors
  "e": [] // half width
});

final R = [[], [], []];
final AbsR = [[], [], []];
final t = [];

final xAxis = Vector3();
final yAxis = Vector3();
final zAxis = Vector3();
final v1 = Vector3();
final size = Vector3();
final closestPoint = Vector3();
final rotationMatrix = Matrix3();
final aabb = Box3();
final obbmatrix = Matrix4();
final inverse = Matrix4();
final localRay = Ray();

final obb = OBB();
// OBB

class OBB {
  late Vector3 center;
  late Vector3 halfSize;
  late Matrix3 rotation;

  OBB({Vector3? center, Vector3? halfSize, Matrix3? rotation}) {
    this.center = center ?? Vector3();
    this.halfSize = halfSize ?? Vector3();
    this.rotation = rotation ?? Matrix3();
  }

  OBB set(Vector3 center, Vector3 halfSize, Matrix3 rotation) {
    this.center = center;
    this.halfSize = halfSize;
    this.rotation = rotation;

    return this;
  }

  OBB copy(OBB obb) {
    this.center.copy(obb.center);
    this.halfSize.copy(obb.halfSize);
    this.rotation.copy(obb.rotation);

    return this;
  }

  OBB clone() {
    return OBB().copy(this);
  }

  Vector getSize(Vector result) {
    return result.copy(this.halfSize).multiplyScalar(2);
  }

  /**
	* Reference: Closest Point on OBB to Point in Real-Time Collision Detection
	* by Christer Ericson (chapter 5.1.4)
	*/
  Vector clampPoint(Vector point, Vector result) {
    final halfSize = this.halfSize;

    v1.subVectors(point, this.center);
    this.rotation.extractBasis(xAxis, yAxis, zAxis);

    // start at the center position of the OBB

    result.copy(this.center);

    // project the target onto the OBB axes and walk towards that point

    final x = MathUtils.clamp(v1.dot(xAxis), -halfSize.x, halfSize.x);
    result.add(xAxis.multiplyScalar(x));

    final y = MathUtils.clamp(v1.dot(yAxis), -halfSize.y, halfSize.y);
    result.add(yAxis.multiplyScalar(y));

    final z = MathUtils.clamp(v1.dot(zAxis), -halfSize.z, halfSize.z);
    result.add(zAxis.multiplyScalar(z));

    return result;
  }

  bool ontainsPoint(Vector point) {
    v1.subVectors(point, this.center);
    this.rotation.extractBasis(xAxis, yAxis, zAxis);

    // project v1 onto each axis and check if these points lie inside the OBB

    return Math.abs(v1.dot(xAxis)) <= this.halfSize.x &&
        Math.abs(v1.dot(yAxis)) <= this.halfSize.y &&
        Math.abs(v1.dot(zAxis)) <= this.halfSize.z;
  }

  bool intersectsBox3(Box3 box3) {
    return this.intersectsOBB(obb.fromBox3(box3));
  }

  bool intersectsSphere(Sphere sphere) {
    // find the point on the OBB closest to the sphere center

    this.clampPoint(sphere.center, closestPoint);

    // if that point is inside the sphere, the OBB and sphere intersect

    return closestPoint.distanceToSquared(sphere.center) <=
        (sphere.radius * sphere.radius);
  }

  /**
	* Reference: OBB-OBB Intersection in Real-Time Collision Detection
	* by Christer Ericson (chapter 4.4.1)
	*
	*/
  bool intersectsOBB(OBB obb, {double epsilon = Math.epsilon}) {
    // prepare data structures (the code uses the same nomenclature like the reference)

    a.c = this.center;
    a.e[0] = this.halfSize.x;
    a.e[1] = this.halfSize.y;
    a.e[2] = this.halfSize.z;
    this.rotation.extractBasis(a.u[0], a.u[1], a.u[2]);

    b.c = obb.center;
    b.e[0] = obb.halfSize.x;
    b.e[1] = obb.halfSize.y;
    b.e[2] = obb.halfSize.z;
    obb.rotation.extractBasis(b.u[0], b.u[1], b.u[2]);

    // compute rotation matrix expressing b in a's coordinate frame

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        R[i][j] = a.u[i].dot(b.u[j]);
      }
    }

    // compute translation vector

    v1.subVectors(b.c!, a.c!);

    // bring translation into a's coordinate frame

    t[0] = v1.dot(a.u[0]);
    t[1] = v1.dot(a.u[1]);
    t[2] = v1.dot(a.u[2]);

    // compute common subexpressions. Add in an epsilon term to
    // counteract arithmetic errors when two edges are parallel and
    // their cross product is (near) null

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        AbsR[i][j] = Math.abs(R[i][j]) + epsilon;
      }
    }

    num ra, rb;

    // test axes L = A0, L = A1, L = A2

    for (int i = 0; i < 3; i++) {
      ra = a.e[i];
      rb = b.e[0] * AbsR[i][0] + b.e[1] * AbsR[i][1] + b.e[2] * AbsR[i][2];
      if (Math.abs(t[i]) > ra + rb) return false;
    }

    // test axes L = B0, L = B1, L = B2

    for (int i = 0; i < 3; i++) {
      ra = a.e[0] * AbsR[0][i] + a.e[1] * AbsR[1][i] + a.e[2] * AbsR[2][i];
      rb = b.e[i];
      if (Math.abs(t[0] * R[0][i] + t[1] * R[1][i] + t[2] * R[2][i]) > ra + rb)
        return false;
    }

    // test axis L = A0 x B0

    ra = a.e[1] * AbsR[2][0] + a.e[2] * AbsR[1][0];
    rb = b.e[1] * AbsR[0][2] + b.e[2] * AbsR[0][1];
    if (Math.abs(t[2] * R[1][0] - t[1] * R[2][0]) > ra + rb) return false;

    // test axis L = A0 x B1

    ra = a.e[1] * AbsR[2][1] + a.e[2] * AbsR[1][1];
    rb = b.e[0] * AbsR[0][2] + b.e[2] * AbsR[0][0];
    if (Math.abs(t[2] * R[1][1] - t[1] * R[2][1]) > ra + rb) return false;

    // test axis L = A0 x B2

    ra = a.e[1] * AbsR[2][2] + a.e[2] * AbsR[1][2];
    rb = b.e[0] * AbsR[0][1] + b.e[1] * AbsR[0][0];
    if (Math.abs(t[2] * R[1][2] - t[1] * R[2][2]) > ra + rb) return false;

    // test axis L = A1 x B0

    ra = a.e[0] * AbsR[2][0] + a.e[2] * AbsR[0][0];
    rb = b.e[1] * AbsR[1][2] + b.e[2] * AbsR[1][1];
    if (Math.abs(t[0] * R[2][0] - t[2] * R[0][0]) > ra + rb) return false;

    // test axis L = A1 x B1

    ra = a.e[0] * AbsR[2][1] + a.e[2] * AbsR[0][1];
    rb = b.e[0] * AbsR[1][2] + b.e[2] * AbsR[1][0];
    if (Math.abs(t[0] * R[2][1] - t[2] * R[0][1]) > ra + rb) return false;

    // test axis L = A1 x B2

    ra = a.e[0] * AbsR[2][2] + a.e[2] * AbsR[0][2];
    rb = b.e[0] * AbsR[1][1] + b.e[1] * AbsR[1][0];
    if (Math.abs(t[0] * R[2][2] - t[2] * R[0][2]) > ra + rb) return false;

    // test axis L = A2 x B0

    ra = a.e[0] * AbsR[1][0] + a.e[1] * AbsR[0][0];
    rb = b.e[1] * AbsR[2][2] + b.e[2] * AbsR[2][1];
    if (Math.abs(t[1] * R[0][0] - t[0] * R[1][0]) > ra + rb) return false;

    // test axis L = A2 x B1

    ra = a.e[0] * AbsR[1][1] + a.e[1] * AbsR[0][1];
    rb = b.e[0] * AbsR[2][2] + b.e[2] * AbsR[2][0];
    if (Math.abs(t[1] * R[0][1] - t[0] * R[1][1]) > ra + rb) return false;

    // test axis L = A2 x B2

    ra = a.e[0] * AbsR[1][2] + a.e[1] * AbsR[0][2];
    rb = b.e[0] * AbsR[2][1] + b.e[1] * AbsR[2][0];
    if (Math.abs(t[1] * R[0][2] - t[0] * R[1][2]) > ra + rb) return false;

    // since no separating axis is found, the OBBs must be intersecting

    return true;
  }

  /**
	* Reference: Testing Box Against Plane in Real-Time Collision Detection
	* by Christer Ericson (chapter 5.2.3)
	*/
  bool intersectsPlane(Plane plane) {
    this.rotation.extractBasis(xAxis, yAxis, zAxis);

    // compute the projection interval radius of this OBB onto L(t) = this->center + t * p.normal;

    final r = this.halfSize.x * Math.abs(plane.normal.dot(xAxis)) +
        this.halfSize.y * Math.abs(plane.normal.dot(yAxis)) +
        this.halfSize.z * Math.abs(plane.normal.dot(zAxis));

    // compute distance of the OBB's center from the plane

    final d = plane.normal.dot(this.center) - plane.constant;

    // Intersection occurs when distance d falls within [-r,+r] interval

    return Math.abs(d) <= r;
  }

  /**
	* Performs a ray/OBB intersection test and stores the intersection point
	* to the given 3D vector. If no intersection is detected, *null* is returned.
	*/
  intersectRay(Ray ray, Vector3 result) {
    // the idea is to perform the intersection test in the local space
    // of the OBB.

    this.getSize(size);
    aabb.setFromCenterAndSize(v1.set(0, 0, 0), size);

    // create a 4x4 transformation matrix

    matrix4FromRotationMatrix(obbmatrix, this.rotation);
    obbmatrix.setPositionFromVector3(this.center);

    // transform ray to the local space of the OBB

    inverse.copy(obbmatrix).invert();
    localRay.copy(ray).applyMatrix4(inverse);

    // perform ray <-> AABB intersection test

    if (localRay.intersectBox(aabb, result) != null) {
      // transform the intersection point back to world space

      return result.applyMatrix4(obbmatrix);
    } 
    else {
      return null;
    }
  }

  /**
	* Performs a ray/OBB intersection test. Returns either true or false if
	* there is a intersection or not.
	*/
  bool intersectsRay(Ray ray) {
    return this.intersectRay(ray, v1) != null;
  }

  OBB fromBox3(Box3 box3) {
    box3.getCenter(this.center);
    box3.getSize(this.halfSize).multiplyScalar(0.5);

    this.rotation.identity();

    return this;
  }

  bool equals(OBB obb) {
    return obb.center.equals(this.center) &&
        obb.halfSize.equals(this.halfSize) &&
        obb.rotation.equals(this.rotation);
  }

  OBB applyMatrix4(Matrix4 matrix) {
    final e = matrix.elements;

    double sx = v1.set(e[0], e[1], e[2]).length();
    final sy = v1.set(e[4], e[5], e[6]).length();
    final sz = v1.set(e[8], e[9], e[10]).length();

    final det = matrix.determinant();
    if (det < 0) sx = -sx;

    rotationMatrix.setFromMatrix4(matrix);

    final invSX = 1 / sx;
    final invSY = 1 / sy;
    final invSZ = 1 / sz;

    rotationMatrix.elements[0] *= invSX;
    rotationMatrix.elements[1] *= invSX;
    rotationMatrix.elements[2] *= invSX;

    rotationMatrix.elements[3] *= invSY;
    rotationMatrix.elements[4] *= invSY;
    rotationMatrix.elements[5] *= invSY;

    rotationMatrix.elements[6] *= invSZ;
    rotationMatrix.elements[7] *= invSZ;
    rotationMatrix.elements[8] *= invSZ;

    this.rotation.multiply(rotationMatrix);

    this.halfSize.x *= sx;
    this.halfSize.y *= sy;
    this.halfSize.z *= sz;

    v1.setFromMatrixPosition(matrix);
    this.center.add(v1);

    return this;
  }
}

void matrix4FromRotationMatrix(Matrix4 matrix4, Matrix3 matrix3) {
  final e = matrix4.elements;
  final me = matrix3.elements;

  e[0] = me[0];
  e[1] = me[1];
  e[2] = me[2];
  e[3] = 0;

  e[4] = me[3];
  e[5] = me[4];
  e[6] = me[5];
  e[7] = 0;

  e[8] = me[6];
  e[9] = me[7];
  e[10] = me[8];
  e[11] = 0;

  e[12] = 0;
  e[13] = 0;
  e[14] = 0;
  e[15] = 1;
}
