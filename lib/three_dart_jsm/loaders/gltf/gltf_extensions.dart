import 'dart:async';
import 'dart:typed_data';
import 'package:three_dart/three_dart.dart';
import 'gltf_parser.dart';
import 'gltf_mesh_standard_sg_material.dart';
import 'gltf_helper.dart';

/*********************************/
/********** extensions ***********/

/*********************************/

Map<String, String> extensions = {
  "KHR_BINARY_GLTF": 'KHR_binary_glTF',
  "KHR_DRACO_MESH_COMPRESSION": 'KHR_draco_mesh_compression',
  "KHR_LIGHTS_PUNCTUAL": 'KHR_lights_punctual',
  "KHR_MATERIALS_CLEARCOAT": 'KHR_materials_clearcoat',
  "KHR_MATERIALS_IOR": 'KHR_materials_ior',
  "KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS":
      'KHR_materials_pbrSpecularGlossiness',
  "KHR_MATERIALS_SHEEN": 'KHR_materials_sheen',
  "KHR_MATERIALS_SPECULAR": 'KHR_materials_specular',
  "KHR_MATERIALS_TRANSMISSION": 'KHR_materials_transmission',
  "KHR_MATERIALS_UNLIT": 'KHR_materials_unlit',
  "KHR_MATERIALS_VOLUME": 'KHR_materials_volume',
  "KHR_TEXTURE_BASISU": 'KHR_texture_basisu',
  "KHR_TEXTURE_TRANSFORM": 'KHR_texture_transform',
  "KHR_MESH_QUANTIZATION": 'KHR_mesh_quantization',
  "EXT_TEXTURE_WEBP": 'EXT_texture_webp',
  "EXT_MESHOPT_COMPRESSION": 'EXT_meshopt_compression',
  "MSFT_TEXTURE_DDS": 'MSFT_texture_dds'
};

class GLTFExtension {
  late String name;
  Function? markDefs;
  Function? loadMesh;
  Function? loadMaterial;
  Function? getMaterialType;
  Function? createNodeAttachment;
  Function? extendMaterialParams;
  Function? loadBufferView;
  Function? loadTexture;
  Function? createNodeMesh;
}

/**
 * Materials specular Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_specular
 */
class GLTFMaterialsSpecularExtension extends GLTFExtension {
  late GLTFParser parser;

  GLTFMaterialsSpecularExtension(this.parser) {
    this.parser = parser;
    this.name = extensions["KHR_MATERIALS_SPECULAR"]!;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) async {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      List<Future<Texture>> pending = [];

      final extension = materialDef["extensions"][this.name];

      materialParams.specularIntensity =
          extension.specularFactor != null ? extension.specularFactor : 1.0;

      if (extension.specularTexture != null) {
        pending.add(parser.assignTexture(
            materialParams, 'specularIntensityMap', extension.specularTexture));
      }

      final colorArray = extension.specularColorFactor ?? [1, 1, 1];
      materialParams.specularColor =
          Color(colorArray[0], colorArray[1], colorArray[2]);

      if (extension.specularColorTexture != null) {
        final texture = parser.assignTexture(
            materialParams, 'specularColorMap', extension.specularColorTexture, sRGBEncoding);
        pending.add(texture);
      }

      return await Future.wait(pending);
    };
  }
}

/**
 * DDS Texture Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/MSFT_texture_dds
 *
 */
class GLTFTextureDDSExtension extends GLTFExtension {
  late dynamic ddsLoader;
  String name = extensions["MSFT_TEXTURE_DDS"]!;

  GLTFTextureDDSExtension(ddsLoader) {
    if (!ddsLoader) {
      throw ('THREE.GLTFLoader: Attempting to load .dds texture without importing DDSLoader');
    }

    this.ddsLoader = ddsLoader;
  }
}

/**
 * Punctual Lights Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_lights_punctual
 */
