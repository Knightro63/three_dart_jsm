import 'package:three_dart/three3d/three.dart';
import 'face3.dart';
import 'direct_geometry.dart';

int _geometryId = 0; // Geometry uses even numbers as Id
final _geometrym1 = Matrix4();
final _geometryobj = Object3D();
final _geometryoffset = Vector3();

class Geometry with EventDispatcher {
  int id = _geometryId += 2;
  String uuid = MathUtils.generateUUID();
  String name = '';
  String type = 'Geometry';
  List<Vector3> vertices = [];
  List<Color> colors = [];
  List<Face3> faces = [];
  List<List<List<Vector2>>?> faceVertexUvs = [[]];
  List<MorphTarget> morphTargets = [];
  List<MorphNormals> morphNormals = [];
  List<Vector4> skinWeights = [];
  List<Vector4> skinIndices = [];
  List<double> lineDistances = [];
  Box3? boundingBox;
  Sphere? boundingSphere;

  // update flags

  bool elementsNeedUpdate = false;
  bool verticesNeedUpdate = false;
  bool uvsNeedUpdate = false;
  bool normalsNeedUpdate = false;
  bool colorsNeedUpdate = false;
  bool lineDistancesNeedUpdate = false;
  bool groupsNeedUpdate = false;

  bool isGeometry = true;
  bool isBufferGeometry = false;

  DirectGeometry? directGeometry;

  Map parameters = {};

  Geometry() {}

  Geometry applyMatrix4(Matrix4 matrix) {
    final normalMatrix = Matrix3().getNormalMatrix(matrix);

    for (int i = 0, il = this.vertices.length; i < il; i++) {
      final vertex = this.vertices[i];
      vertex.applyMatrix4(matrix);
    }

    for (int i = 0, il = this.faces.length; i < il; i++) {
      final face = this.faces[i];
      face.normal.applyMatrix3(normalMatrix).normalize();

      for (int j = 0, jl = face.vertexNormals.length; j < jl; j++) {
        face.vertexNormals[j].applyMatrix3(normalMatrix).normalize();
      }
    }

    if (this.boundingBox != null) {
      this.computeBoundingBox();
    }

    if (this.boundingSphere != null) {
      this.computeBoundingSphere();
    }

    this.verticesNeedUpdate = true;
    this.normalsNeedUpdate = true;

    return this;
  }

  Geometry rotateX(angle) {
    // rotate geometry around world x-axis

    _geometrym1.makeRotationX(angle);

    this.applyMatrix4(_geometrym1);

    return this;
  }

  Geometry rotateY(angle) {
    // rotate geometry around world y-axis

    _geometrym1.makeRotationY(angle);

    this.applyMatrix4(_geometrym1);

    return this;
  }

  Geometry rotateZ(angle) {
    // rotate geometry around world z-axis

    _geometrym1.makeRotationZ(angle);

    this.applyMatrix4(_geometrym1);

    return this;
  }

  Geometry translate(x, y, z) {
    // translate geometry

    _geometrym1.makeTranslation(x, y, z);

    this.applyMatrix4(_geometrym1);

    return this;
  }

  Geometry scale(x, y, z) {
    // scale geometry

    _geometrym1.makeScale(x, y, z);

    this.applyMatrix4(_geometrym1);

    return this;
  }

  Geometry lookAt(Vector3 vector) {
    _geometryobj.lookAt(vector);

    _geometryobj.updateMatrix();

    this.applyMatrix4(_geometryobj.matrix);

    return this;
  }

