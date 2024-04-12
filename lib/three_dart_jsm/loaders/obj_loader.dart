import 'dart:async';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';
import 'mtl_loader.dart';

// o object_name | g group_name
final _object_pattern = RegExp("^[og]\s*(.+)?");
// mtllib file_reference
final _material_library_pattern = RegExp("^mtllib ");
// usemtl material_name
final _material_use_pattern = RegExp("^usemtl ");
// usemap map_name
final _map_use_pattern = RegExp("^usemap ");

final _vA = Vector3();
final _vB = Vector3();
final _vC = Vector3();

final _ab = Vector3();
final _cb = Vector3();

class ParseStateMaterial {
  late dynamic index;
  late dynamic name;
  late dynamic mtllib;
  late dynamic smooth;
  late int groupStart;
  late int groupEnd;
  late int groupCount;
  late dynamic inherited;

  ParseStateMaterial(Map<String, dynamic> options) {
    index = options["index"];
    name = options["name"];
    mtllib = options["mtllib"];
    smooth = options["smooth"];
    groupStart = options["groupStart"] ?? 0;
    groupEnd = options["groupEnd"] ?? 0;
    groupCount = options["groupCount"] ?? 0;
    inherited = options["inherited"];
  }

  ParseStateMaterial clone(index) {
    final cloned = ParseStateMaterial({
      "index": (index is num ? index : this.index),
      "name": this.name,
      "mtllib": this.mtllib,
      "smooth": this.smooth,
      "groupStart": 0,
      "groupEnd": -1,
      "groupCount": -1,
      "inherited": false
    });

    return cloned;
  }
}

class ParseStateObject {
  String name = "";
  bool fromDeclaration = false;
  List materials = [];
  Map<String, dynamic> geometry = {
    "vertices": [],
    "normals": [],
    "colors": [],
    "uvs": [],
    "hasUVIndices": false
  };
  bool smooth = true;

  ParseStateObject(Map<String, dynamic> options) {
    name = options["name"];
    fromDeclaration = options["fromDeclaration"];
  }

  ParseStateMaterial startMaterial(String? name, libraries) {
    final ParseStateMaterial? previous = this._finalize(false);

    // New usemtl declaration overwrites an inherited material, except if faces were declared
    // after the material, then it must be preserved for proper MultiMaterial continuation.
    if (previous != null && (previous.inherited || previous.groupCount <= 0)) {
      splice(this.materials, previous.index, 1);
    }

    final material = ParseStateMaterial({
      "index": this.materials.length,
      "name": name ?? '',
      "mtllib": (libraries is List && libraries.length > 0
          ? libraries[libraries.length - 1]
          : ''),
      "smooth": (previous != null ? previous.smooth : this.smooth),
      "groupStart": (previous != null ? previous.groupEnd : 0),
      "groupEnd": -1,
      "groupCount": -1,
      "inherited": false
    });

    this.materials.add(material);

    return material;
  }

  ParseStateMaterial? currentMaterial() {
    if (this.materials.length > 0) {
      return this.materials[this.materials.length - 1];
    }

    return null;
  }

  ParseStateMaterial? _finalize(bool end) {
    final ParseStateMaterial? lastMultiMaterial = this.currentMaterial();
    if (lastMultiMaterial != null && lastMultiMaterial.groupEnd == -1) {
      lastMultiMaterial.groupEnd = this.geometry["vertices"]!.length ~/ 3;
      lastMultiMaterial.groupCount =
          lastMultiMaterial.groupEnd - lastMultiMaterial.groupStart;
      lastMultiMaterial.inherited = false;
    }

    // Ignore objects tail materials if no face declarations followed them before a o/g started.
    if (end && this.materials.length > 1) {
      for (int mi = this.materials.length - 1; mi >= 0; mi--) {
        if (this.materials[mi].groupCount <= 0) {
          splice(this.materials, mi, 1);
        }
      }
    }

    // Guarantee at least one empty material, this makes the creation later more straight forward.
    if (end && this.materials.length == 0) {
      this
          .materials
          .add(ParseStateMaterial({"name": '', "smooth": this.smooth}));
    }

    return lastMultiMaterial;
  }
}

