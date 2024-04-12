import 'dart:async';
import 'package:three_dart/three_dart.dart';
/**
 * Loads a Wavefront .mtl file specifying materials
 */

class MTLLoader extends Loader {
  dynamic materialOptions;

  MTLLoader([LoadingManager? manager]) : super(manager) {}

  loadAsync(url) async {
    final completer = Completer();

    load(url, (result) {
      completer.complete(result);
    });

    return completer.future;
  }

  /**
	 * Loads and parses a MTL asset from a URL.
	 *
	 * @param {String} url - URL to the MTL file.
	 * @param {Function} [onLoad] - Callback invoked with the loaded object.
	 * @param {Function} [onProgress] - Callback for download progress.
	 * @param {Function} [onError] - Callback for download errors.
	 *
	 * @see setPath setResourcePath
	 *
	 * @note In order for relative texture references to resolve correctly
	 * you must call setResourcePath() explicitly prior to load.
	 */
  load(url, Function onLoad, [Function? onProgress, Function? onError]) {
    final scope = this;

    final path = (this.path == '') ? LoaderUtils.extractUrlBase(url) : this.path;

    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setRequestHeader(this.requestHeader);
    loader.setWithCredentials(this.withCredentials);
    loader.load(url, (text) {
      // try {

      if (onLoad != null) onLoad(scope.parse(text, path));

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

  MTLLoader etMaterialOptions(value) {
    this.materialOptions = value;
    return this;
  }

  /**
	 * Parses a MTL file.
	 *
	 * @param {String} text - Content of MTL file
	 * @return {MaterialCreator}
	 *
	 * @see setPath setResourcePath
	 *
	 * @note In order for relative texture references to resolve correctly
	 * you must call setResourcePath() explicitly prior to parse.
	 */
  parse(text, [String? path, Function? onLoad, Function? onError]) {
    List<String> lines = text.split('\n');
    Map<String,dynamic> info = {};
    final delimiter_pattern = RegExp(r"\s+");
    final materialsInfo = {};

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      line = line.trim();

      if (line.length == 0 || line[0] == '#') {
        // Blank line or comment ignore
        continue;
      }

      final pos = line.indexOf(' ');

      String key = (pos >= 0) ? line.substring(0, pos) : line;
      key = key.toLowerCase();

      String value = (pos >= 0) ? line.substring(pos + 1) : '';
      value = value.trim();

      if (key == 'newmtl') {
        // New material

        info = {"name": value};
        materialsInfo[value] = info;
      } else {
        if (key == 'ka' || key == 'kd' || key == 'ks' || key == 'ke') {
          final ss = value.split(delimiter_pattern);
          info[key] = [parseFloat(ss[0]), parseFloat(ss[1]), parseFloat(ss[2])];
        } else {
          info[key] = value;
        }
      }
    }

    final materialCreator = MaterialCreator(
        this.resourcePath != "" ? this.resourcePath : path,
        this.materialOptions);
    materialCreator.setCrossOrigin(this.crossOrigin);
    materialCreator.setManager(this.manager);
    materialCreator.setMaterials(materialsInfo);
    return materialCreator;
  }
}

/**
 * Create a MTLLoader.MaterialCreator
 * @param baseUrl - Url relative to which textures are loaded
 * @param options - Set of options on how to construct the materials
 *                  side: Which side to apply the material
 *                        FrontSide (default), THREE.BackSide, THREE.DoubleSide
 *                  wrap: What type of wrapping to apply for textures
 *                        RepeatWrapping (default), THREE.ClampToEdgeWrapping, THREE.MirroredRepeatWrapping
 *                  normalizeRGB: RGBs need to be normalized to 0-1 from 0-255
 *                                Default: false, assumed to be already normalized
 *                  ignoreZeroRGBs: Ignore values of RGBs (Ka,Kd,Ks) that are all 0's
 *                                  Default: false
 * @constructor
 */

class MaterialCreator {
  late String baseUrl;
  late Map<String, dynamic> options;
  late Map<String, dynamic> materialsInfo;
  late Map<String, dynamic> materials;
  late List materialsArray;
  late Map<String, dynamic> nameLookup;
  late String crossOrigin;
  late int side;
  late int wrap;

  dynamic manager;

  MaterialCreator(baseUrl, options) {
    this.baseUrl = baseUrl ?? "";
    this.options = options ?? {};
    this.materialsInfo = {};
    this.materials = {};
    this.materialsArray = [];
    this.nameLookup = {};

    this.crossOrigin = 'anonymous';

    this.side =
        (this.options["side"] != null) ? this.options["side"] : FrontSide;
    this.wrap =
        (this.options["wrap"] != null) ? this.options["wrap"] : RepeatWrapping;
  }

  MaterialCreator setCrossOrigin(value) {
    this.crossOrigin = value;
    return this;
  }

  void setManager(value) {
    this.manager = value;
  }

  void setMaterials(materialsInfo) {
    this.materialsInfo = this.convert(materialsInfo);
    this.materials = {};
    this.materialsArray = [];
    this.nameLookup = {};
  }

  Map<String, dynamic> convert(materialsInfo) {
    // TODO options can be null? or have default value
    if (this.options == null) return materialsInfo;

    Map<String, dynamic> converted = {};

    for (final mn in materialsInfo.keys) {
      // Convert materials info into normalized form based on options

      final mat = materialsInfo[mn];

      Map<String, dynamic> covmat = {};

      converted[mn] = covmat;

      for (final prop in mat.keys) {
        bool save = true;
        dynamic value = mat[prop];
        final lprop = prop.toLowerCase();

        switch (lprop) {
          case 'kd':
          case 'ka':
          case 'ks':

            // Diffuse color (color under white light) using RGB values

            if (this.options != null && this.options["normalizeRGB"] != null) {
              value = [value[0] / 255, value[1] / 255, value[2] / 255];
            }

            if (this.options != null &&
                this.options["ignoreZeroRGBs"] != null) {
              if (value[0] == 0 && value[1] == 0 && value[2] == 0) {
                // ignore

                save = false;
              }
            }

            break;

          default:
            break;
        }

        if (save) {
          covmat[lprop] = value;
        }
      }
    }

    return converted;
  }

  void preload() async {
    for (final mn in this.materialsInfo.keys) {
      await this.create(mn);
    }
  }

  getIndex(materialName) {
    return this.nameLookup[materialName];
  }

  getAsArray() async {
    int index = 0;

    for (final mn in this.materialsInfo.keys) {
      this.materialsArray[index] = await this.create(mn);
      this.nameLookup[mn] = index;
      index++;
    }

    return this.materialsArray;
  }

  create(materialName) async {
    if (this.materials[materialName] == null) {
      await this.createMaterial_(materialName);
    }

    return this.materials[materialName];
  }

  createMaterial_(materialName) async {
    // Create material

    final scope = this;
    final mat = this.materialsInfo[materialName];
    final params = {"name": materialName, "side": this.side};

    final resolveURL = (baseUrl, url) {
      if (!(url is String) || url == '') return '';

      // Absolute URL
      final _reg = RegExp(r"^https?:\/\/", caseSensitive: false);
      if (_reg.hasMatch(url)) return url;

      return baseUrl + url;
    };

    final setMapForType = (mapType, value) async {
      if (params[mapType] != null) return; // Keep the first encountered texture

      final texParams = scope.getTextureParams(value, params);

      final map = await scope.loadTexture(
          resolveURL(scope.baseUrl, texParams["url"]), null, null, null, null);

      map?.repeat.copy(texParams["scale"]);
      map?.offset.copy(texParams["offset"]);

      map?.wrapS = scope.wrap;
      map?.wrapT = scope.wrap;

      params[mapType] = map;
    };

    for (final prop in mat.keys) {
      final value = mat[prop];
      double n;

      if (value == '') continue;

      switch (prop.toLowerCase()) {

        // Ns is material specular exponent

        case 'kd':

          // Diffuse color (color under white light) using RGB values

          params["color"] = Color(1, 1, 1).fromArray(value);

          break;

        case 'ks':

          // Specular color (color when light is reflected from shiny surface) using RGB values
          params["specular"] = Color(1, 1, 1).fromArray(value);

          break;

        case 'ke':

          // Emissive using RGB values
          params["emissive"] = Color(1, 1, 1).fromArray(value);

          break;

        case 'map_kd':

          // Diffuse texture map

          await setMapForType('map', value);

          break;

        case 'map_ks':

          // Specular map

          await setMapForType('specularMap', value);

          break;

        case 'map_ke':

          // Emissive map

          await setMapForType('emissiveMap', value);

          break;

        case 'norm':
          await setMapForType('normalMap', value);

          break;

        case 'map_bump':
        case 'bump':

          // Bump texture map

          await setMapForType('bumpMap', value);

          break;

        case 'map_d':

          // Alpha map

          await setMapForType('alphaMap', value);
          params["transparent"] = true;

          break;

        case 'ns':

          // The specular exponent (defines the focus of the specular highlight)
          // A high exponent results in a tight, concentrated highlight. Ns values normally range from 0 to 1000.

          params["shininess"] = parseFloat(value);

          break;

        case 'd':
          n = parseFloat(value);

          if (n < 1) {
            params["opacity"] = n;
            params["transparent"] = true;
          }

          break;

        case 'tr':
          n = parseFloat(value);

          if (this.options != null && this.options["invertTrProperty"])
            n = 1 - n;

          if (n > 0) {
            params["opacity"] = 1 - n;
            params["transparent"] = true;
          }

          break;

        default:
          break;
      }
    }

    this.materials[materialName] = MeshPhongMaterial(params);
    return this.materials[materialName];
  }

  getTextureParams(String value, matParams) {
    Map<String, dynamic> texParams = {
      "scale": Vector2(1, 1),
      "offset": Vector2(0, 0)
    };

    final items = value.split(RegExp(r"\s+"));
    int pos;

    pos = items.indexOf('-bm');

    if (pos >= 0) {
      matParams.bumpScale = parseFloat(items[pos + 1]);
      splice(items, pos, 2);
    }

    pos = items.indexOf('-s');

    if (pos >= 0) {
      texParams["scale"]!
          .set(parseFloat(items[pos + 1]), parseFloat(items[pos + 2]));
      splice(items, pos, 4); // we expect 3 parameters here!

    }

    pos = items.indexOf('-o');

    if (pos >= 0) {
      texParams["offset"]!
          .set(parseFloat(items[pos + 1]), parseFloat(items[pos + 2]));
      splice(items, pos, 4); // we expect 3 parameters here!

    }

    texParams["url"] = items.join(' ').trim();
    return texParams;
  }

  Future<Texture?> loadTexture(url, mapping, onLoad, onProgress, onError) async {
    final manager = (this.manager != null) ? this.manager : defaultLoadingManager;
     TextureLoader? loader = manager.getHandler(url);

    if (loader == null) {
      loader = TextureLoader(manager);
      loader.flipY = true;
    }

    if (loader.setCrossOrigin != null) loader.setCrossOrigin(this.crossOrigin);

    // final texture = loader.load( url, onLoad, onProgress, onError );
    final texture = await loader.fromAsset(url);

    if (mapping != null) texture?.mapping = mapping;

    return texture;
  }
}