class GLTFLightsExtension extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["KHR_LIGHTS_PUNCTUAL"]!;
  late dynamic cache;

  GLTFLightsExtension(parser) {
    this.parser = parser;

    // Object3D instance caches
    this.cache = {"refs": {}, "uses": {}};

    this.markDefs = () {
      final parser = this.parser;
      final nodeDefs = this.parser.json["nodes"] ?? [];

      for (int nodeIndex = 0, nodeLength = nodeDefs.length;
          nodeIndex < nodeLength;
          nodeIndex++) {
        final nodeDef = nodeDefs[nodeIndex];

        if (nodeDef["extensions"] != null &&
            nodeDef["extensions"][this.name] != null &&
            nodeDef["extensions"][this.name]["light"] != null) {
          parser.addNodeRef(
              this.cache, nodeDef["extensions"][this.name]["light"]);
        }
      }
    };

    this.createNodeAttachment = (nodeIndex) {
      final self = this;
      final parser = this.parser;
      final json = parser.json;
      Map<String, dynamic> nodeDef = json["nodes"][nodeIndex];

      // final lightDef = ( nodeDef.extensions && nodeDef.extensions[ this.name ] ) ?? {};
      Map lightDef = {};
      if (nodeDef["extensions"] != null &&
          nodeDef["extensions"][this.name] != null) {
        lightDef = nodeDef["extensions"][this.name];
      }

      final lightIndex = lightDef["light"];

      if (lightIndex == null) return null;

      final _light = this._loadLight(lightIndex);

      return parser.getNodeRef(self.cache, lightIndex, _light);
    };
  }

  _loadLight(lightIndex) {
    final parser = this.parser;
    String cacheKey = 'light:${lightIndex}';
    dynamic dependency = parser.cache.get(cacheKey);

    if (dependency != null) return dependency;

    final json = parser.json;
    Map<String, dynamic> extensions = Map<String, dynamic>();
    if (json["extensions"] != null && json["extensions"][this.name] != null) {
      extensions = json["extensions"][this.name];
    }
    // final extensions = ( json["extensions"] != null && json["extensions"][ this.name ]) ?? Map<String, dynamic>();
    final lightDefs = extensions["lights"] ?? [];
    final lightDef = lightDefs[lightIndex];
    final lightNode;

    Color color = Color.fromHex(0xffffff);
    print(lightDef["color"]);
    if (lightDef["color"] != null) {
      List<dynamic> listDyn = lightDef["color"];
      List<double> listDouble = listDyn.map(
        (i){
          if(i is int){
            return i.toDouble();
          }
          else{
            return double.tryParse(i) ?? 1;
          }
        }
      ).toList();
      color.fromArray(listDouble);
    }

    final range = lightDef["range"] != null ? lightDef["range"] : 0;

    switch (lightDef["type"]) {
      case 'directional':
        lightNode = DirectionalLight(color.getHex(), null);
        lightNode.target.position.set(0, 0, -1);
        lightNode.add(lightNode.target);
        break;

      case 'point':
        lightNode = PointLight(color.getHex(), null, null, null);
        lightNode.distance = range.toDouble();
        break;

      case 'spot':
        lightNode = SpotLight(color.getHex(), null, null, null, null, null);
        lightNode.distance = range;
        // Handle spotlight properties.
        lightDef["spot"] = lightDef["spot"] ?? {};
        lightDef["spot"]["innerConeAngle"] =
            lightDef["spot"]["innerConeAngle"] != null
                ? lightDef["spot"]["innerConeAngle"]
                : 0;
        lightDef["spot"]["outerConeAngle"] =
            lightDef["spot"]["outerConeAngle"] != null
                ? lightDef["spot"]["outerConeAngle"]
                : Math.pi / 4.0;
        lightNode.angle = lightDef["spot"]["outerConeAngle"];
        lightNode.penumbra = 1.0 -
            lightDef["spot"]["innerConeAngle"] /
                lightDef["spot"]["outerConeAngle"];
        lightNode.target.position.set(0, 0, -1);
        lightNode.add(lightNode.target);
        break;

      default:
        throw ('THREE.GLTFLoader: Unexpected light type: ${lightDef["type"]}');
    }

    // Some lights (e.g. spot) default to a position other than the origin. Reset the position
    // here, because node-level parsing will only override position if explicitly specified.
    lightNode.position.set(0.0, 0.0, 0.0);

    lightNode.decay = 2.0;

    if (lightDef["intensity"] != null)
      lightNode.intensity = lightDef["intensity"].toDouble();

    lightNode.name =
        parser.createUniqueName(lightDef["name"] ?? ('light_' + lightIndex));

    // dependency = Promise.resolve( lightNode );
    dependency = lightNode;

    parser.cache.add(cacheKey, dependency);

    return dependency;
  }
}