class ParserState {
  final objects = [];
  ParseStateObject? object;

  List<double> vertices = [];
  List<double> normals = [];
  List<double> colors = [];
  List<double> uvs = [];

  final materials = {};
  final materialLibraries = [];

  ParserState() {
    startObject("", false);
  }

  void startObject(String? name, bool? fromDeclaration) {
    // print(" startObject name: ${name} fromDeclaration: ${fromDeclaration} ");
    // print(" startObject object: ${this.object} this.object.fromDeclaration: ${this.object?.fromDeclaration} ");
    // If the current object (initial from reset) is not from a g/o declaration in the parsed
    // file. We need to use it for the first parsed g/o to keep things in sync.
    if (this.object != null && this.object!.fromDeclaration == false) {
      this.object!.name = name ?? '';
      this.object!.fromDeclaration = (fromDeclaration != false);
      return;
    }

    final previousMaterial =
        this.object != null ? this.object!.currentMaterial() : null;

    if (this.object != null) {
      this.object!._finalize(true);
    }

    this.object = ParseStateObject({
      "name": name ?? '',
      "fromDeclaration": (fromDeclaration != false),
    });

    // Inherit previous objects material.
    // Spec tells us that a declared material must be set to all objects until a material is declared.
    // If a usemtl declaration is encountered while this object is being parsed, it will
    // overwrite the inherited material. Exception being that there was already face declarations
    // to the inherited material, then it will be preserved for proper MultiMaterial continuation.

    if (previousMaterial != null && previousMaterial.name != null) {
      final declared = previousMaterial.clone(0);
      declared.inherited = true;
      this.object!.materials.add(declared);
    }

    this.objects.add(this.object);
  }

  void finalize() {
    if (this.object != null) {
      this.object!._finalize(true);
    }
  }

  int parseVertexIndex(String value, int len) {
    final int index = int.parse(value, radix: 10);
    return (index >= 0 ? index - 1 : index + len ~/ 3) * 3;
  }

  int parseNormalIndex(String value, int len) {
    final index = int.parse(value, radix: 10);
    return (index >= 0 ? index - 1 : index + len ~/ 3) * 3;
  }

  int parseUVIndex(String value, int len) {
    final index = int.parse(value, radix: 10);
    return (index >= 0 ? index - 1 : index + len ~/ 2) * 2;
  }

  void addVertex(int a, int b, int c) {
    final src = this.vertices;
    final dst = this.object!.geometry["vertices"];

    dst.addAll([src[a + 0], src[a + 1], src[a + 2]]);
    dst.addAll([src[b + 0], src[b + 1], src[b + 2]]);
    dst.addAll([src[c + 0], src[c + 1], src[c + 2]]);
  }

  void addVertexPoint(int a) {
    final src = this.vertices;
    final dst = this.object!.geometry["vertices"];

    dst.addAll([src[a + 0], src[a + 1], src[a + 2]]);
  }

  void addVertexLine(int a) {
    final src = this.vertices;
    final dst = this.object!.geometry["vertices"];

    dst.addAll([src[a + 0], src[a + 1], src[a + 2]]);
  }

  void addNormal(int a, int b, int c) {
    final src = this.normals;
    final dst = this.object!.geometry["normals"];

    dst.addAll([src[a + 0], src[a + 1], src[a + 2]]);
    dst.addAll([src[b + 0], src[b + 1], src[b + 2]]);
    dst.addAll([src[c + 0], src[c + 1], src[c + 2]]);
  }

  void addFaceNormal(int a, int b, int c) {
    final src = this.vertices;
    final dst = this.object!.geometry["normals"];

    _vA.fromArray(src, a);
    _vB.fromArray(src, b);
    _vC.fromArray(src, c);

    _cb.subVectors(_vC, _vB);
    _ab.subVectors(_vA, _vB);
    _cb.cross(_ab);

    _cb.normalize();

    dst.addAll([_cb.x, _cb.y, _cb.z]);
    dst.addAll([_cb.x, _cb.y, _cb.z]);
    dst.addAll([_cb.x, _cb.y, _cb.z]);
  }