  Geometry fromBufferGeometry(geometry) {
    final scope = this;

    final index = geometry.index != null ? geometry.index : null;
    final attributes = geometry.attributes;

    if (attributes["position"] == null) {
      print('Geometry.fromBufferGeometry(): Position attribute required for conversion.');
      return this;
    }

    final position = attributes["position"];
    final normal = attributes["normal"];
    final color = attributes["color"];
    final uv = attributes["uv"];
    final uv2 = attributes["uv2"];

    if (uv2 != null) this.faceVertexUvs[1] = [];

    for (int i = 0; i < position.count; i++) {
      scope.vertices
          .add(Vector3().fromBufferAttribute(position, i));

      if (color != null) {
        scope.colors
            .add(Color(0, 0, 0).fromBufferAttribute(color, i));
      }
    }

    void addFace(int a, int b, int c, int? materialIndex) {
      List<Color> vertexColors = (color == null)
          ? []
          : [
              scope.colors[a].clone(),
              scope.colors[b].clone(),
              scope.colors[c].clone()
            ];

      List<Vector3> vertexNormals = (normal == null)
          ? []
          : [
              Vector3().fromBufferAttribute(normal, a),
              Vector3().fromBufferAttribute(normal, b),
              Vector3().fromBufferAttribute(normal, c)
            ];

      final face = Face3(a, b, c, vertexNormals, vertexColors, materialIndex ?? 0);

      scope.faces.add(face);

      if (uv != null) {
        scope.faceVertexUvs[0]?.add([
          Vector2().fromBufferAttribute(uv, a),
          Vector2().fromBufferAttribute(uv, b),
          Vector2().fromBufferAttribute(uv, c)
        ]);
      }

      if (uv2 != null) {
        scope.faceVertexUvs[1]?.add([
          Vector2().fromBufferAttribute(uv2, a),
          Vector2().fromBufferAttribute(uv2, b),
          Vector2().fromBufferAttribute(uv2, c)
        ]);
      }
    }

    final groups = geometry.groups;

    if (groups.length > 0) {
      for (int i = 0; i < groups.length; i++) {
        final group = groups[i];

        int start = group["start"];
        int count = group["count"];

        for (int j = start, jl = start + count; j < jl; j += 3) {
          if (index != null) {
            addFace(index.getX(j).toInt(), index.getX(j + 1).toInt(),
                index.getX(j + 2).toInt(), group["materialIndex"]);
          } else {
            addFace(j, j + 1, j + 2, group["materialIndex"]);
          }
        }
      }
    } 
    else {
      if (index != null) {
        for (int i = 0; i < index.count; i += 3) {
          addFace(index.getX(i), index.getX(i + 1), index.getX(i + 2), null);
        }
      } 
      else {
        for (int i = 0; i < position.count; i += 3) {
          addFace(i, i + 1, i + 2, null);
        }
      }
    }

    this.computeFaceNormals();

    if (geometry.boundingBox != null) {
      this.boundingBox = geometry.boundingBox.clone();
    }

    if (geometry.boundingSphere != null) {
      this.boundingSphere = geometry.boundingSphere.clone();
    }

    return this;
  }

  Geometry center() {
    this.computeBoundingBox();

    this.boundingBox!.getCenter(_geometryoffset).negate();

    this.translate(_geometryoffset.x, _geometryoffset.y, _geometryoffset.z);

    return this;
  }

  Geometry normalize() {
    this.computeBoundingSphere();

    final center = this.boundingSphere!.center;
    final radius = this.boundingSphere!.radius;

    final s = (radius == 0 ? 1 : 1.0 / radius).toDouble();

    final matrix = Matrix4();
    matrix.set(s, 0, 0, -s * center.x, 0, s, 0, -s * center.y, 0, 0, s,
        -s * center.z, 0, 0, 0, 1);

    this.applyMatrix4(matrix);

    return this;
  }

  void computeFaceNormals() {
    final cb = Vector3(), ab = Vector3();

    for (int f = 0, fl = this.faces.length; f < fl; f++) {
      final face = this.faces[f];

      final vA = this.vertices[face.a];
      final vB = this.vertices[face.b];
      final vC = this.vertices[face.c];

      cb.subVectors(vC, vB);
      ab.subVectors(vA, vB);
      cb.cross(ab);

      cb.normalize();

      face.normal.copy(cb);
    }
  }