/**
 * Unlit Materials Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_unlit
 */
class GLTFMaterialsUnlitExtension extends GLTFExtension {
  String name = extensions["KHR_MATERIALS_UNLIT"]!;

  GLTFMaterialsUnlitExtension() {
    this.getMaterialType = (materialIndex) {
      return MeshBasicMaterial;
    };
  }

  Future extendParams(Map<String, dynamic> materialParams, Map<String, dynamic> materialDef, GLTFParser parser) async {
    List<Future> pending = [];

    materialParams["color"] = Color(1.0, 1.0, 1.0);
    materialParams["opacity"] = 1.0;

    Map<String, dynamic>? metallicRoughness = materialDef["pbrMetallicRoughness"];

    if (metallicRoughness != null) {
      if (metallicRoughness["baseColorFactor"] is List) {
        List<double> array = List<double>.from(metallicRoughness["baseColorFactor"].map((e) => e.toDouble()).toList());

        materialParams["color"].fromArray(array);
        materialParams["opacity"] = array[3];
      }

      if (metallicRoughness["baseColorTexture"] != null) {
        pending.add(parser.assignTexture(
            materialParams, 'map', metallicRoughness["baseColorTexture"]));
      }
    }

    return Future.wait(pending);
  }
}

/**
 * Clearcoat Materials Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_clearcoat
 */
class GLTFMaterialsClearcoatExtension extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["KHR_MATERIALS_CLEARCOAT"]!;

  GLTFMaterialsClearcoatExtension(this.parser) {
    this.parser = parser;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name]) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) async {
      final parser = this.parser;
      Map<String, dynamic> materialDef =
          parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      List<Future> pending = [];

      Map<String, dynamic> exten = materialDef["extensions"][this.name];

      if (exten["clearcoatFactor"] != null) {
        materialParams.clearcoat = exten["clearcoatFactor"];
      }

      if (exten["clearcoatTexture"] != null) {
        pending.add(parser.assignTexture(
            materialParams, 'clearcoatMap', exten["clearcoatTexture"]));
      }

      if (exten["clearcoatRoughnessFactor"] != null) {
        materialParams.clearcoatRoughness = exten["clearcoatRoughnessFactor"];
      }

      if (exten["clearcoatRoughnessTexture"] != null) {
        pending.add(parser.assignTexture(materialParams,
            'clearcoatRoughnessMap', exten["clearcoatRoughnessTexture"]));
      }

      if (exten["clearcoatNormalTexture"] != null) {
        pending.add(parser.assignTexture(materialParams, 'clearcoatNormalMap',
            exten["clearcoatNormalTexture"]));

        if (exten["clearcoatNormalTexture"]["scale"] != null) {
          final scale = exten["clearcoatNormalTexture"]["scale"];

          materialParams.clearcoatNormalScale = Vector2(scale, scale);
        }
      }

      return await Future.wait(pending);
    };
  }
}

/**
 * Sheen Materials Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_sheen
 */
class GLTFMaterialsSheenExtension extends GLTFExtension {
  late GLTFParser parser;

  GLTFMaterialsSheenExtension(this.parser) {
    this.parser = parser;
    this.name = extensions["KHR_MATERIALS_SHEEN"]!;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      List<Future> pending = [];

      materialParams.sheenColor = Color(0, 0, 0);
      materialParams.sheenRoughness = 0;
      materialParams.sheen = 1;

      Map extension = materialDef["extensions"][this.name];

      if (extension["sheenColorFactor"] != null) {
        materialParams.sheenColor.fromArray(extension["sheenColorFactor"]);
      }

      if (extension["sheenRoughnessFactor"] != null) {
        materialParams.sheenRoughness = extension["sheenRoughnessFactor"];
      }

      if (extension["sheenColorTexture"] != null) {
        pending.add(parser.assignTexture(
            materialParams, 'sheenColorMap', extension["sheenColorTexture"], sRGBEncoding));
      }

      if (extension["sheenRoughnessTexture"] != null) {
        pending.add(parser.assignTexture(materialParams, 'sheenRoughnessMap',
            extension["sheenRoughnessTexture"]));
      }

      return Future.wait(pending);
    };
  }
}

/**
 * Transmission Materials Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_transmission
 * Draft: https://github.com/KhronosGroup/glTF/pull/1698
 */
