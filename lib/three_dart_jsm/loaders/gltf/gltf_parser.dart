import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';
import 'gltf_mesh_standard_sg_material.dart';
import 'gltf_helper.dart';
import 'gltf_cubic_spline_interpolant.dart';
import 'gltf_registry.dart';

/* GLTF PARSER */

class GLTFData{
  GLTFData({
    required this.scene,
    required this.scenes,
    this.animations,
    this.cameras,
    this.userData,
    this.asset,
    required this.parser
  });

  Object3D scene;
  List scenes;
  List? animations;
  List? cameras;
  dynamic asset;
  Map? userData;
  GLTFParser parser;
}

class GLTFParser {
  late FileLoader fileLoader;
  late Map<String, dynamic> json;
  late dynamic extensions;
  late Map plugins;
  late Map<String, dynamic> options;
  late GLTFRegistry cache;
  late Map associations;
  late Map primitiveCache;
  late Map<String,dynamic> meshCache;
  late Map<String,dynamic> cameraCache;
  late Map lightCache;
  late Map nodeNamesUsed;
  late TextureLoader textureLoader;

  Function? createNodeAttachment;
  Function? extendMaterialParams;
  Function? loadBufferView;

  late Map textureCache;
  late Map sourceCache;

  GLTFParser(Map<String, dynamic>? json, Map<String, dynamic>? options) {
    this.json = json ?? {};
    this.extensions = {};
    this.plugins = {};
    this.options = options ?? {};

    // loader object cache
    this.cache = GLTFRegistry();

    this.textureCache = {};
    this.sourceCache = {};

    // associations between Three.js objects and glTF elements
    this.associations = Map();

    // BufferGeometry caching
    this.primitiveCache = {};

    // Object3D instance caches
    this.meshCache = {"refs": {}, "uses": {}};
    this.cameraCache = {"refs": {}, "uses": {}};
    this.lightCache = {"refs": {}, "uses": {}};

    // Track node names, to ensure no duplicates
    this.nodeNamesUsed = {};

    // Use an ImageBitmapLoader if imageBitmaps are supported. Moves much of the
    // expensive work of uploading a texture to the GPU off the main thread.
    // if ( createImageBitmap != null && /Firefox/.test( navigator.userAgent ) == false ) {
    //   this.textureLoader = ImageBitmapLoader( this.options.manager );
    // } else {
    this.textureLoader = TextureLoader(this.options["manager"]);
    // }

    this.textureLoader.setCrossOrigin(this.options["crossOrigin"]);
    this.textureLoader.setRequestHeader(this.options["requestHeader"]);

    this.fileLoader = FileLoader(this.options["manager"]);
    this.fileLoader.setResponseType('arraybuffer');

    if (this.options["crossOrigin"] == 'use-credentials') {
      this.fileLoader.setWithCredentials(true);
    }

    this.loadBufferView = loadBufferView2;
  }

  void setExtensions(extensions) {
    this.extensions = extensions;
  }

  void setPlugins(plugins) {
    this.plugins = plugins;
  }

  Future<void> parse(onLoad, onError) async {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;

    // Clear the loader cache
    this.cache.removeAll();

    // Mark the special nodes/meshes in json for efficient parse
    this._invokeAll((ext) {
      print(ext);
      return ext.markDefs != null && ext.markDefs() != null;
    });

    final _scenes = await this.getDependencies('scene');
    final _animations = await this.getDependencies('animation');
    final _cameras = await this.getDependencies('camera');

    final result = GLTFData(
      scene: _scenes[json["scene"] ?? 0],
      scenes: _scenes,
      animations: _animations as List?,
      cameras: _cameras as List?,
      asset: json["asset"],
      parser: parser,
      userData: {}
    );

    addUnknownExtensionsToUserData(extensions, result, json);

    assignExtrasToUserData(result, json);

    onLoad(result);
  }

  /**
   * Marks the special nodes/meshes in json for efficient parse.
   */
  void markDefs() {
    final nodeDefs = this.json["nodes"] ?? [];
    final skinDefs = this.json["skins"] ?? [];
    final meshDefs = this.json["meshes"] ?? [];

    // Nothing in the node definition indicates whether it is a Bone or an
    // Object3D. Use the skins' joint references to mark bones.
    for (int skinIndex = 0, skinLength = skinDefs.length;
        skinIndex < skinLength;
        skinIndex++) {
      final joints = skinDefs[skinIndex]["joints"];

      for (int i = 0, il = joints.length; i < il; i++) {
        nodeDefs[joints[i]]["isBone"] = true;
      }
    }

    // Iterate over all nodes, marking references to shared resources,
    // as well as skeleton joints.
    for (int nodeIndex = 0, nodeLength = nodeDefs.length;
        nodeIndex < nodeLength;
        nodeIndex++) {
      Map<String, dynamic> nodeDef = nodeDefs[nodeIndex];

      if (nodeDef["mesh"] != null) {
        this.addNodeRef(this.meshCache, nodeDef["mesh"]);

        // Nothing in the mesh definition indicates whether it is
        // a SkinnedMesh or Mesh. Use the node's mesh reference
        // to mark SkinnedMesh if node has skin.
        if (nodeDef["skin"] != null) {
          meshDefs[nodeDef["mesh"]]["isSkinnedMesh"] = true;
        }
      }

      if (nodeDef["camera"] != null) {
        this.addNodeRef(this.cameraCache, nodeDef["camera"]);
      }
    }
  }

  /**
   * Counts references to shared node / Object3D resources. These resources
   * can be reused, or "instantiated", at multiple nodes in the scene
   * hierarchy. Mesh, Camera, and Light instances are instantiated and must
   * be marked. Non-scenegraph resources (like Materials, Geometries, and
   * Textures) can be reused directly and are not marked here.
   *
   * Example: CesiumMilkTruck sample model reuses "Wheel" meshes.
   */
  void addNodeRef(Map<String,dynamic> cache, int? index) {
    if (index == null) return;

    if (cache["refs"][index] == null) {
      cache["refs"][index] = cache["uses"][index] = 0;
    }

    cache["refs"][index]++;
  }

  /** Returns a reference to a shared resource, cloning it if necessary. */
  getNodeRef(Map<String,dynamic> cache, int index, object) {
    if (cache["refs"][index] == null || cache["refs"][index] <= 1) return object;

    final ref = object.clone();

    ref.name += '_instance_${(cache["uses"][index]++)}';

    return ref;
  }

