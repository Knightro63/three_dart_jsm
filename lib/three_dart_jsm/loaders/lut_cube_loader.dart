import 'dart:async';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:three_dart/three_dart.dart';

// https://wwwimages2.adobe.com/content/dam/acom/en/products/speedgrade/cc/pdfs/cube-lut-specification-1.0.pdf

class LUTCubeLoaderData {
  LUTCubeLoaderData({
    this.title,
    required this.size,
    required this.domainMax,
    required this.domainMin,
    this.texture,
    this.texture3D
  });

  String? title;
  num size;
  Vector3 domainMin;
  Vector3 domainMax;
  DataTexture? texture;
  Data3DTexture? texture3D;
}

class LUTCubeLoader extends Loader {
  LUTCubeLoader([LoadingManager? manager]) : super(manager) {}

  @override
  Future loadAsync(url) async {
    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setResponseType('text');
    final resp = await loader.loadAsync(url);

    return this.parse(resp);
  }
  @override
  void load(url, Function? onLoad, [Function? onProgress, Function? onError]) async {
    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setResponseType('text');
    final data = loader.load(url, (text) {
      // try {
      if (onLoad != null) {
        onLoad(this.parse(text));
      }
      // } catch ( e ) {

      // 	if ( onError != null ) {

      // 		onError( e );

      // 	} else {

      // 		print( e );

      // 	}

      // 	this.manager.itemError( url );

      // }
    }, onProgress, onError);

    return data;
  }

  LUTCubeLoaderData parse(str, [String? path, Function? onLoad, Function? onError]) {
    // Remove empty lines and comments
    // str = str
    // 	.replace( /^#.*?(\n|\r)/gm, '' )
    // 	.replace( /^\s*?(\n|\r)/gm, '' )
    // 	.trim();

    final reg = RegExp(r"^#.*?(\n|\r)", multiLine: true);
    str = str.replaceAll(reg, "");

    final reg2 = RegExp(r"^\s*?(\n|\r)", multiLine: true);
    str = str.replaceAll(reg2, "");
    str = str.trim();

    String? title = null;
    int size = 0;
    final domainMin = Vector3(0, 0, 0);
    final domainMax = Vector3(1, 1, 1);

    final reg3 = RegExp(r"[\n\r]+");
    final lines = str.split(reg3);
    Uint8Array? data;

    int currIndex = 0;
    for (int i = 0, l = lines.length; i < l; i++) {
      final line = lines[i].trim();
      final split = line.split(RegExp(r"\s"));

      switch (split[0]) {
        case 'TITLE':
          title = line.substring(7, line.length - 1);
          break;
        case 'LUT_3D_SIZE':
          // TODO: A .CUBE LUT file specifies floating point values and could be represented with
          // more precision than can be captured with Uint8Array.
          final sizeToken = split[1];
          size = parseFloat(sizeToken).toInt();
          data = Uint8Array(size * size * size * 4);
          break;
        case 'DOMAIN_MIN':
          domainMin.x = parseFloat(split[1]);
          domainMin.y = parseFloat(split[2]);
          domainMin.z = parseFloat(split[3]);
          break;
        case 'DOMAIN_MAX':
          domainMax.x = parseFloat(split[1]);
          domainMax.y = parseFloat(split[2]);
          domainMax.z = parseFloat(split[3]);
          break;
        default:
          final r = parseFloat(split[0]);
          final g = parseFloat(split[1]);
          final b = parseFloat(split[2]);

          if (r > 1.0 || r < 0.0 || g > 1.0 || g < 0.0 || b > 1.0 || b < 0.0) {
            throw ('LUTCubeLoader : Non normalized values not supported.');
          }

          data![currIndex + 0] = (r * 255).toInt();
          data[currIndex + 1] = (g * 255).toInt();
          data[currIndex + 2] = (b * 255).toInt();
          data[currIndex + 3] = 255;
          currIndex += 4;
      }
    }

    final texture = DataTexture();
    texture.image!.data = data;
    texture.image!.width = size;
    texture.image!.height = size * size;
    texture.type = UnsignedByteType;
    texture.magFilter = LinearFilter;
    texture.wrapS = ClampToEdgeWrapping;
    texture.wrapT = ClampToEdgeWrapping;
    texture.generateMipmaps = false;

    final texture3D = Data3DTexture();
    texture3D.image!.data = data;
    texture3D.image!.width = size;
    texture3D.image!.height = size;
    texture3D.image!.depth = size;
    texture3D.type = UnsignedByteType;
    texture3D.magFilter = LinearFilter;
    texture3D.wrapS = ClampToEdgeWrapping;
    texture3D.wrapT = ClampToEdgeWrapping;
    texture3D.wrapR = ClampToEdgeWrapping;
    texture3D.generateMipmaps = false;

    return LUTCubeLoaderData(
      title: title,
      size: size,
      domainMin: domainMin,
      domainMax: domainMax,
      texture: texture,
      texture3D: texture3D,
    );
  }
}