class GLTFMaterialsTransmissionExtension extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["KHR_MATERIALS_TRANSMISSION"]!;

  GLTFMaterialsTransmissionExtension(this.parser) {
    this.parser = parser;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      Map<String, dynamic> materialDef =
          parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) async {
      final parser = this.parser;
      Map<String, dynamic> materialDef =
          parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      List<Future> pending = [];

      Map<String, dynamic> exten = materialDef["extensions"][this.name];

      if (exten["transmissionFactor"] != null) {
        materialParams.transmission = exten["transmissionFactor"];
      }

      if (exten["transmissionTexture"] != null) {
        pending.add(parser.assignTexture(
            materialParams, 'transmissionMap', exten["transmissionTexture"]));
      }

      return Future.wait(pending);
    };
  }
}

/**
 * Materials ior Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_ior
 */
class GLTFMaterialsIorExtension extends GLTFExtension {
  late GLTFParser parser;

  GLTFMaterialsIorExtension(this.parser) {
    this.parser = parser;
    this.name = extensions["KHR_MATERIALS_IOR"]!;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      final extension = materialDef["extensions"][this.name];

      materialParams.ior = extension.ior != null ? extension.ior : 1.5;

      return null;
    };
  }
}

/**
 * Materials Volume Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_volume
 */
class GLTFMaterialsVolumeExtension extends GLTFExtension {
  late GLTFParser parser;

  GLTFMaterialsVolumeExtension(this.parser) {
    this.parser = parser;
    this.name = extensions["KHR_MATERIALS_VOLUME"]!;

    this.getMaterialType = (materialIndex) {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) return null;

      return MeshPhysicalMaterial;
    };

    this.extendMaterialParams = (materialIndex, materialParams) async {
      final parser = this.parser;
      final materialDef = parser.json["materials"][materialIndex];

      if (materialDef["extensions"] == null ||
          materialDef["extensions"][this.name] == null) {
        return null;
      }

      List<Future> pending = [];

      final extension = materialDef["extensions"][this.name];

      materialParams.thickness =
          extension.thicknessFactor != null ? extension.thicknessFactor : 0;

      if (extension.thicknessTexture != null) {
        pending.add(parser.assignTexture(
            materialParams, 'thicknessMap', extension.thicknessTexture));
      }

      materialParams.attenuationDistance = extension.attenuationDistance ?? 0;

      final colorArray = extension.attenuationColor ?? [1, 1, 1];
      materialParams.attenuationColor =
          Color(colorArray[0], colorArray[1], colorArray[2]);

      return await Future.wait(pending);
    };
  }
}

/**
 * BasisU Texture Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_basisu
 */
class GLTFTextureBasisUExtension extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["KHR_TEXTURE_BASISU"]!;

  GLTFTextureBasisUExtension(this.parser) {
    this.parser = parser;
    this.loadTexture = loadTexture2;
  }

  Future<Texture>? loadTexture2(textureIndex) {
    final parser = this.parser;
    Map<String, dynamic> json = parser.json;

    Map<String, dynamic> textureDef = json["textures"][textureIndex];

    if (textureDef["extensions"] == null ||
        textureDef["extensions"][this.name] == null) {
      return null;
    }

    final extension = textureDef["extensions"][this.name];
    final loader = parser.options["ktx2Loader"];

    if (loader == null) {
      if (json["extensionsRequired"] != null &&
          json["extensionsRequired"].indexOf(this.name) >= 0) {
        throw ('THREE.GLTFLoader: setKTX2Loader must be called before loading KTX2 textures');
      } else {
        // Assumes that the extension is optional and that a fallback texture is present
        return null;
      }
    }

    return parser.loadTextureImage(textureIndex, extension.source, loader);
  }
}

/**
 * WebP Texture Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_texture_webp
 */