  Future _invokeOne(Function func) async {
    final extensions = this.plugins.values.toList();
    extensions.add(this);

    for (int i = 0; i < extensions.length; i++) {
      final result = await func(extensions[i]);
      if (result != null) return result;
    }
  }

  Future<List> _invokeAll(Function func) async {
    final extensions = this.plugins.values.toList();
    unshift(extensions, this);

    final results = [];

    for (int i = 0; i < extensions.length; i++) {
      final result = await func(extensions[i]);

      if (result != null) results.add(result);
    }

    return results;
  }

  /**
   * Requests the specified dependency asynchronously, with caching.
   * @param {string} type
   * @param {number} index
   * @return {Promise<Object3D|Material|THREE.Texture|AnimationClip|ArrayBuffer|Object>}
   */
  getDependency(String type, int index) async {
    final cacheKey = '${type}:${index}';
    dynamic dependency = this.cache.get(cacheKey);

    // print(" GLTFParse.getDependency type: ${type} index: ${index} ");

    if (dependency == null) {
      switch (type) {
        case 'scene':
          dependency = await this.loadScene(index);
          break;

        case 'node':
          dependency = await this.loadNode(index);
          break;

        case 'mesh':
          dependency = await this._invokeOne((ext) async {
            return ext.loadMesh != null ? await ext.loadMesh(index) : null;
          });
          break;

        case 'accessor':
          dependency = await this.loadAccessor(index);
          break;

        case 'bufferView':
          dependency = await this._invokeOne((ext) async {
            return ext.loadBufferView != null
                ? await ext.loadBufferView(index)
                : null;
          });

          break;

        case 'buffer':
          dependency = await this.loadBuffer(index);
          break;

        case 'material':
          dependency = await this._invokeOne((ext) async {
            return ext.loadMaterial != null
                ? await ext.loadMaterial(index)
                : null;
          });
          break;

        case 'texture':
          dependency = await this._invokeOne((ext) async {
            return ext.loadTexture != null
                ? await ext.loadTexture(index)
                : null;
          });
          break;

        case 'skin':
          dependency = await this.loadSkin(index);
          break;

        case 'animation':
          dependency = await this.loadAnimation(index);
          break;

        case 'camera':
          dependency = await this.loadCamera(index);
          break;

        default:
          throw ('GLTFParser getDependency Unknown type: ${type}');
      }

      this.cache.add(cacheKey, dependency);
    }

    return dependency;
  }