  void computeVertexNormals({bool areaWeighted = true}) {
    final vertices = List<Vector3>.filled(
        this.vertices.length, Vector3(0, 0, 0));

    for (int v = 0, vl = this.vertices.length; v < vl; v++) {
      vertices[v] = Vector3();
    }

    if (areaWeighted) {
      // vertex normals weighted by triangle areas
      // http://www.iquilezles.org/www/articles/normals/normals.htm

      final cb = Vector3(), ab = Vector3();

      for (int f = 0, fl = this.faces.length; f < fl; f++) {
        final face = this.faces[f];

        final vA = this.vertices[face.a];
        final vB = this.vertices[face.b];
        final vC = this.vertices[face.c];

        cb.subVectors(vC, vB);
        ab.subVectors(vA, vB);
        cb.cross(ab);

        vertices[face.a].add(cb);
        vertices[face.b].add(cb);
        vertices[face.c].add(cb);
      }
    } else {
      this.computeFaceNormals();

      for (int f = 0, fl = this.faces.length; f < fl; f++) {
        final face = this.faces[f];

        vertices[face.a].add(face.normal);
        vertices[face.b].add(face.normal);
        vertices[face.c].add(face.normal);
      }
    }

    for (int v = 0, vl = this.vertices.length; v < vl; v++) {
      vertices[v].normalize();
    }

    for (int f = 0, fl = this.faces.length; f < fl; f++) {
      final face = this.faces[f];

      final vertexNormals = face.vertexNormals;

      if (vertexNormals.length == 3) {
        vertexNormals[0].copy(vertices[face.a]);
        vertexNormals[1].copy(vertices[face.b]);
        vertexNormals[2].copy(vertices[face.c]);
      } else {
        vertexNormals[0] = vertices[face.a].clone();
        vertexNormals[1] = vertices[face.b].clone();
        vertexNormals[2] = vertices[face.c].clone();
      }
    }

    if (this.faces.length > 0) {
      this.normalsNeedUpdate = true;
    }
  }

  void computeFlatVertexNormals() {
    this.computeFaceNormals();

    for (int f = 0, fl = this.faces.length; f < fl; f++) {
      final face = this.faces[f];

      final vertexNormals = face.vertexNormals;

      if (vertexNormals.length == 3) {
        vertexNormals[0].copy(face.normal);
        vertexNormals[1].copy(face.normal);
        vertexNormals[2].copy(face.normal);
      } else {
        vertexNormals[0] = face.normal.clone();
        vertexNormals[1] = face.normal.clone();
        vertexNormals[2] = face.normal.clone();
      }
    }

    if (this.faces.length > 0) {
      this.normalsNeedUpdate = true;
    }
  }

  void computeBoundingBox() {
    if (this.boundingBox == null) {
      this.boundingBox = Box3();
    }

    this.boundingBox!.setFromPoints(this.vertices);
  }

  void computeBoundingSphere() {
    if (this.boundingSphere == null) {
      this.boundingSphere = Sphere();
    }

    this.boundingSphere!.setFromPoints(this.vertices, null);
  }