class GLTFTextureWebPExtension extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["EXT_TEXTURE_WEBP"]!;
  bool? isSupported;

  GLTFTextureWebPExtension(this.parser) {
    this.isSupported = null;
    this.loadTexture = loadTexture2;
  }

  Future<Texture>? loadTexture2(textureIndex) {
    final name = this.name;
    final parser = this.parser;
    Map<String, dynamic> json = parser.json;

    Map<String, dynamic> textureDef = json["textures"][textureIndex];

    if (textureDef["extensions"] == null ||
        textureDef["extensions"][name] == null) {
      return null;
    }

    final exten = textureDef["extensions"][name];
    final source = json["images"][exten["source"]];
    final loader = source.uri
        ? parser.options['manager'].getHandler(source.uri)
        : parser.textureLoader;

    final isSupported = this.detectSupport();

    if (isSupported)
      return parser.loadTextureImage(textureIndex, source, loader);

    if (json["extensionsRequired"] != null &&
        json["extensionsRequired"].indexOf(name) >= 0) {
      throw ('THREE.GLTFLoader: WebP required by asset but unsupported.');
    }

    // Fall back to PNG or JPEG.
    return parser.loadTexture(textureIndex);
  }

  bool detectSupport() {
    // if ( ! this.isSupported ) {
    //   this.isSupported = Promise( function ( resolve ) {
    //     final image = Image();
    //     // Lossy test image. Support for lossy images doesn't guarantee support for all
    //     // WebP images, unfortunately.
    //     image.src = 'data:image/webp;base64,UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA';
    //     image.onload = image.onerror = function () {
    //       resolve( image.height == 1 );
    //     };
    //   } );
    // }
    // return this.isSupported;

    return true;
  }
}

/**
* meshopt BufferView Compression Extension
*
* Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_meshopt_compression
*/
class GLTFMeshoptCompression extends GLTFExtension {
  late GLTFParser parser;
  String name = extensions["EXT_MESHOPT_COMPRESSION"]!;

  GLTFMeshoptCompression(this.parser) {
    this.parser = parser;

    this.loadBufferView = (index) async {
      Map<String, dynamic> json = this.parser.json;
      Map<String, dynamic> bufferView = json["bufferViews"][index];

      if (bufferView["extensions"] != null &&
          bufferView["extensions"][this.name] != null) {
        final extensionDef = bufferView["extensions"][this.name];

        final buffer =
            await this.parser.getDependency('buffer', extensionDef.buffer);
        final decoder = this.parser.options['meshoptDecoder'];

        if (!decoder || !decoder.supported) {
          if (json["extensionsRequired"] != null &&
              json["extensionsRequired"].indexOf(this.name) >= 0) {
            throw ('THREE.GLTFLoader: setMeshoptDecoder must be called before loading compressed files');
          } else {
            // Assumes that the extension is optional and that fallback buffer data is present
            return null;
          }
        }

        final byteOffset = extensionDef.byteOffset ?? 0;
        final byteLength = extensionDef.byteLength ?? 0;

        final count = extensionDef.count;
        final stride = extensionDef.byteStride;

        final result = Uint8List(count * stride);
        final source = Uint8List.view(buffer, byteOffset, byteLength);

        decoder.decodeGltfBuffer(result, count, stride, source,
            extensionDef.mode, extensionDef.filter);
        return result;
      } else {
        return null;
      }
    };
  }
}

/* BINARY EXTENSION */
final BINARY_EXTENSION_HEADER_MAGIC = 'glTF';
final BINARY_EXTENSION_HEADER_LENGTH = 12;
final BINARY_EXTENSION_CHUNK_TYPES = {"JSON": 0x4E4F534A, "BIN": 0x004E4942};

class GLTFBinaryExtension extends GLTFExtension {
  String name = extensions["KHR_BINARY_GLTF"]!;
  dynamic content;
  dynamic body;
  late Map<String, dynamic> header;

