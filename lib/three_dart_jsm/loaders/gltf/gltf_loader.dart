import 'dart:async';
import 'dart:convert' as convert;
import 'dart:typed_data';
import 'package:three_dart/three_dart.dart';
import 'gltf_extensions.dart';
import 'gltf_parser.dart';

class GLTFLoader extends Loader {
  late List<Function> pluginCallbacks;
  late dynamic _dracoLoader;
  late dynamic _ktx2Loader;
  late dynamic _ddsLoader;
  late dynamic _meshoptDecoder;

  GLTFLoader([LoadingManager? manager]) : super(manager) {
    this._dracoLoader = null;
    this._ddsLoader = null;
    this._ktx2Loader = null;
    this._meshoptDecoder = null;

    this.pluginCallbacks = [];

    this.register((parser) {
      return GLTFMaterialsClearcoatExtension(parser);
    });

    this.register((parser) {
      return GLTFTextureBasisUExtension(parser);
    });

    this.register((parser) {
      return GLTFTextureWebPExtension(parser);
    });

    this.register((parser) {
      return GLTFMaterialsSheenExtension(parser);
    });

    this.register((parser) {
      return GLTFMaterialsTransmissionExtension(parser);
    });

    this.register((parser) {
      return GLTFMaterialsVolumeExtension(parser);
    });

    this.register((parser) {
      return GLTFMaterialsIorExtension(parser);
    });

    this.register((parser) {
      return GLTFMaterialsSpecularExtension(parser);
    });

    this.register((parser) {
      return GLTFLightsExtension(parser);
    });

    this.register((parser) {
      return GLTFMeshoptCompression(parser);
    });
  }

  @override
  Future<GLTFData> loadAsync(url) async {
    Completer<GLTFData> completer = Completer();

    load(url, (buffer) {
      completer.complete(buffer);
    });

    return completer.future;
  }

  @override
  void load(url, Function onLoad, [Function? onProgress, Function? onError]) {
    final scope = this;

    final resourcePath;

    if (this.resourcePath != '') {
      resourcePath = this.resourcePath;
    } else if (this.path != '') {
      resourcePath = this.path;
    } else {
      resourcePath = LoaderUtils.extractUrlBase(url);
    }

    // Tells the LoadingManager to track an extra item, which resolves after
    // the model is fully loaded. This means the count of items loaded will
    // be incorrect, but ensures manager.onLoad() does not fire early.
    this.manager.itemStart(url);

    Function(String) _onError = (e) {
      if (onError != null) {
        onError(e);
      } else {
        print(e);
      }

      scope.manager.itemError(url);
      scope.manager.itemEnd(url);
    };

    final loader = FileLoader(this.manager);

    loader.setPath(this.path);
    loader.setResponseType('arraybuffer');
    loader.setRequestHeader(this.requestHeader);
    loader.setWithCredentials(this.withCredentials);

    loader.load(
      url, 
      (data) {
        scope._parse(
          data, 
          resourcePath, 
          (gltf) {
            onLoad(gltf);
            scope.manager.itemEnd(url);
          }, 
          _onError
        );
      }, 
      onProgress, 
      _onError
    );
  }

  @override
  GLTFLoader setPath(String path) {
    super.setPath(path);
    return this;
  }

  GLTFLoader setDRACOLoader(dracoLoader) {
    this._dracoLoader = dracoLoader;
    return this;
  }

  GLTFLoader setDDSLoader(ddsLoader) {
    this._ddsLoader = ddsLoader;
    return this;
  }

  GLTFLoader setKTX2Loader(ktx2Loader) {
    this._ktx2Loader = ktx2Loader;
    return this;
  }

  GLTFLoader setMeshoptDecoder(meshoptDecoder) {
    this._meshoptDecoder = meshoptDecoder;
    return this;
  }

  GLTFLoader register(Function callback) {
    if (this.pluginCallbacks.indexOf(callback) == -1) {
      this.pluginCallbacks.add(callback);
    }

    return this;
  }

  GLTFLoader unregister(Function callback) {
    if (this.pluginCallbacks.indexOf(callback) != -1) {
      splice(this.pluginCallbacks, this.pluginCallbacks.indexOf(callback), 1);
    }

    return this;
  }

  void _parse(
    data, 
    [
      String? path, 
      Function(GLTFData)? onLoad, 
      Function(String)? onError
    ]
  ) {
    final content;
    final extensions = {};
    final plugins = {};

    if (data is String) {
      content = data;
    } 
    else {
      final magic = LoaderUtils.decodeText(Uint8List.view(data.buffer, 0, 4));
      if (magic == BINARY_EXTENSION_HEADER_MAGIC) {
        extensions[extensions["KHR_BINARY_GLTF"]] = GLTFBinaryExtension(data.buffer);
        content = extensions[extensions["KHR_BINARY_GLTF"]].content;
      } 
      else {
        content = LoaderUtils.decodeText(data);
      }
    }

    Map<String, dynamic> json = convert.jsonDecode(content);

    if (json["asset"] == null || num.parse(json["asset"]["version"]) < 2.0) {
      if (onError != null)
        onError(
            'THREE.GLTFLoader: Unsupported asset. glTF versions >= 2.0 are supported.');
      return;
    }

    final parser = GLTFParser(json, {
      "path": path != null
          ? path
          : this.resourcePath != null
              ? this.resourcePath
              : '',
      "crossOrigin": this.crossOrigin,
      "requestHeader": this.requestHeader,
      "manager": this.manager,
      "_ktx2Loader": this._ktx2Loader,
      "_meshoptDecoder": this._meshoptDecoder
    });

    parser.fileLoader.setRequestHeader(this.requestHeader);

    for (int i = 0; i < this.pluginCallbacks.length; i++) {
      final plugin = this.pluginCallbacks[i](parser);
      plugins[plugin.name] = plugin;

      // Workaround to avoid determining as unknown extension
      // in addUnknownExtensionsToUserData().
      // Remove this workaround if we move all the existing
      // extension handlers to plugin system
      extensions[plugin.name] = true;
    }

    if (json["extensionsUsed"] != null) {
      for (int i = 0; i < json["extensionsUsed"].length; ++i) {
        final extensionName = json["extensionsUsed"][i];
        final extensionsRequired = json["extensionsRequired"] ?? [];

        if (extensionName == extensions["KHR_MATERIALS_UNLIT"]) {
          extensions[extensionName] = GLTFMaterialsUnlitExtension();
        } else if (extensionName ==
            extensions["KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS"]) {
          extensions[extensionName] =
              GLTFMaterialsPbrSpecularGlossinessExtension();
        } else if (extensionName == extensions["KHR_DRACO_MESH_COMPRESSION"]) {
          extensions[extensionName] =
              GLTFDracoMeshCompressionExtension(json, this._dracoLoader);
        } else if (extensionName == extensions["MSFT_TEXTURE_DDS"]) {
          extensions[extensionName] =
              GLTFTextureDDSExtension(this._ddsLoader);
        } else if (extensionName == extensions["KHR_TEXTURE_TRANSFORM"]) {
          extensions[extensionName] = GLTFTextureTransformExtension();
        } else if (extensionName == extensions["KHR_MESH_QUANTIZATION"]) {
          extensions[extensionName] = GLTFMeshQuantizationExtension();
        } else {
          if (extensionsRequired.indexOf(extensionName) >= 0 &&
              plugins[extensionName] == null) {
            print('THREE.GLTFLoader: Unknown extension ${extensionName}.');
          }
        }
      }
    }

    parser.setExtensions(extensions);
    parser.setPlugins(plugins);
    parser.parse(onLoad, onError);
  }
}