  merge(Geometry? geometry, matrix, {int materialIndexOffset = 0}) {
    if (geometry == null && geometry!.isGeometry) {
      print('Geometry.merge(): geometry not an instance of Geometry. $geometry');
      return;
    }

    Matrix3? normalMatrix;
    final vertexOffset = this.vertices.length,
        vertices1 = this.vertices,
        vertices2 = geometry.vertices,
        faces1 = this.faces,
        faces2 = geometry.faces,
        colors1 = this.colors,
        colors2 = geometry.colors;

    if (matrix != null) {
      normalMatrix = Matrix3().getNormalMatrix(matrix);
    }

    // vertices

    for (int i = 0, il = vertices2.length; i < il; i++) {
      final vertex = vertices2[i];
      final vertexCopy = vertex.clone();

      if (matrix != null) vertexCopy.applyMatrix4(matrix);

      vertices1.add(vertexCopy);
    }

    // colors

    for (int i = 0, il = colors2.length; i < il; i++) {
      colors1.add(colors2[i].clone());
    }

    // faces

    for (int i = 0, il = faces2.length; i < il; i++) {
      final face = faces2[i];
      Vector3? normal;
      Color? color;
      final faceVertexNormals = face.vertexNormals,
          faceVertexColors = face.vertexColors;

      final faceCopy = Face3(face.a + vertexOffset, face.b + vertexOffset, face.c + vertexOffset);
      faceCopy.normal.copy(face.normal);

      if (normalMatrix != null) {
        faceCopy.normal.applyMatrix3(normalMatrix).normalize();
      }

      for (int j = 0, jl = faceVertexNormals.length; j < jl; j++) {
        normal = faceVertexNormals[j].clone();

        if (normalMatrix != null) {
          normal.applyMatrix3(normalMatrix).normalize();
        }

        faceCopy.vertexNormals.add(normal);
      }

      faceCopy.color.copy(face.color);

      for (int j = 0, jl = faceVertexColors.length; j < jl; j++) {
        color = faceVertexColors[j];
        faceCopy.vertexColors.add(color.clone());
      }

      faceCopy.materialIndex = face.materialIndex + materialIndexOffset;

      faces1.add(faceCopy);
    }

    // uvs

    for (int i = 0, il = geometry.faceVertexUvs.length; i < il; i++) {
      final faceVertexUvs2 = geometry.faceVertexUvs[i];

      if (this.faceVertexUvs[i] == null){
        this.faceVertexUvs[i] = [];
      }

      for (int j = 0, jl = faceVertexUvs2!.length; j < jl; j++) {
        final uvs2 = faceVertexUvs2[j];
        List<Vector2> uvsCopy = [];

        for (int k = 0, kl = uvs2.length; k < kl; k++) {
          uvsCopy.add(uvs2[k].clone());
        }

        this.faceVertexUvs[i]!.add(uvsCopy);
      }
    }
  }

  void mergeMesh( mesh) {
    if (!(mesh && mesh.isMesh)) {
      print(
          'Geometry.mergeMesh(): mesh not an instance of Mesh. ${mesh}');
      return;
    }

    if (mesh.matrixAutoUpdate) mesh.updateMatrix();

    this.merge(mesh.geometry, mesh.matrix);
  }

  /*
	 * Checks for duplicate vertices with hashmap.
	 * Duplicated vertices are removed
	 * and faces' vertices are updated.
	 */

  int mergeVertices({int precisionPoints = 4}) {
    final verticesMap =
        {}; // Hashmap for looking up vertices by position coordinates (and making sure they are unique)
    List<Vector3> unique = [];
    final changes = List.filled(this.vertices.length, 0);

    final precision = Math.pow(10, precisionPoints);

    for (int i = 0, il = this.vertices.length; i < il; i++) {
      final v = this.vertices[i];
      final key =
          '${Math.round(v.x * precision)}_${Math.round(v.y * precision)}_${Math.round(v.z * precision)}';

      if (verticesMap[key] == null) {
        verticesMap[key] = i;
        unique.add(this.vertices[i]);
        changes[i] = unique.length - 1;
      } else {
        //console.log('Duplicate vertex found. ', i, ' could be using ', verticesMap[key]);
        changes[i] = changes[verticesMap[key]];
      }
    }

    // if faces are completely degenerate after merging vertices, we
    // have to remove them from the geometry.
    final faceIndicesToRemove = [];

    for (int i = 0, il = this.faces.length; i < il; i++) {
      final face = this.faces[i];

      face.a = changes[face.a];
      face.b = changes[face.b];
      face.c = changes[face.c];

      final indices = [face.a, face.b, face.c];

      // if any duplicate vertices are found in a Face3
      // we have to remove the face as nothing can be saved
      for (int n = 0; n < 3; n++) {
        if (indices[n] == indices[(n + 1) % 3]) {
          faceIndicesToRemove.add(i);
          break;
        }
      }
    }

    for (int i = faceIndicesToRemove.length - 1; i >= 0; i--) {
      final idx = faceIndicesToRemove[i];

      this.faces.sublist(idx, idx + 1);

      for (int j = 0, jl = this.faceVertexUvs.length; j < jl; j++) {
        this.faceVertexUvs[j]?.sublist(idx, idx + 1);
      }
    }

    // Use unique set of vertices

    final diff = this.vertices.length - unique.length;
    this.vertices = unique;
    return diff;
  }