  GLTFBinaryExtension(ByteBuffer data) {
    // final headerView = DataView( data, 0, BINARY_EXTENSION_HEADER_LENGTH );
    final headerView = ByteData.view(data, 0, BINARY_EXTENSION_HEADER_LENGTH);

    this.header = {
      "magic": LoaderUtils.decodeText(data.asUint8List(0, 4)),
      "version": headerView.getUint32(4, Endian.host),
      "length": headerView.getUint32(8, Endian.host)
    };

    if (this.header["magic"] != BINARY_EXTENSION_HEADER_MAGIC) {
      throw ('THREE.GLTFLoader: Unsupported glTF-Binary header.');
    } else if (this.header["version"] < 2.0) {
      throw ('THREE.GLTFLoader: Legacy binary file detected.');
    }

    // final chunkView = DataView( data, BINARY_EXTENSION_HEADER_LENGTH );
    ByteData chunkView = ByteData.view(data, BINARY_EXTENSION_HEADER_LENGTH);
    int chunkIndex = 0;

    while (chunkIndex < chunkView.lengthInBytes) {
      final chunkLength = chunkView.getUint32(chunkIndex, Endian.host);
      chunkIndex += 4;

      final chunkType = chunkView.getUint32(chunkIndex, Endian.host);
      chunkIndex += 4;

      if (chunkType == BINARY_EXTENSION_CHUNK_TYPES["JSON"]) {
        final contentArray = Uint8List.view(
            data, BINARY_EXTENSION_HEADER_LENGTH + chunkIndex, chunkLength);
        this.content = LoaderUtils.decodeText(contentArray);
      } else if (chunkType == BINARY_EXTENSION_CHUNK_TYPES["BIN"]) {
        final byteOffset = BINARY_EXTENSION_HEADER_LENGTH + chunkIndex;

        this.body = Uint8List.view(data)
            .sublist(byteOffset, byteOffset + chunkLength)
            .buffer;
      }

      // Clients must ignore chunks with unknown types.

      chunkIndex += chunkLength;
    }

    if (this.content == null) {
      throw ('THREE.GLTFLoader: JSON content not found.');
    }
  }
}

/**
 * DRACO Mesh Compression Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_draco_mesh_compression
 */
class GLTFDracoMeshCompressionExtension extends GLTFExtension {
  String name = extensions["KHR_DRACO_MESH_COMPRESSION"]!;
  late dynamic json;
  late dynamic dracoLoader;

  GLTFDracoMeshCompressionExtension(json, dracoLoader) {
    if (dracoLoader == null) {
      throw ('THREE.GLTFLoader: No DRACOLoader instance provided.');
    }

    this.json = json;
    this.dracoLoader = dracoLoader;
    this.dracoLoader.preload();
  }

  decodePrimitive(Map<String,dynamic> primitive, GLTFParser parser) async {
    final json = this.json;
    final dracoLoader = this.dracoLoader;
    final bufferViewIndex = primitive["extensions"][this.name]["bufferView"];
    final gltfAttributeMap = primitive["extensions"][this.name]["attributes"];
    final threeAttributeMap = {};
    final attributeNormalizedMap = {};
    final attributeTypeMap = {};

    gltfAttributeMap.forEach((attributeName, _value) {
      final threeAttributeName =
          ATTRIBUTES[attributeName] ?? attributeName.toLowerCase();

      threeAttributeMap[threeAttributeName] = gltfAttributeMap[attributeName];
    });

    primitive["attributes"].forEach((attributeName, _value) {
      final threeAttributeName =
          ATTRIBUTES[attributeName] ?? attributeName.toLowerCase();

      if (gltfAttributeMap[attributeName] != null) {
        final accessorDef =
            json["accessors"][primitive["attributes"][attributeName]];
        final componentType = WEBGL_COMPONENT_TYPES[accessorDef["componentType"]];

        attributeTypeMap[threeAttributeName] = componentType;
        attributeNormalizedMap[threeAttributeName] =
            accessorDef["normalized"] == true;
      }
    });

    final bufferView =
        await parser.getDependency('bufferView', bufferViewIndex);

    final completer = Completer<dynamic>();

    dracoLoader.decodeDracoFile(bufferView, (geometry) {
      geometry.attributes.forEach((attributeName, _value) {
        final attribute = geometry.attributes[attributeName];
        final normalized = attributeNormalizedMap[attributeName];

        if (normalized != null) attribute.normalized = normalized;
      });

      completer.complete(geometry);
    }, threeAttributeMap, attributeTypeMap);

    return completer.future;
  }
}

/**
 * Texture Transform Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_transform
 */
class GLTFTextureTransformExtension extends GLTFExtension {
  String name = extensions["KHR_TEXTURE_TRANSFORM"]!;

  Texture extendTexture(Texture texture, transform) {
    texture = texture.clone();

    if (transform.offset != null) {
      texture.offset.fromArray(transform.offset);
    }

    if (transform.rotation != null) {
      texture.rotation = transform.rotation;
    }

    if (transform.scale != null) {
      texture.repeat.fromArray(transform.scale);
    }

    if (transform.texCoord != null) {
      print('THREE.GLTFLoader: Custom UV sets in ${this.name} extension not yet supported.');
    }

    texture.needsUpdate = true;

    return texture;
  }
}