  /**
   * Requests all dependencies of the specified type asynchronously, with caching.
   * @param {string} type
   * @return {Promise<Array<Object>>}
   */
  Future<List> getDependencies(String type) async {
    final dependencies = this.cache.get(type);

    if (dependencies != null) {
      return dependencies;
    }

    final parser = this;
    final defs = this.json[type + (type == 'mesh' ? 'es' : 's')] ?? [];

    List _dependencies = [];

    int l = defs.length;

    for (int i = 0; i < l; i++) {
      final _dep = await parser.getDependency(type, i);
      _dependencies.add(_dep);
    }

    this.cache.add(type, _dependencies);

    return _dependencies;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
   * @param {number} bufferIndex
   * @return {Promise<ArrayBuffer>}
   */
  loadBuffer(int bufferIndex) async {
    Map<String, dynamic> bufferDef = this.json["buffers"][bufferIndex];
    final loader = this.fileLoader;

    if (bufferDef["type"] != null && bufferDef["type"] != 'arraybuffer') {
      throw ('THREE.GLTFLoader: ${bufferDef["type"]} buffer type is not supported.');
    }

    // If present, GLB container is required to be the first buffer.
    if (bufferDef["uri"] == null && bufferIndex == 0) {
      return this.extensions[extensions["KHR_BINARY_GLTF"]].body;
    }

    final options = this.options;

    final _url = LoaderUtils.resolveURL(bufferDef["uri"], options["path"]);

    final res = await loader.loadAsync(_url);

    return res;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
   * @param {number} bufferViewIndex
   * @return {Promise<ArrayBuffer>}
   */
  loadBufferView2(int bufferViewIndex) async {
    final bufferViewDef = this.json["bufferViews"][bufferViewIndex];
    final buffer = await this.getDependency('buffer', bufferViewDef["buffer"]);

    final byteLength = bufferViewDef["byteLength"] ?? 0;
    final byteOffset = bufferViewDef["byteOffset"] ?? 0;

    // use sublist(0) clone list, if not when load texture decode image will fail ? and with no error, return null image
    final _buffer;
    if (buffer is Uint8List) {
      _buffer = Uint8List.view(buffer.buffer, byteOffset, byteLength)
          .sublist(0)
          .buffer;
    } else {
      _buffer =
          Uint8List.view(buffer, byteOffset, byteLength).sublist(0).buffer;
    }

    return _buffer;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#accessors
   * @param {number} accessorIndex
   * @return {Promise<BufferAttribute|InterleavedBufferAttribute>}
   */
  loadAccessor(accessorIndex) async {
    final parser = this;
    final json = this.json;

    Map<String, dynamic> accessorDef = this.json["accessors"][accessorIndex];

    if (accessorDef["bufferView"] == null && accessorDef["sparse"] == null) {
      // Ignore empty accessors, which may be used to declare runtime
      // information about attributes coming from another source (e.g. Draco
      // compression extension).
      return null;
    }

    final bufferView;
    if (accessorDef["bufferView"] != null) {
      bufferView =
          await this.getDependency('bufferView', accessorDef["bufferView"]);
    } else {
      bufferView = null;
    }

    dynamic sparseIndicesBufferView;
    dynamic sparseValuesBufferView;

    if (accessorDef["sparse"] != null) {
      final _sparse = accessorDef["sparse"];
      sparseIndicesBufferView = await this
          .getDependency('bufferView', _sparse["indices"]["bufferView"]);
      sparseValuesBufferView = await this
          .getDependency('bufferView', _sparse["values"]["bufferView"]);
    }

    int itemSize = WEBGL_TYPE_SIZES[accessorDef["type"]]!;
    final typedArray = GLTypeData(accessorDef["componentType"]);

    // For VEC3: itemSize is 3, elementBytes is 4, itemBytes is 12.
    final elementBytes = typedArray.getBytesPerElement() ?? 0;
    final itemBytes = elementBytes * itemSize;
    final byteOffset = accessorDef["byteOffset"] ?? 0;
    final int? byteStride = accessorDef["bufferView"] != null
        ? json["bufferViews"][accessorDef["bufferView"]]["byteStride"]
        : null;
    final normalized = accessorDef["normalized"] == true;
    List<double> array;
    dynamic bufferAttribute;

    // The buffer is not interleaved if the stride is the item size in bytes.
    if (byteStride != null && byteStride != itemBytes) {
      // Each "slice" of the buffer, as defined by 'count' elements of 'byteStride' bytes, gets its own InterleavedBuffer
      // This makes sure that IBA.count reflects accessor.count properly
      final ibSlice = Math.floor(byteOffset / byteStride);
      final ibCacheKey =
          'InterleavedBuffer:${accessorDef["bufferView"]}:${accessorDef["componentType"]}:${ibSlice}:${accessorDef["count"]}';
      dynamic ib = parser.cache.get(ibCacheKey);

      if (ib == null) {
        // array = TypedArray.view( bufferView, ibSlice * byteStride, accessorDef.count * byteStride / elementBytes );
        array = typedArray.view(bufferView, ibSlice * byteStride,
            accessorDef["count"] * byteStride / elementBytes);

        // Integer parameters to IB/IBA are in array elements, not bytes.
        ib = InterleavedBuffer(Float32Array.fromList(array), byteStride ~/ elementBytes);

        parser.cache.add(ibCacheKey, ib);
      }

      bufferAttribute = InterleavedBufferAttribute(
          ib, itemSize, (byteOffset % byteStride) / elementBytes, normalized);
    } else {
      if (bufferView == null) {
        array = typedArray.createList(accessorDef["count"] * itemSize);
        bufferAttribute =
          GLTypeData.createBufferAttribute(array, itemSize, normalized);
      } else {
        final _array = typedArray.view(
            bufferView, byteOffset, accessorDef["count"] * itemSize);
        bufferAttribute =
          GLTypeData.createBufferAttribute(_array, itemSize, normalized);
      }
    }

    // https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#sparse-accessors
    if (accessorDef["sparse"] != null) {
      final itemSizeIndices = WEBGL_TYPE_SIZES["SCALAR"]!;
      final typedArrayIndices =
          GLTypeData(accessorDef["sparse"]["indices"]["componentType"]);

      final byteOffsetIndices =
          accessorDef["sparse"]["indices"]["byteOffset"] ?? 0;
      final byteOffsetValues = accessorDef["sparse"]["values"]["byteOffset"] ?? 0;

      final sparseIndices = typedArrayIndices.view(sparseIndicesBufferView,
          byteOffsetIndices, accessorDef["sparse"]["count"] * itemSizeIndices);
      final sparseValues = typedArray.view(sparseValuesBufferView,
          byteOffsetValues, accessorDef["sparse"]["count"] * itemSize);

      if (bufferView != null) {
        // Avoid modifying the original ArrayBuffer, if the bufferView wasn't initialized with zeroes.
        bufferAttribute = Float32BufferAttribute(bufferAttribute.array.clone(),
            bufferAttribute.itemSize, bufferAttribute.normalized);
      }

      for (int i = 0, il = sparseIndices.length; i < il; i++) {
        final index = sparseIndices[i];

        bufferAttribute.setX(index, sparseValues[i * itemSize]);
        if (itemSize >= 2)
          bufferAttribute.setY(index, sparseValues[i * itemSize + 1]);
        if (itemSize >= 3)
          bufferAttribute.setZ(index, sparseValues[i * itemSize + 2]);
        if (itemSize >= 4)
          bufferAttribute.setW(index, sparseValues[i * itemSize + 3]);
        if (itemSize >= 5)
          throw ('THREE.GLTFLoader: Unsupported itemSize in sparse BufferAttribute.');
      }
    }

    return bufferAttribute;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#textures
   * @param {number} textureIndex
   * @return {Promise<THREE.Texture>}
   */
  Future<Texture> loadTexture(textureIndex) async {
    final parser = this;
    Map<String, dynamic> json = this.json;
    final options = this.options;

    Map<String, dynamic> textureDef = json["textures"][textureIndex];
    final sourceIndex = textureDef["source"];
    final sourceDef = json["images"][sourceIndex];

    final textureExtensions = textureDef["extensions"] ?? {};

    // final source;

    // if (textureExtensions[extensions["MSFT_TEXTURE_DDS"]] != null) {
    //   source = json["images"]
    //       [textureExtensions[extensions["MSFT_TEXTURE_DDS"]]["source"]];
    // } else {
    //   source = json["images"][textureDef["source"]];
    // }

    dynamic loader;

    if (sourceDef["uri"] != null) {
      loader = options["manager"].getHandler(sourceDef["uri"]);
    }

    if (loader == null) {
      loader = textureExtensions[extensions["MSFT_TEXTURE_DDS"]] != null
          ? parser.extensions[extensions["MSFT_TEXTURE_DDS"]]["ddsLoader"]
          : this.textureLoader;
    }

    return this.loadTextureImage(textureIndex, sourceIndex, loader);
  }

  Future<Texture> loadTextureImage(textureIndex, sourceIndex, loader) async {
    // print(" GLTFParser.loadTextureImage source: ${source} textureIndex: ${textureIndex} loader: ${loader} ");

    final parser = this;
    final json = this.json;

    Map textureDef = json["textures"][textureIndex];
    Map sourceDef = json["images"][sourceIndex];

    // final URL = self.URL || self.webkitURL;

    final cacheKey =
        '${(sourceDef["uri"] ?? sourceDef["bufferView"])}:${textureDef["sampler"]}';

    if (this.textureCache[cacheKey] != null) {
      // See https://github.com/mrdoob/three.js/issues/21559.
      return this.textureCache[cacheKey];
    }


    loader.flipY = false;
    Texture texture = await this.loadImageSource(sourceIndex, loader);

    texture.flipY = false;

    if (textureDef["name"] != null) texture.name = textureDef["name"];

    final samplers = json["samplers"] ?? {};
    Map sampler = samplers[textureDef["sampler"]] ?? {};

    texture.magFilter = WEBGL_FILTERS[sampler["magFilter"]] ?? LinearFilter;
    texture.minFilter =
        WEBGL_FILTERS[sampler["minFilter"]] ?? LinearMipmapLinearFilter;
    texture.wrapS = WEBGL_WRAPPINGS[sampler["wrapS"]] ?? RepeatWrapping;
    texture.wrapT = WEBGL_WRAPPINGS[sampler["wrapT"]] ?? RepeatWrapping;

    parser.associations[texture] = {"textures": textureIndex};

    this.textureCache[cacheKey] = texture;

    return texture;
  }

  Future<Texture> loadImageSource(sourceIndex, TextureLoader loader) async {
    final parser = this;
    final json = this.json;
    final options = this.options;
    Texture? texture;

    if (this.sourceCache[sourceIndex] != null) {
      texture = this.sourceCache[sourceIndex];
      return texture!.clone();
    }

    Map sourceDef = json["images"][sourceIndex];

    // final URL = self.URL || self.webkitURL;

    String? sourceURI = sourceDef["uri"];
    //bool isObjectURL = false;

    print("loader: ${loader} ");

    if (sourceDef["bufferView"] != null) {
      // Load binary image data from bufferView, if provided.

      final bufferView = await parser.getDependency('bufferView', sourceDef["bufferView"]);

      //isObjectURL = true;
      final blob = Blob(bufferView.asUint8List(), {"type": sourceDef["mimeType"]});
      // sourceURI = URL.createObjectURL( blob );

      texture = await loader.fromBlob(blob);
    }
    else if (sourceURI != null) {
      final String resolve = LoaderUtils.resolveURL(sourceURI, options["path"]);
      if(resolve.startsWith('assets') || resolve.startsWith('packages')){
        texture = await loader.fromAsset(resolve);
      }
      else{//if(resolve.contains("https")){
        texture = await loader.fromNetwork(resolve);
      }
    } 
    else if (sourceURI == null) {
      throw ('THREE.GLTFLoader: Image ' +
          sourceIndex +
          ' is missing URI and bufferView');
    }

    this.sourceCache[sourceIndex] = texture;
    return texture!;
  }

  /**
   * Asynchronously assigns a texture to the given material parameters.
   * @param {Object} materialParams
   * @param {string} mapName
   * @param {Object} mapDef
   * @return {Promise}
   */
  Future<Texture> assignTexture(materialParams, mapName, Map<String, dynamic> mapDef, [encoding]) async {
    final parser = this;

    Texture texture = await this.getDependency('texture', mapDef["index"]);

    // Materials sample aoMap from UV set 1 and other maps from UV set 0 - this can't be configured
    // However, we will copy UV set 0 to UV set 1 on demand for aoMap
    if (mapDef["texCoord"] != null &&
        mapDef["texCoord"] != 0 &&
        !(mapName == 'aoMap' && mapDef["texCoord"] == 1)) {
      print(
          'THREE.GLTFLoader: Custom UV set ${mapDef["texCoord"]} for texture ${mapName} not yet supported.');
    }

    if (parser.extensions[extensions["KHR_TEXTURE_TRANSFORM"]] != null) {
      final transform = mapDef["extensions"] != null
          ? mapDef["extensions"][extensions["KHR_TEXTURE_TRANSFORM"]]
          : null;

      if (transform != null) {
        final gltfReference = parser.associations[texture];
        texture = parser.extensions[extensions["KHR_TEXTURE_TRANSFORM"]]
            .extendTexture(texture, transform);
        parser.associations[texture] = gltfReference;
      }
    }


    if ( encoding != null ) {

      texture.encoding = encoding;

    }

    materialParams[mapName] = texture;

    return texture;
  }

  /**
   * Assigns final material to a Mesh, Line, or Points instance. The instance
   * already has a material (generated from the glTF material options alone)
   * but reuse of the same glTF material may require multiple threejs materials
   * to accomodate different primitive types, defines, etc. New materials will
   * be created if necessary, and reused from a cache.
   * @param  {Object3D} mesh Mesh, Line, or Points instance.
   */
  void assignFinalMaterial(Mesh mesh) {
    final geometry = mesh.geometry;
    Material material = mesh.material;

    bool useVertexTangents = geometry?.attributes["tangent"] != null;
    bool useVertexColors = geometry?.attributes["color"] != null;
    bool useFlatShading = geometry?.attributes["normal"] == null;

    if (mesh is Points) {
      final cacheKey = 'PointsMaterial:' + material.uuid;

      PointsMaterial? pointsMaterial = this.cache.get(cacheKey);

      if (pointsMaterial == null) {
        pointsMaterial = PointsMaterial();
        pointsMaterial.copy(material);
        pointsMaterial.color.copy(material.color);
        pointsMaterial.map = material.map;
        pointsMaterial.sizeAttenuation =
            false; // glTF spec says points should be 1px

        this.cache.add(cacheKey, pointsMaterial);
      }

      material = pointsMaterial;
    } else if (mesh is Line) {
      final cacheKey = 'LineBasicMaterial:' + material.uuid;

      LineBasicMaterial? lineMaterial = this.cache.get(cacheKey);

      if (lineMaterial == null) {
        lineMaterial = LineBasicMaterial();
        lineMaterial.copy(material);
        lineMaterial.color.copy(material.color);

        this.cache.add(cacheKey, lineMaterial);
      }

      material = lineMaterial;
    }

    // Clone the material if it will be modified
    if (useVertexTangents || useVertexColors || useFlatShading) {
      String cacheKey = 'ClonedMaterial:' + material.uuid + ':';

      if (material.type == "GLTFSpecularGlossinessMaterial")
        cacheKey += 'specular-glossiness:';
      if (useVertexTangents) cacheKey += 'vertex-tangents:';
      if (useVertexColors) cacheKey += 'vertex-colors:';
      if (useFlatShading) cacheKey += 'flat-shading:';

      Material? cachedMaterial = this.cache.get(cacheKey);

      if (cachedMaterial == null) {
        cachedMaterial = material.clone();

        if (useVertexTangents) cachedMaterial.vertexTangents = true;
        if (useVertexColors) cachedMaterial.vertexColors = true;
        if (useFlatShading) cachedMaterial.flatShading = true;

        this.cache.add(cacheKey, cachedMaterial);

        this.associations[cachedMaterial] = this.associations[material];
      }

      material = cachedMaterial;
    }

    // workarounds for mesh and geometry

    if (material.aoMap != null &&
        geometry?.attributes["uv2"] == null &&
        geometry?.attributes["uv"] != null) {
      geometry?.setAttribute('uv2', geometry.attributes["uv"]);
    }

    // https://github.com/mrdoob/three.js/issues/11438#issuecomment-507003995
    if (material.normalScale != null && !useVertexTangents) {
      material.normalScale!.y = -material.normalScale!.y;
    }

    if (material.clearcoatNormalScale != null && !useVertexTangents) {
      material.clearcoatNormalScale!.y = -material.clearcoatNormalScale!.y;
    }

    mesh.material = material;
  }

  Type getMaterialType(int materialIndex) {
    return MeshStandardMaterial;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#materials
   * @param {number} materialIndex
   * @return {Promise<Material>}
   */
  Future<Material> loadMaterial(materialIndex) async {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;
    Map<String, dynamic> materialDef = json["materials"][materialIndex];

    final materialType;
    Map<String, dynamic> materialParams = {};
    Map<String, dynamic> materialExtensions = materialDef["extensions"] ?? {};

    List pending = [];

    if (materialExtensions[
            extensions["KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS"]] !=
        null) {
      final sgExtension =
          extensions[extensions["KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS"]];
      materialType = sgExtension.getMaterialType(materialIndex);
      pending
          .add(sgExtension.extendParams(materialParams, materialDef, parser));
    } else if (materialExtensions[extensions["KHR_MATERIALS_UNLIT"]] != null) {
      final kmuExtension = extensions[extensions["KHR_MATERIALS_UNLIT"]];
      materialType = kmuExtension.getMaterialType(materialIndex);
      pending
          .add(kmuExtension.extendParams(materialParams, materialDef, parser));
    } else {
      // Specification:
      // https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#metallic-roughness-material

      Map<String, dynamic> metallicRoughness =
          materialDef["pbrMetallicRoughness"] ?? {};

      materialParams["color"] = Color(1.0, 1.0, 1.0);
      materialParams["opacity"] = 1.0;

      if (metallicRoughness["baseColorFactor"] is List) {
        List<double> array = List<double>.from(metallicRoughness["baseColorFactor"].map((e) => e.toDouble()));

        materialParams["color"].fromArray(array);
        materialParams["opacity"] = array[3];
      }

      if (metallicRoughness["baseColorTexture"] != null) {
        pending.add(await parser.assignTexture(
            materialParams, 'map', metallicRoughness["baseColorTexture"], sRGBEncoding));
      }

      materialParams["metalness"] = metallicRoughness["metallicFactor"] != null
          ? metallicRoughness["metallicFactor"]
          : 1.0;
      materialParams["roughness"] = metallicRoughness["roughnessFactor"] != null
          ? metallicRoughness["roughnessFactor"]
          : 1.0;

      if (metallicRoughness["metallicRoughnessTexture"] != null) {
        pending.add(await parser.assignTexture(materialParams, 'metalnessMap',
            metallicRoughness["metallicRoughnessTexture"]));
        pending.add(await parser.assignTexture(materialParams, 'roughnessMap',
            metallicRoughness["metallicRoughnessTexture"]));
      }

      materialType = await this._invokeOne((ext) async {
        return ext.getMaterialType != null
            ? await ext.getMaterialType(materialIndex)
            : null;
      });

      final _v = await this._invokeAll((ext) {
        return ext.extendMaterialParams != null &&
            ext.extendMaterialParams(materialIndex, materialParams) != null;
      });

      pending.add(_v);
    }

    if (materialDef["doubleSided"] == true) {
      materialParams["side"] = DoubleSide;
    }

    final alphaMode = materialDef["alphaMode"] ?? ALPHA_MODES["OPAQUE"];

    if (alphaMode == ALPHA_MODES["BLEND"]) {
      materialParams["transparent"] = true;

      // See: https://github.com/mrdoob/three.js/issues/17706
      materialParams["depthWrite"] = false;
    } else {
      materialParams["transparent"] = false;

      if (alphaMode == ALPHA_MODES["MASK"]) {
        materialParams["alphaTest"] = materialDef["alphaCutoff"] != null
            ? materialDef["alphaCutoff"]
            : 0.5;
      }
    }

    if (materialDef["normalTexture"] != null &&
        materialType != MeshBasicMaterial) {
      pending.add(await parser.assignTexture(
          materialParams, 'normalMap', materialDef["normalTexture"]));

      if (materialDef["normalTexture"]["scale"] != null) {
        materialParams["normalScale"] = Vector2(
            materialDef["normalTexture"].scale,
            materialDef["normalTexture"].scale);
      }
    }

    if (materialDef["occlusionTexture"] != null &&
        materialType != MeshBasicMaterial) {
      pending.add(await parser.assignTexture(
          materialParams, 'aoMap', materialDef["occlusionTexture"]));

      if (materialDef["occlusionTexture"]["strength"] != null) {
        materialParams["aoMapIntensity"] =
            materialDef["occlusionTexture"]["strength"];
      }
    }

    if (materialDef["emissiveFactor"] != null &&
        materialType != MeshBasicMaterial) {
      materialParams["emissive"] =
          Color(1, 1, 1).fromArray(List<double>.from(materialDef["emissiveFactor"].map((e) => e.toDouble())));
    }

    if (materialDef["emissiveTexture"] != null &&
        materialType != MeshBasicMaterial) {
      pending.add(await parser.assignTexture(
          materialParams, 'emissiveMap', materialDef["emissiveTexture"], sRGBEncoding));
    }

    // await Future.wait(pending);

    final material;

    if (materialType == GLTFMeshStandardSGMaterial) {
      material = extensions[extensions["KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS"]]
          .createMaterial(materialParams);
    } else {
      material = createMaterialType(materialType, materialParams);
    }

    if (materialDef["name"] != null) material.name = materialDef["name"];

    assignExtrasToUserData(material, materialDef);

    parser.associations[material] = {
      "type": 'materials',
      "index": materialIndex
    };

    if (materialDef["extensions"] != null)
      addUnknownExtensionsToUserData(extensions, material, materialDef);

    return material;
  }

  Material createMaterialType(materialType, Map<String, dynamic> materialParams) {
    if (materialType == GLTFMeshStandardSGMaterial) {
      return GLTFMeshStandardSGMaterial(materialParams);
    } else if (materialType == MeshBasicMaterial) {
      return MeshBasicMaterial(materialParams);
    } else if (materialType == MeshPhysicalMaterial) {
      return MeshPhysicalMaterial(materialParams);
    } else if (materialType == MeshStandardMaterial) {
      return MeshStandardMaterial(materialParams);
    } else {
      throw ("GLTFParser createMaterialType materialType: ${materialType.runtimeType.toString()} is not support ");
    }
  }

  /** When Object3D instances are targeted by animation, they need unique names. */
  String createUniqueName(String? originalName) {
    final sanitizedName = PropertyBinding.sanitizeNodeName(originalName ?? '');

    String name = sanitizedName;

    for (int i = 1; this.nodeNamesUsed[name] != null; ++i) {
      name = '${sanitizedName}_${i}';
    }

    this.nodeNamesUsed[name] = true;

    return name;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#geometry
   *
   * Creates BufferGeometries from primitives.
   *
   * @param {Array<GLTF.Primitive>} primitives
   * @return {Promise<Array<BufferGeometry>>}
   */
  Future<List<BufferGeometry>> loadGeometries(primitives) async {
    final parser = this;
    final extensions = this.extensions;
    final cache = this.primitiveCache;

    Function createDracoPrimitive = (primitive) async {
      final geometry = await extensions[extensions["KHR_DRACO_MESH_COMPRESSION"]]
          .decodePrimitive(primitive, parser);
      return await addPrimitiveAttributes(geometry, primitive, parser);
    };

    List<BufferGeometry> pending = [];

    for (int i = 0, il = primitives.length; i < il; i++) {
      Map<String, dynamic> primitive = primitives[i];
      final cacheKey = createPrimitiveKey(primitive);

      // See if we've already created this geometry
      final cached = cache[cacheKey];

      if (cached != null) {
        // Use the cached geometry if it exists
        pending.add(cached.promise);
      } else {
        final geometryPromise;

        if (primitive["extensions"] != null &&
            primitive["extensions"][extensions["KHR_DRACO_MESH_COMPRESSION"]] !=
                null) {
          // Use DRACO geometry if available
          geometryPromise = await createDracoPrimitive(primitive);
        } else {
          // Otherwise create a geometry
          geometryPromise = await addPrimitiveAttributes(
              BufferGeometry(), primitive, parser);
        }

        // Cache this geometry
        cache[cacheKey] = {"primitive": primitive, "promise": geometryPromise};

        pending.add(geometryPromise);
      }
    }

    return pending;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#meshes
   * @param {number} meshIndex
   * @return {Promise<Group|Mesh|SkinnedMesh>}
   */
  Future<Object3D> loadMesh(int meshIndex) async {
    final parser = this;
    final json = this.json;
    final extensions = this.extensions;

    Map<String, dynamic> meshDef = json["meshes"][meshIndex];
    final primitives = meshDef["primitives"];

    List<Future> pending = [];

    for (int i = 0, il = primitives.length; i < il; i++) {
      final material = primitives[i]["material"] == null
          ? createDefaultMaterial(this.cache)
          : await this.getDependency('material', primitives[i]["material"]);

      pending.add(Future.sync(() => material));
    }

    pending.add(parser.loadGeometries(primitives));

    final results = await Future.wait(pending);

    final materials = slice(results, 0, results.length - 1);
    final geometries = results[results.length - 1];

    final meshes = [];

    for (int i = 0, il = geometries.length; i < il; i++) {
      final geometry = geometries[i];
      Map<String, dynamic> primitive = primitives[i];

      // 1. create Mesh

      final mesh;

      final material = materials[i];

      if (primitive["mode"] == webgl_constants["TRIANGLES"] ||
          primitive["mode"] == webgl_constants["TRIANGLE_STRIP"] ||
          primitive["mode"] == webgl_constants["TRIANGLE_FAN"] ||
          primitive["mode"] == null) {
        // .isSkinnedMesh isn't in glTF spec. See ._markDefs()
        mesh = meshDef["isSkinnedMesh"] == true
            ? SkinnedMesh(geometry, material)
            : Mesh(geometry, material);

        if (mesh is SkinnedMesh &&
            !mesh.geometry!.attributes["skinWeight"].normalized) {
          // we normalize floating point skin weight array to fix malformed assets (see #15319)
          // it's important to skip this for non-float32 data since normalizeSkinWeights assumes non-normalized inputs
          mesh.normalizeSkinWeights();
        }

        if (primitive["mode"] == webgl_constants["TRIANGLE_STRIP"]) {
          mesh.geometry =
              toTrianglesDrawMode(mesh.geometry, TriangleStripDrawMode);
        } else if (primitive["mode"] == webgl_constants["TRIANGLE_FAN"]) {
          mesh.geometry =
              toTrianglesDrawMode(mesh.geometry, TriangleFanDrawMode);
        }
      } else if (primitive["mode"] == webgl_constants["LINES"]) {
        mesh = LineSegments(geometry, material);
      } else if (primitive["mode"] == webgl_constants["LINE_STRIP"]) {
        mesh = Line(geometry, material);
      } else if (primitive["mode"] == webgl_constants["LINE_LOOP"]) {
        mesh = LineLoop(geometry, material);
      } else if (primitive["mode"] == webgl_constants["POINTS"]) {
        mesh = Points(geometry, material);
      } else {
        throw ('THREE.GLTFLoader: Primitive mode unsupported: ${primitive["mode"]}');
      }

      if (mesh.geometry.morphAttributes.keys.length > 0) {
        updateMorphTargets(mesh, meshDef);
      }

      mesh.name =
          parser.createUniqueName(meshDef["name"] ?? ('mesh_${meshIndex}'));

      assignExtrasToUserData(mesh, meshDef);

      if (primitive["extensions"] != null)
        addUnknownExtensionsToUserData(extensions, mesh, primitive);

      parser.assignFinalMaterial(mesh);

      meshes.add(mesh);
    }

    if (meshes.length == 1) {
      return meshes[0];
    }

    final group = Group();

    for (int i = 0, il = meshes.length; i < il; i++) {
      group.add(meshes[i]);
    }

    return group;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#cameras
   * @param {number} cameraIndex
   * @return {Promise<THREE.Camera>}
   */
  Camera? loadCamera(cameraIndex) {
    Camera? camera;
    Map<String, dynamic> cameraDef = this.json["cameras"][cameraIndex];
    final params = cameraDef[cameraDef["type"]];

    if (params == null) {
      print('THREE.GLTFLoader: Missing camera parameters.');
      return null;
    }

    if (cameraDef["type"] == 'perspective') {
      camera = PerspectiveCamera(
          MathUtils.radToDeg(params["yfov"]),
          params["aspectRatio"] ?? 1,
          params["znear"] ?? 1,
          params["zfar"] ?? 2e6);
    } else if (cameraDef["type"] == 'orthographic') {
      camera = OrthographicCamera(-params["xmag"], params["xmag"],
          params["ymag"], -params["ymag"], params["znear"], params["zfar"]);
    }

    if (cameraDef["name"] != null)
      camera?.name = this.createUniqueName(cameraDef["name"]);

    assignExtrasToUserData(camera, cameraDef);

    return camera;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#skins
   * @param {number} skinIndex
   * @return {Promise<Object>}
   */
  loadSkin(skinIndex) async {
    final skinDef = this.json["skins"][skinIndex];

    final skinEntry = {"joints": skinDef["joints"]};

    if (skinDef["inverseBindMatrices"] == null) {
      return skinEntry;
    }

    final accessor =
        await this.getDependency('accessor', skinDef["inverseBindMatrices"]);

    skinEntry["inverseBindMatrices"] = accessor;
    return skinEntry;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#animations
   * @param {number} animationIndex
   * @return {Promise<AnimationClip>}
   */
  Future<AnimationClip> loadAnimation(animationIndex) async {
    final json = this.json;

    Map<String, dynamic> animationDef = json["animations"][animationIndex];

    List<Future> pendingNodes = [];
    List<Future> pendingInputAccessors = [];
    List<Future> pendingOutputAccessors = [];
    List<Future> pendingSamplers = [];
    List<Future> pendingTargets = [];

    for (int i = 0, il = animationDef["channels"].length; i < il; i++) {
      Map<String, dynamic> channel = animationDef["channels"][i];
      Map<String, dynamic> sampler =
          animationDef["samplers"][channel["sampler"]];
      Map<String, dynamic> target = channel["target"];
      final name = target["node"] != null
          ? target["node"]
          : target["id"]; // NOTE: target.id is deprecated.
      final input = animationDef["parameters"] != null
          ? animationDef["parameters"][sampler["input"]]
          : sampler["input"];
      final output = animationDef["parameters"] != null
          ? animationDef["parameters"][sampler["output"]]
          : sampler["output"];

      pendingNodes.add(this.getDependency('node', name));
      pendingInputAccessors.add(this.getDependency('accessor', input));
      pendingOutputAccessors.add(this.getDependency('accessor', output));
      pendingSamplers.add(Future.sync(() => sampler));
      pendingTargets.add(Future.sync(() => target));
    }

    final dependencies = await Future.wait([
      Future.wait(pendingNodes),
      Future.wait(pendingInputAccessors),
      Future.wait(pendingOutputAccessors),
      Future.wait(pendingSamplers),
      Future.wait(pendingTargets)
    ]);

    final nodes = dependencies[0];
    final inputAccessors = dependencies[1];
    final outputAccessors = dependencies[2];
    final samplers = dependencies[3];
    final targets = dependencies[4];

    List<KeyframeTrack> tracks = [];

    for (int i = 0, il = nodes.length; i < il; i++) {
      final node = nodes[i];
      final inputAccessor = inputAccessors[i];

      final outputAccessor = outputAccessors[i];
      Map<String, dynamic> sampler = samplers[i];
      Map<String, dynamic> target = targets[i];

      if (node == null) continue;

      node.updateMatrix();
      node.matrixAutoUpdate = true;

      final _typedKeyframeTrack =
          _TypedKeyframeTrack(PATH_PROPERTIES.getValue(target["path"]));

      String targetName = node.name != null ? node.name : node.uuid;

      final interpolation = sampler["interpolation"] != null
          ? INTERPOLATION[sampler["interpolation"]]
          : InterpolateLinear;

      final targetNames = [];

      if (PATH_PROPERTIES.getValue(target["path"]) == PATH_PROPERTIES.weights) {
        // Node may be a Group (glTF mesh with several primitives) or a Mesh.
        node.traverse((object) {
          if (object.morphTargetInfluences != null) {
            targetNames.add(object.name != null ? object.name : object.uuid);
          }
        });
      } else {
        targetNames.add(targetName);
      }

      Float32List outputArray = outputAccessor.array.toDartList();

      if (outputAccessor.normalized) {
        final scale = getNormalizedComponentScale(outputArray.runtimeType);

        final scaled = Float32List(outputArray.length);

        for (int j = 0, jl = outputArray.length; j < jl; j++) {
          scaled[j] = outputArray[j] * scale;
        }

        outputArray = scaled;
      }

      for (int j = 0, jl = targetNames.length; j < jl; j++) {
        final track = _typedKeyframeTrack.createTrack(
            targetNames[j] + '.' + PATH_PROPERTIES.getValue(target["path"]),
            inputAccessor.array.toDartList(),
            outputArray,
            interpolation);

        // Override interpolation with custom factory method.
        if (sampler["interpolation"] == 'CUBICSPLINE') {
          track.createInterpolant = (result) {
            // A CUBICSPLINE keyframe in glTF has three output values for each input value,
            // representing inTangent, splineVertex, and outTangent. As a result, track.getValueSize()
            // must be divided by three to get the interpolant's sampleSize argument.
            return GLTFCubicSplineInterpolant(
                track.times, track.values, track.getValueSize() ~/ 3, result);
          };

          // Mark as CUBICSPLINE. `track.getInterpolation()` doesn't support custom interpolants.
          // track.createInterpolant.isInterpolantFactoryMethodGLTFCubicSpline = true;
          // TODO
          print(
              "GLTFParser.loadAnimation isInterpolantFactoryMethodGLTFCubicSpline TODO ?? how to handle this case ??? ");
        }

        tracks.add(track);
      }
    }

    final name = animationDef["name"] != null
        ? animationDef["name"]
        : 'animation_${animationIndex}';

    return AnimationClip(name, -1, tracks);
  }

  createNodeMesh(int nodeIndex) async {
    final json = this.json;
    final parser = this;
    Map<String, dynamic> nodeDef = json["nodes"][nodeIndex];

    if (nodeDef["mesh"] == null) return null;

    final mesh = await parser.getDependency('mesh', nodeDef["mesh"]);

    final node = parser.getNodeRef(parser.meshCache, nodeDef["mesh"], mesh);

    // if weights are provided on the node, override weights on the mesh.
    if (nodeDef["weights"] != null) {
      node.traverse((o) {
        if (!o.isMesh) return;

        for (int i = 0, il = nodeDef["weights"].length; i < il; i++) {
          o.morphTargetInfluences[i] = nodeDef["weights"][i];
        }
      });
    }

    return node;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#nodes-and-hierarchy
   * @param {number} nodeIndex
   * @return {Promise<Object3D>}
   */
  Future<Object3D> loadNode(int nodeIndex) async {
    final json = this.json;
    final extensions = this.extensions;
    final parser = this;

    Map<String, dynamic> nodeDef = json["nodes"][nodeIndex];

    // reserve node's name before its dependencies, so the root has the intended name.
    final nodeName =
        nodeDef["name"] != null ? parser.createUniqueName(nodeDef["name"]) : '';

    final pending = [];

    final meshPromise = await parser._invokeOne((ext) {
      return ext.createNodeMesh != null ? ext.createNodeMesh(nodeIndex) : null;
    });

    if (meshPromise != null) {
      pending.add(meshPromise);
    }
    // if ( nodeDef["mesh"] != null ) {
    //   final mesh = await parser.getDependency( 'mesh', nodeDef["mesh"] );
    //   final node = await parser._getNodeRef( parser.meshCache, nodeDef["mesh"], mesh );
    //   // if weights are provided on the node, override weights on the mesh.
    //   if ( nodeDef["weights"] != null ) {
    //     node.traverse( ( o ) {
    //       if ( ! o.isMesh ) return;
    //       for ( final i = 0, il = nodeDef["weights"].length; i < il; i ++ ) {
    //         o.morphTargetInfluences[ i ] = nodeDef["weights"][ i ];
    //       }
    //     } );
    //   }
    //   pending.add(node);
    // }

    if (nodeDef["camera"] != null) {
      final camera = await parser.getDependency('camera', nodeDef["camera"]);

      pending.add(await parser.getNodeRef(
          parser.cameraCache, nodeDef["camera"], camera));
    }

    // parser._invokeAll( ( ext ) async {
    //   return ext.createNodeAttachment != null ? await ext.createNodeAttachment( nodeIndex ) : null;
    // } ).forEach( ( promise ) {
    //   pending.add( promise );
    // } );

    List _results = await parser._invokeAll((ext) async {
      return ext.createNodeAttachment != null
          ? await ext.createNodeAttachment(nodeIndex)
          : null;
    });

    final objects = [];

    pending.forEach((element) {
      objects.add(element);
    });

    _results.forEach((element) {
      objects.add(element);
    });

    final node;

    // .isBone isn't in glTF spec. See ._markDefs
    if (nodeDef["isBone"] == true) {
      node = Bone();
    } else if (objects.length > 1) {
      node = Group();
    } else if (objects.length == 1) {
      node = objects[0];
    } else {
      node = Object3D();
    }

    if (objects.length == 0 || node != objects[0]) {
      for (int i = 0, il = objects.length; i < il; i++) {
        node.add(objects[i]);
      }
    }

    if (nodeDef["name"] != null) {
      node.userData["name"] = nodeDef["name"];
      node.name = nodeName;
    }

    assignExtrasToUserData(node, nodeDef);

    if (nodeDef["extensions"] != null)
      addUnknownExtensionsToUserData(extensions, node, nodeDef);

    if (nodeDef["matrix"] != null) {
      final matrix = Matrix4();
      matrix.fromArray(List<num>.from(nodeDef["matrix"]));
      node.applyMatrix4(matrix);
    } else {
      if (nodeDef["translation"] != null) {
        node.position.fromArray(List<num>.from(nodeDef["translation"]));
      }

      if (nodeDef["rotation"] != null) {
        node.quaternion.fromArray(List<num>.from(nodeDef["rotation"]));
      }

      if (nodeDef["scale"] != null) {
        node.scale.fromArray(List<num>.from(nodeDef["scale"]));
      }
    }

    parser.associations[node] = {"type": 'nodes', "index": nodeIndex};

    return node;
  }

  /**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#scenes
   * @param {number} sceneIndex
   * @return {Promise<Group>}
   */

  Future<void> buildNodeHierarchy(int nodeId, parentObject, json, parser) async {
    Map<String, dynamic> nodeDef = json["nodes"][nodeId];

    final node = await parser.getDependency('node', nodeId);

    if (nodeDef["skin"] != null) {
      // build skeleton here as well

      final skinEntry;

      final skin = await parser.getDependency('skin', nodeDef["skin"]);
      skinEntry = skin;

      final jointNodes = [];

      for (int i = 0, il = skinEntry["joints"].length; i < il; i++) {
        final _node = await parser.getDependency('node', skinEntry["joints"][i]);

        jointNodes.add(_node);
      }

      node.traverse((mesh) {
        if(mesh is SkinnedMesh) {
          List<Bone> bones = [];
          List<Matrix4> boneInverses = [];

          for (int j = 0, jl = jointNodes.length; j < jl; j++) {
            final jointNode = jointNodes[j];

            if (jointNode != null) {
              bones.add(jointNode);

              final mat = Matrix4();

              if (skinEntry["inverseBindMatrices"] != null) {
                mat.fromArray(skinEntry["inverseBindMatrices"].array, j * 16);
              }

              boneInverses.add(mat);
            } else {
              print(
                  'THREE.GLTFLoader: Joint "%s" could not be found. ${skinEntry["joints"][j]}');
            }
          }

          mesh.bind(Skeleton(bones, boneInverses),
              mesh.matrixWorld);
        }
      });
    }

    // build node hierachy

    parentObject.add(node);

    if (nodeDef["children"] != null) {
      final children = nodeDef["children"];

      for (int i = 0, il = children.length; i < il; i++) {
        final child = children[i];
        await buildNodeHierarchy(child, node, json, parser);
      }
    }
  }

  Future<Group> loadScene(int sceneIndex) async {
    final json = this.json;
    final extensions = this.extensions;
    Map<String, dynamic> sceneDef = this.json["scenes"][sceneIndex];
    final parser = this;

    // Loader returns Group, not Scene.
    // See: https://github.com/mrdoob/three.js/issues/18342#issuecomment-578981172
    final scene = Group();
    if (sceneDef["name"] != null)
      scene.name = parser.createUniqueName(sceneDef["name"]);

    assignExtrasToUserData(scene, sceneDef);

    if (sceneDef["extensions"] != null)
      addUnknownExtensionsToUserData(extensions, scene, sceneDef);

    final nodeIds = sceneDef["nodes"] ?? [];

    for (int i = 0, il = nodeIds.length; i < il; i++) {
      await buildNodeHierarchy(nodeIds[i], scene, json, parser);
    }

    return scene;
  }
}
//class GLTFParser end...

class _TypedKeyframeTrack {
  late String path;

  _TypedKeyframeTrack(String path) {
    this.path = path;
  }

  KeyframeTrack createTrack(String v0, List<num> v1, List<num> v2, v3) {
    switch (this.path) {
      case PATH_PROPERTIES.weights:
        return NumberKeyframeTrack(v0, v1, v2, v3);
      case PATH_PROPERTIES.rotation:
        return QuaternionKeyframeTrack(v0, v1, v2, v3);
      case PATH_PROPERTIES.position:
      case PATH_PROPERTIES.scale:
      default:
        return VectorKeyframeTrack(v0, v1, v2, v3);
    }
  }
}