  Geometry setFromPoints(List<Vector> points) {
    this.vertices = [];

    for (int i = 0, l = points.length; i < l; i++) {
      final point = points[i];
      if(point is Vector3){
        this.vertices.add(Vector3(point.x, point.y, point.z));
      }
      else if(point is Vector4){
        this.vertices.add(Vector3(point.x, point.y, point.z));
      }
      else{
        this.vertices.add(Vector3(point.x, point.y, 0));
      }
    }

    return this;
  }

  Map<String,dynamic> toJSON() {
    Map<String, dynamic> data = {
      "metadata": {
        "version": 4.5,
        "type": 'Geometry',
        "generator": 'Geometry.toJSON'
      }
    };

    // standard Geometry serialization

    data["uuid"] = this.uuid;
    data["type"] = this.type;
    if (this.name != '') data["name"] = this.name;

    print(" Geometry tojson todo ");

    final vertices = [];

    for (int i = 0; i < this.vertices.length; i++) {
      final vertex = this.vertices[i];
      vertices.addAll([vertex.x, vertex.y, vertex.z]);
    }

    final faces = [];
    final normals = [];
    final normalsHash = {};
    final colors = [];
    final colorsHash = {};
    final uvs = [];
    final uvsHash = {};

    int setBit(int value, int position, bool enabled) {
      return enabled ? value | (1 << position) : value & (~(1 << position));
    }

    Map<String,dynamic> getNormalIndex(Vector3 normal) {
      final hash = normal.x.toString() + normal.y.toString() + normal.z.toString();

      if (normalsHash[hash] != null) {
        return normalsHash[hash];
      }

      normalsHash[hash] = normals.length / 3;
      normals.addAll([normal.x, normal.y, normal.z]);

      return normalsHash[hash];
    }

    Map<String,dynamic> getColorIndex(Color color) {
      final hash = color.r.toString() + color.g.toString() + color.b.toString();

      if (colorsHash[hash] != null) {
        return colorsHash[hash];
      }

      colorsHash[hash] = colors.length;
      colors.add(color.getHex());

      return colorsHash[hash];
    }

    Map<String,dynamic> getUvIndex(Vector2 uv) {
      final hash = uv.x.toString() + uv.y.toString();

      if (uvsHash[hash] != null) {
        return uvsHash[hash];
      }

      uvsHash[hash] = uvs.length / 2;
      uvs.addAll([uv.x, uv.y]);

      return uvsHash[hash];
    }

    for (int i = 0; i < this.faces.length; i++) {
      final face = this.faces[i];

      final hasMaterial = true;
      final hasFaceUv = false; // deprecated
      final hasFaceVertexUv = this.faceVertexUvs[0]?[i] != null;
      final hasFaceNormal = face.normal.length() > 0;
      final hasFaceVertexNormal = face.vertexNormals.length > 0;
      final hasFaceColor = face.color.r != 1 || face.color.g != 1 || face.color.b != 1;
      final hasFaceVertexColor = face.vertexColors.length > 0;

      int faceType = 0;

      faceType = setBit(faceType, 0, false); // isQuad
      faceType = setBit(faceType, 1, hasMaterial);
      faceType = setBit(faceType, 2, hasFaceUv);
      faceType = setBit(faceType, 3, hasFaceVertexUv);
      faceType = setBit(faceType, 4, hasFaceNormal);
      faceType = setBit(faceType, 5, hasFaceVertexNormal);
      faceType = setBit(faceType, 6, hasFaceColor);
      faceType = setBit(faceType, 7, hasFaceVertexColor);

      faces.add(faceType);
      faces.addAll([face.a, face.b, face.c]);
      faces.add(face.materialIndex);

      if (hasFaceVertexUv) {
        final faceVertexUvs = this.faceVertexUvs[0]![i];

        faces.addAll([
          getUvIndex(faceVertexUvs[0]),
          getUvIndex(faceVertexUvs[1]),
          getUvIndex(faceVertexUvs[2])
        ]);
      }

      if (hasFaceNormal) {
        faces.add(getNormalIndex(face.normal));
      }

      if (hasFaceVertexNormal) {
        final vertexNormals = face.vertexNormals;

        faces.addAll([
          getNormalIndex(vertexNormals[0]),
          getNormalIndex(vertexNormals[1]),
          getNormalIndex(vertexNormals[2])
        ]);
      }

      if (hasFaceColor) {
        faces.add(getColorIndex(face.color));
      }

      if (hasFaceVertexColor) {
        final vertexColors = face.vertexColors;

        faces.addAll([
          getColorIndex(vertexColors[0]),
          getColorIndex(vertexColors[1]),
          getColorIndex(vertexColors[2])
        ]);
      }
    }

    data["data"] = {};

    data["data"].vertices = vertices;
    data["data"].normals = normals;
    if (colors.length > 0) data["data"].colors = colors;
    if (uvs.length > 0)
      data["data"].uvs = [uvs]; // temporal backward compatibility
    data["data"].faces = faces;

    return data;
  }