class GLTFMaterialsPbrSpecularGlossinessExtension extends GLTFExtension {
  String name = extensions["KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS"]!;

  List<String> specularGlossinessParams = [
    'color',
    'map',
    'lightMap',
    'lightMapIntensity',
    'aoMap',
    'aoMapIntensity',
    'emissive',
    'emissiveIntensity',
    'emissiveMap',
    'bumpMap',
    'bumpScale',
    'normalMap',
    'normalMapType',
    'displacementMap',
    'displacementScale',
    'displacementBias',
    'specularMap',
    'specular',
    'glossinessMap',
    'glossiness',
    'alphaMap',
    'envMap',
    'envMapIntensity',
  ];

  GLTFMaterialsPbrSpecularGlossinessExtension() {
    this.getMaterialType = (materialIndex) {
      return GLTFMeshStandardSGMaterial;
    };
  }

  extendParams(materialParams, materialDef, GLTFParser parser) async {
    final pbrSpecularGlossiness = materialDef.extensions[this.name];

    materialParams.color = Color(1.0, 1.0, 1.0);
    materialParams.opacity = 1.0;

    List<Future> pending = [];

    if (pbrSpecularGlossiness.diffuseFactor is List) {
      final array = pbrSpecularGlossiness.diffuseFactor;

      materialParams.color.fromArray(array);
      materialParams.opacity = array[3];
    }

    if (pbrSpecularGlossiness.diffuseTexture != null) {
      pending.add(parser.assignTexture(
          materialParams, 'map', pbrSpecularGlossiness.diffuseTexture, sRGBEncoding));
    }

    materialParams.emissive = Color(0.0, 0.0, 0.0);
    materialParams.glossiness = pbrSpecularGlossiness.glossinessFactor != null
        ? pbrSpecularGlossiness.glossinessFactor
        : 1.0;
    materialParams.specular = Color(1.0, 1.0, 1.0);

    if (pbrSpecularGlossiness.specularFactor is List) {
      materialParams.specular.fromArray(pbrSpecularGlossiness.specularFactor);
    }

    if (pbrSpecularGlossiness.specularGlossinessTexture != null) {
      final specGlossMapDef = pbrSpecularGlossiness.specularGlossinessTexture;
      pending.add(parser.assignTexture(
          materialParams, 'glossinessMap', specGlossMapDef));
      pending.add(
          parser.assignTexture(materialParams, 'specularMap', specGlossMapDef, sRGBEncoding));
    }

    return Future.wait(pending);
  }

  GLTFMeshStandardSGMaterial createMaterial(materialParams) {
    final material = GLTFMeshStandardSGMaterial(materialParams);
    material.fog = true;

    material.color = materialParams.color;

    material.map = materialParams.map == null ? null : materialParams.map;

    material.lightMap = null;
    material.lightMapIntensity = 1.0;

    material.aoMap = materialParams.aoMap == null ? null : materialParams.aoMap;
    material.aoMapIntensity = 1.0;

    material.emissive = materialParams.emissive;
    material.emissiveIntensity = 1.0;
    material.emissiveMap =
        materialParams.emissiveMap == null ? null : materialParams.emissiveMap;

    material.bumpMap =
        materialParams.bumpMap == null ? null : materialParams.bumpMap;
    material.bumpScale = 1;

    material.normalMap =
        materialParams.normalMap == null ? null : materialParams.normalMap;
    material.normalMapType = TangentSpaceNormalMap;

    if (materialParams.normalScale)
      material.normalScale = materialParams.normalScale;

    material.displacementMap = null;
    material.displacementScale = 1;
    material.displacementBias = 0;

    material.specularMap =
        materialParams.specularMap == null ? null : materialParams.specularMap;
    material.specular = materialParams.specular;

    material.glossinessMap = materialParams.glossinessMap == null
        ? null
        : materialParams.glossinessMap;
    material.glossiness = materialParams.glossiness;

    material.alphaMap = null;

    material.envMap =
        materialParams.envMap == null ? null : materialParams.envMap;
    material.envMapIntensity = 1.0;

    return material;
  }
}

/**
 * Mesh Quantization Extension
 *
 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_mesh_quantization
 */
class GLTFMeshQuantizationExtension extends GLTFExtension {
  String name = extensions["KHR_MESH_QUANTIZATION"]!;
}
