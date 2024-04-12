import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import 'shader_pass.dart';

class LUTPass extends ShaderPass {
  LUTPass(Map<String, dynamic> options):super.fromJson(lutShader) {
    this.lut = options["lut"] ?? null;
    this.intensity = options["intensity"] ?? 1;
  }

  set lut(v) {
    final material = this.material;

    if (v != this.lut) {
      material.uniforms["lut3d"]["value"] = null;
      material.uniforms["lut"]["value"] = null;

      if (v != null) {
        final is3dTextureDefine = v is Data3DTexture ? 1 : 0;
        if (is3dTextureDefine != material.defines!["USE_3DTEXTURE"]) {
          material.defines!["USE_3DTEXTURE"] = is3dTextureDefine;
          material.needsUpdate = true;
        }

        if (v is Data3DTexture) {
          material.uniforms["lut3d"]["value"] = v;
        } 
        else {
          material.uniforms["lut"]["value"] = v;
          material.uniforms["lutSize"]["value"] = v.image.width;
        }
      }
    }
  }

  num get lut {
    return this.material.uniforms["lut"]["value"] ?? this.material.uniforms["lut3d"]["value"];
  }

  set intensity(num v) {
    this.material.uniforms["intensity"]["value"] = v;
  }

  num get intensity {
    return this.material.uniforms["intensity"]["value"];
  }
}