  Geometry clone() {
    return Geometry().copy(this);
  }

  Geometry copy(Geometry source) {
    // reset

    this.vertices = [];
    this.colors = [];
    this.faces = [];
    this.faceVertexUvs = [[]];
    this.morphTargets = [];
    this.morphNormals = [];
    this.skinWeights = [];
    this.skinIndices = [];
    this.lineDistances = [];
    this.boundingBox = null;
    this.boundingSphere = null;

    // name

    this.name = source.name;

    // vertices

    final vertices = source.vertices;

    for (int i = 0, il = vertices.length; i < il; i++) {
      this.vertices.add(vertices[i].clone());
    }

    // colors

    final colors = source.colors;

    for (int i = 0, il = colors.length; i < il; i++) {
      this.colors.add(colors[i].clone());
    }

    // faces

    final faces = source.faces;

    for (int i = 0, il = faces.length; i < il; i++) {
      this.faces.add(faces[i].clone());
    }

    // face vertex uvs

    for (int i = 0, il = source.faceVertexUvs.length; i < il; i++) {
      final faceVertexUvs = source.faceVertexUvs[i];

      if (this.faceVertexUvs[i] == null) {
        this.faceVertexUvs[i] = [];
      }

      for (int j = 0, jl = faceVertexUvs!.length; j < jl; j++) {
        List<Vector2> uvs = faceVertexUvs[j];
        List<Vector2> uvsCopy = [];

        for (int k = 0, kl = uvs.length; k < kl; k++) {
          final uv = uvs[k];

          uvsCopy.add(uv.clone());
        }

        this.faceVertexUvs[i]?.add(uvsCopy);
      }
    }

    // morph targets

    final morphTargets = source.morphTargets;

    for (int i = 0, il = morphTargets.length; i < il; i++) {
      final morphTarget = MorphTarget(null);
      morphTarget.name = morphTargets[i].name;

      // vertices

      if (morphTargets[i].vertices != null) {
        morphTarget.vertices = [];

        for (int j = 0, jl = morphTargets[i].vertices!.length; j < jl; j++) {
          morphTarget.vertices!.add(morphTargets[i].vertices![j].clone());
        }
      }

      // normals

      if (morphTargets[i].normals != null) {
        morphTarget.normals = [];

        for (int j = 0, jl = morphTargets[i].normals!.length; j < jl; j++) {
          morphTarget.normals!.add(morphTargets[i].normals![j].clone());
        }
      }

      this.morphTargets.add(morphTarget);
    }

    // morph normals

    final morphNormals = source.morphNormals;

    for (int i = 0, il = morphNormals.length; i < il; i++) {
      final morphNormal = MorphNormals();

      // vertex normals

      if (morphNormals[i].vertexNormals != null) {
        morphNormal.vertexNormals = [];

        for (int j = 0, jl = morphNormals[i].vertexNormals!.length;j < jl;j++) {
          final srcVertexNormal = morphNormals[i].vertexNormals![j];

          Face3 destVertexNormal = Face3(0,0,0);

          destVertexNormal.a = srcVertexNormal.a;//.clone();
          destVertexNormal.b = srcVertexNormal.b;//.clone();
          destVertexNormal.c = srcVertexNormal.c;//.clone();

          morphNormal.vertexNormals!.add(destVertexNormal);
        }
      }

      // face normals

      if (morphNormals[i].faceNormals != null) {
        morphNormal.faceNormals = [];

        for (int j = 0, jl = morphNormals[i].faceNormals!.length; j < jl; j++) {
          morphNormal.faceNormals!.add(morphNormals[i].faceNormals![j].clone());
        }
      }

      this.morphNormals.add(morphNormal);
    }

    // skin weights

    final skinWeights = source.skinWeights;

    for (int i = 0, il = skinWeights.length; i < il; i++) {
      this.skinWeights.add(skinWeights[i].clone());
    }

    // skin indices

    final skinIndices = source.skinIndices;

    for (int i = 0, il = skinIndices.length; i < il; i++) {
      this.skinIndices.add(skinIndices[i].clone());
    }

    // line distances

    final lineDistances = source.lineDistances;

    for (int i = 0, il = lineDistances.length; i < il; i++) {
      this.lineDistances.add(lineDistances[i]);
    }

    // bounding box

    final boundingBox = source.boundingBox;

    if (boundingBox != null) {
      this.boundingBox = boundingBox.clone();
    }

    // bounding sphere

    final boundingSphere = source.boundingSphere;

    if (boundingSphere != null) {
      this.boundingSphere = boundingSphere.clone();
    }

    // update flags

    this.elementsNeedUpdate = source.elementsNeedUpdate;
    this.verticesNeedUpdate = source.verticesNeedUpdate;
    this.uvsNeedUpdate = source.uvsNeedUpdate;
    this.normalsNeedUpdate = source.normalsNeedUpdate;
    this.colorsNeedUpdate = source.colorsNeedUpdate;
    this.lineDistancesNeedUpdate = source.lineDistancesNeedUpdate;
    this.groupsNeedUpdate = source.groupsNeedUpdate;

    return this;
  }