  void addColor(int a, [int? b, int? c]) {
    final src = this.colors;
    final dst = this.object!.geometry["colors"];

    if (src.length > a && src[a] != null) dst.addAll([src[a + 0], src[a + 1], src[a + 2]]);
    if (b != null && src.length > b && src[b] != null)
      dst.addAll([src[b + 0], src[b + 1], src[b + 2]]);
    if (c != null && src.length > c && src[c] != null)
      dst.addAll([src[c + 0], src[c + 1], src[c + 2]]);
  }

  void addUV(int a, int b, int c) {
    final src = this.uvs;
    final dst = this.object!.geometry["uvs"];

    dst.addAll([src[a + 0], src[a + 1]]);
    dst.addAll([src[b + 0], src[b + 1]]);
    dst.addAll([src[c + 0], src[c + 1]]);
  }

  void addDefaultUV() {
    final dst = this.object!.geometry["uvs"];

    dst.addAll([0, 0]);
    dst.addAll([0, 0]);
    dst.addAll([0, 0]);
  }

  void addUVLine(int a) {
    final src = this.uvs;
    final dst = this.object!.geometry["uvs"];

    dst.addAll([src[a + 0], src[a + 1]]);
  }

  void addFace(String a, String b, String c, String? ua, String? ub, String? uc, String? na, String? nb, String? nc) {
    final vLen = this.vertices.length;

    int ia = this.parseVertexIndex(a, vLen);
    int ib = this.parseVertexIndex(b, vLen);
    int ic = this.parseVertexIndex(c, vLen);

    this.addVertex(ia, ib, ic);
    this.addColor(ia, ib, ic);

    // normals

    if (na != null && na != '') {
      final nLen = this.normals.length;

      ia = this.parseNormalIndex(na, nLen);
      ib = this.parseNormalIndex(nb!, nLen);
      ic = this.parseNormalIndex(nc!, nLen);

      this.addNormal(ia, ib, ic);
    } else {
      this.addFaceNormal(ia, ib, ic);
    }

    // uvs

    if (ua != null && ua != '') {
      final uvLen = this.uvs.length;

      ia = this.parseUVIndex(ua, uvLen);
      ib = this.parseUVIndex(ub!, uvLen);
      ic = this.parseUVIndex(uc!, uvLen);

      this.addUV(ia, ib, ic);

      this.object!.geometry["hasUVIndices"] = true;
    } else {
      // add placeholder values (for inconsistent face definitions)

      this.addDefaultUV();
    }
  }

  void addPointGeometry(List<String> vertices) {
    this.object!.geometry["type"] = 'Points';

    final vLen = this.vertices.length;

    for (int vi = 0, l = vertices.length; vi < l; vi++) {
      final index = this.parseVertexIndex(vertices[vi], vLen);

      this.addVertexPoint(index);
      this.addColor(index, null, null);
    }
  }

  void addLineGeometry(List<String> vertices,List<String> uvs) {
    this.object!.geometry["type"] = 'Line';

    final vLen = this.vertices.length;
    final uvLen = this.uvs.length;

    for (int vi = 0, l = vertices.length; vi < l; vi++) {
      this.addVertexLine(this.parseVertexIndex(vertices[vi], vLen));
    }

    for (int uvi = 0, l = uvs.length; uvi < l; uvi++) {
      this.addUVLine(this.parseUVIndex(uvs[uvi], uvLen));
    }
  }
}

//

class OBJLoader extends Loader {
  MaterialCreator? materials;

  OBJLoader([manager]):super(manager) {}

  loadAsync(url) async {
    final completer = Completer();

    load(url, (buffer) {
      completer.complete(buffer);
    });

    return completer.future;
  }

