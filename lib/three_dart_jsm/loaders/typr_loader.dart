import 'dart:async';
import 'dart:typed_data';
import 'package:three_dart/three_dart.dart';
import 'package:typr_dart/typr_dart.dart' as typr_dart;

/**
 * Requires opentype.js to be included in the project.
 * Loads TTF files and converts them into typeface JSON that can be used directly
 * to create THREE.Font objects.
 */

class TYPRLoader extends Loader {
  bool reversed = false;

  TYPRLoader([LoadingManager? manager]) : super(manager) {}

  Future<dynamic> loadAsync(url) async {
    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setResponseType('arraybuffer');
    loader.setRequestHeader(this.requestHeader);
    loader.setWithCredentials(this.withCredentials);
    final buffer = await loader.loadAsync(url);

    return this._parse(buffer);
  }

  dynamic load(url, Function? onLoad, [Function? onProgress, Function? onError]) {
    final scope = this;

    final loader = FileLoader(this.manager);
    loader.setPath(this.path);
    loader.setResponseType('arraybuffer');
    loader.setRequestHeader(this.requestHeader);
    loader.setWithCredentials(this.withCredentials);
    loader.load(url, (buffer) {
      // try {

      if (onLoad != null) onLoad(scope._parse(buffer));

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

  Map<String,dynamic> _parse(Uint8List arraybuffer) {
    Map<String,dynamic> convert(typr_dart.Font font, bool reversed) {
      // final round = Math.round;

      // final glyphs = {};
      // final scale = (100000) / ((font.head["unitsPerEm"] ?? 2048) * 72);

      // final numGlyphs = font.maxp["numGlyphs"];

      // for ( final i = 0; i < numGlyphs; i ++ ) {

      // 	final path = font.glyphToPath(i);

      //   // print(path);

      // 	if ( path != null ) {
      //     final aWidths = font.hmtx["aWidth"];

      //     path["ha"] = round( aWidths[i] * scale );

      //     final crds = path["crds"];
      //     List<num> _scaledCrds = [];

      //     crds.forEach((nrd) {
      //       _scaledCrds.add(nrd * scale);
      //     });

      //     path["crds"] = _scaledCrds;

      // 		glyphs[i ] = path;

      // 	}

      // }

      return {
        "font": font,
        "familyName": font.getFamilyName(),
        "fullName": font.getFullName(),
        "underlinePosition": font.post["underlinePosition"],
        "underlineThickness": font.post["underlineThickness"],
        "boundingBox": {
          "xMin": font.head["xMin"],
          "xMax": font.head["xMax"],
          "yMin": font.head["yMin"],
          "yMax": font.head["yMax"]
        },
        "resolution": 1000,
        "original_font_information": font.name
      };
    }

    return convert(typr_dart.Font(arraybuffer), this.reversed); // eslint-disable-line no-undef
  }
}