  void dispose() {
    this.dispatchEvent(Event(type: "dispose"));
  }

  static BufferGeometry createBufferGeometryFromObject(object) {
    BufferGeometry buffergeometry = BufferGeometry();

    final geometry = object.geometry;

    if (object.isPoints || object.isLine) {
      final positions = Float32BufferAttribute(
          geometry.vertices.length * 3, 3, false);
      final colors = Float32BufferAttribute(
          geometry.colors.length * 3, 3, false);

      buffergeometry.setAttribute(
          'position', positions.copyVector3sArray(geometry.vertices));
      buffergeometry.setAttribute(
          'color', colors.copyColorsArray(geometry.colors));

      if (geometry.lineDistances &&
          geometry.lineDistances.length == geometry.vertices.length) {
        final lineDistances = Float32BufferAttribute(
            geometry.lineDistances.length, 1, false);

        buffergeometry.setAttribute(
            'lineDistance', lineDistances.copyArray(geometry.lineDistances));
      }

      if (geometry.boundingSphere != null) {
        buffergeometry.boundingSphere = geometry.boundingSphere.clone();
      }

      if (geometry.boundingBox != null) {
        buffergeometry.boundingBox = geometry.boundingBox.clone();
      }
    } 
    else if (object.isMesh) {
      buffergeometry = geometry.toBufferGeometry();
    }

    return buffergeometry;
  }
}

class MorphTarget {
  late String name;
  late List<Vector3>? vertices;
  late List<Vector3>? normals;

  MorphTarget(Map<String, dynamic>? json) {
    if (json != null) {
      if (json["name"] != null) name = json["name"];
      if (json["vertices"] != null) vertices = json["vertices"];
      if (json["normals"] != null) normals = json["normals"];
    }
  }
}

class MorphColor {
  late String name;
  late List<Color> colors;
}

class MorphNormals {
  late String name;
  late List<Vector3> normals;
  late List<Face3>? vertexNormals;
  late List<Vector3>? faceNormals;
}