  load(url, Function onLoad, [Function? onProgress, Function? onError]) {
    final scope = this;

    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setRequestHeader(this.requestHeader);
    loader.setWithCredentials(this.withCredentials);
    loader.load(url, (text) async {
      // try {

      onLoad(await scope.parse(text));

      // } catch ( e ) {

      // 	if ( onError != null ) {

      // 		onError( e );

      // 	} else {

      // 		print( e );

      // 	}

      // 	scope.manager.itemError( url );

      // }
    }, onProgress, onError);
  }

  OBJLoader setMaterials(MaterialCreator? materials) {
    this.materials = materials;

    return this;
  }

  Future<Group> parse(String text, [String? path, Function? onLoad, Function? onError]) async {
    final state = ParserState();

    if (text.indexOf('\r\n') != -1) {
      // This is faster than String.split with regex that splits on both
      text = text.replaceAll(RegExp("\r\n", multiLine: true), '\n');
    }

    if (text.indexOf('\\\n') != -1) {
      // join lines separated by a line continuation character (\)
      text = text.replaceAll(RegExp("\\\n"), '');
    }

    List<String> lines = text.split('\n');
    String line = '', lineFirstChar = '';
    int lineLength = 0;

    // Faster to just trim left side of the line. Use if available.

    for (int i = 0, l = lines.length; i < l; i++) {
      line = lines[i];

      line = line.trimLeft();

      // print("i: ${i} line: ${line} ");

      lineLength = line.length;

      if (lineLength == 0) continue;

      lineFirstChar = line[0];

      // @todo invoke passed in handler if any
      if (lineFirstChar == '#') continue;

      if (lineFirstChar == 'v') {
        final data = line.split(RegExp(r"\s+"));

        switch (data[0]) {
          case 'v':
            state.vertices.addAll([
              parseFloat(data[1]),
              parseFloat(data[2]),
              parseFloat(data[3])
            ]);
            if (data.length >= 7) {
              state.colors.addAll([
                parseFloat(data[4]),
                parseFloat(data[5]),
                parseFloat(data[6])
              ]);
            } else {
              // if no colors are defined, add placeholders so color and vertex indices match
              state.colors.addAll([]);
            }

            break;
          case 'vn':
            state.normals.addAll([
              parseFloat(data[1]),
              parseFloat(data[2]),
              parseFloat(data[3])
            ]);
            break;
          case 'vt':
            state.uvs.addAll([parseFloat(data[1]), parseFloat(data[2])]);
            break;
        }
      } else if (lineFirstChar == 'f') {
        final lineData = line.substring(1).trim();
        final vertexData = lineData.split(RegExp(r"\s+"));
        List<List> faceVertices = [];

        // Parse the face vertex data into an easy to work with format

        // print(" lineFirstChar is f .................. ");
        // print(vertexData);

        for (int j = 0, jl = vertexData.length; j < jl; j++) {
          final vertex = vertexData[j];

          if (vertex.length > 0) {
            final vertexParts = vertex.split('/');
            faceVertices.add(vertexParts);
          }
        }

        // Draw an edge between the first vertex and all subsequent vertices to form an n-gon

        final v1 = faceVertices[0];

        for (int j = 1, jl = faceVertices.length - 1; j < jl; j++) {
          final v2 = faceVertices[j];
          final v3 = faceVertices[j + 1];

          state.addFace(
              v1[0],
              v2[0],
              v3[0],
              v1.length > 1 ? v1[1] : null,
              v2.length > 1 ? v2[1] : null,
              v3.length > 1 ? v3[1] : null,
              v1.length > 2 ? v1[2] : null,
              v2.length > 2 ? v2[2] : null,
              v3.length > 2 ? v3[2] : null);
        }
      } else if (lineFirstChar == 'l') {
        final lineParts = line.substring(1).trim().split(' ');
        List<String> lineVertices = [];
        List<String> lineUVs = [];

        if (line.indexOf('/') == -1) {
          lineVertices = lineParts;
        } 
        else {
          for (int li = 0, llen = lineParts.length; li < llen; li++) {
            final parts = lineParts[li].split('/');

            if (parts[0] != '') lineVertices.add(parts[0]);
            if (parts[1] != '') lineUVs.add(parts[1]);
          }
        }

        state.addLineGeometry(lineVertices, lineUVs);
      } 
      else if (lineFirstChar == 'p') {
        final lineData = line.substring(1).trim();
        final pointData = lineData.split(' ');

        state.addPointGeometry(pointData);
      } 
      else if (_object_pattern.hasMatch(line)) {
        List<RegExpMatch> result = _object_pattern.allMatches(line).toList();

        // o object_name
        // or
        // g group_name

        // WORKAROUND: https://bugs.chromium.org/p/v8/issues/detail?id=2869
        // final name = result[ 0 ].substr( 1 ).trim();
        final name = (' ' + (result[0].group(0)?.substring(1).trim() ?? '')).substring(1);

        state.startObject(name, null);
      } 
      else if (_material_use_pattern.hasMatch(line)) {
        // material

        state.object!
            .startMaterial(line.substring(7).trim(), state.materialLibraries);
      } 
      else if (_material_library_pattern.hasMatch(line)) {
        // mtl file

        state.materialLibraries.add(line.substring(7).trim());
      } 
      else if (_map_use_pattern.hasMatch(line)) {
        // the line is parsed but ignored since the loader assumes textures are defined MTL files
        // (according to https://www.okino.com/conv/imp_wave.htm, 'usemap' is the old-style Wavefront texture reference method)

        print(
            'THREE.OBJLoader: Rendering identifier "usemap" not supported. Textures must be defined in MTL files.');
      } 
      else if (lineFirstChar == 's') {
        List<String> result = line.split(' ');

        // smooth shading

        // @todo Handle files that have varying smooth values for a set of faces inside one geometry,
        // but does not define a usemtl for each face set.
        // This should be detected and a dummy material created (later MultiMaterial and geometry groups).
        // This requires some care to not create extra material on each smooth value for "normal" obj files.
        // where explicit usemtl defines geometry groups.
        // Example asset: examples/models/obj/cerberus/Cerberus.obj

        /*
					 * http://paulbourke.net/dataformats/obj/
					 * or
					 * http://www.cs.utah.edu/~boulos/cs3505/obj_spec.pdf
					 *
					 * From chapter "Grouping" Syntax explanation "s group_number":
					 * "group_number is the smoothing group number. To turn off smoothing groups, use a value of 0 or off.
					 * Polygonal elements use group numbers to put elements in different smoothing groups. For free-form
					 * surfaces, smoothing groups are either turned on or off; there is no difference between values greater
					 * than 0."
					 */
        if (result.length > 1) {
          final value = result[1].trim().toLowerCase();
          state.object!.smooth = (value != '0' && value != 'off');
        } 
        else {
          // ZBrush can produce "s" lines #11707
          state.object!.smooth = true;
        }

        final material = state.object!.currentMaterial();
        if (material != null) material.smooth = state.object!.smooth;
      } 
      else {
        // Handle null terminated files without exception
        if (line == '\0') continue;

        print('THREE.OBJLoader: Unexpected line: "' + line + '"');
      }
    }

    state.finalize();

    final container = Group();
    // container.materialLibraries = [].concat( state.materialLibraries );

    final hasPrimitives = !(state.objects.length == 1 &&
        state.objects[0].geometry["vertices"].length == 0);

    if (hasPrimitives == true) {
      for (int i = 0, l = state.objects.length; i < l; i++) {
        final object = state.objects[i];
        final geometry = object.geometry;
        final materials = object.materials;
        final isLine = (geometry["type"] == 'Line');
        final isPoints = (geometry["type"] == 'Points');
        bool hasVertexColors = false;

        // Skip o/g line declarations that did not follow with any faces
        if (geometry["vertices"].length == 0) continue;

        final buffergeometry = BufferGeometry();

        buffergeometry.setAttribute(
            'position', Float32BufferAttribute(Float32Array.fromList( List<double>.from(geometry["vertices"]) ), 3));

        if (geometry["normals"].length > 0) {
          buffergeometry.setAttribute(
              'normal', Float32BufferAttribute(Float32Array.fromList( List<double>.from(geometry["normals"]) ), 3));
        }

        if (geometry["colors"].length > 0) {
          hasVertexColors = true;
          buffergeometry.setAttribute(
              'color', Float32BufferAttribute(Float32Array.fromList( List<double>.from(geometry["colors"])), 3));
        }

        if (geometry["hasUVIndices"] == true) {
          buffergeometry.setAttribute(
              'uv', Float32BufferAttribute(Float32Array.fromList( List<double>.from(geometry["uvs"])), 2));
        }

        // Create materials
        final gm = GroupMaterial();
        final createdMaterials = gm.children = [];

        for (int mi = 0, miLen = materials.length; mi < miLen; mi++) {
          final sourceMaterial = materials[mi];
          final materialHash = sourceMaterial.name +
              '_' +
              "${sourceMaterial.smooth}" +
              '_' +
              "${hasVertexColors}";
          Material? material = state.materials[materialHash];

          if (this.materials != null) {
            material = await this.materials!.create(sourceMaterial.name);

            // mtl etc. loaders probably can't create line materials correctly, copy properties to a line material.
            if (isLine && material != null && !(material is LineBasicMaterial)) {
              final materialLine = LineBasicMaterial({});
              materialLine.copy(material);
              // Material.prototype.copy.call( materialLine, material );
              materialLine.color.copy(material.color);
              material = materialLine;
            } else if (isPoints && material != null && !(material is PointsMaterial)) {
              final materialPoints =
                  PointsMaterial({"size": 10, "sizeAttenuation": false});
              // Material.prototype.copy.call( materialPoints, material );
              materialPoints.copy(material);
              materialPoints.color.copy(material.color);
              materialPoints.map = material.map;
              material = materialPoints;
            }
          }

          if (material == null) {
            if (isLine) {
              material = LineBasicMaterial({});
            } else if (isPoints) {
              material =
                  PointsMaterial({"size": 1, "sizeAttenuation": false});
            } else {
              material = MeshPhongMaterial();
            }

            material?.name = sourceMaterial.name;
            material?.flatShading = sourceMaterial.smooth ? false : true;
            material?.vertexColors = hasVertexColors;

            state.materials[materialHash] = material;
          }

          createdMaterials.add(material!);
        }

        // Create mesh
        final mesh;

        if (createdMaterials.length > 1) {
          for (int mi = 0, miLen = materials.length; mi < miLen; mi++) {
            final sourceMaterial = materials[mi];
            buffergeometry.addGroup(sourceMaterial.groupStart.toInt(),
                sourceMaterial.groupCount.toInt(),
                mi);
          }

          if (isLine) {
            mesh = LineSegments(buffergeometry, gm);
          } else if (isPoints) {
            mesh = Points(buffergeometry, gm);
          } else {
            mesh = Mesh(buffergeometry, gm);
          }
        } else {
          if (isLine) {
            mesh = LineSegments(buffergeometry, createdMaterials[0]);
          } else if (isPoints) {
            mesh = Points(buffergeometry, createdMaterials[0]);
          } else {
            mesh = Mesh(buffergeometry, createdMaterials[0]);
          }
        }

        mesh.name = object.name;

        container.add(mesh);
      }
    } else {
      // if there is only the default parser state object with no geometry data, interpret data as point cloud

      if (state.vertices.length > 0) {
        final material =
            PointsMaterial({"size": 1, "sizeAttenuation": false});

        final buffergeometry = BufferGeometry();

        buffergeometry.setAttribute(
            'position', Float32BufferAttribute(Float32Array.fromList(state.vertices), 3));

        if (state.colors.length > 0 && state.colors[0] != null) {
          buffergeometry.setAttribute(
              'color', Float32BufferAttribute(Float32Array.fromList(state.colors), 3));
          material.vertexColors = true;
        }

        final points = Points(buffergeometry, material);
        container.add(points);
      }
    }

    return container;
  }
}
