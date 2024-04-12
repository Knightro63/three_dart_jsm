import 'dart:typed_data';
import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import "pass.dart";

class GlitchPass extends Pass {
  bool goWild = false;
  num curF = 0;
  late num randX;

  GlitchPass(int? dt_size) : super() {
    if (digitalGlitch == null) {
      print('THREE.GlitchPass relies on DigitalGlitch');
    }

    final shader = digitalGlitch;
    this.uniforms = UniformsUtils.clone(shader["uniforms"]);

    if (dt_size == null) dt_size = 64;

    this.uniforms['tDisp']["value"] = this.generateHeightmap(dt_size);

    this.material = ShaderMaterial({
      "uniforms": this.uniforms,
      "vertexShader": shader["vertexShader"],
      "fragmentShader": shader["fragmentShader"]
    });

    this.fsQuad = FullScreenQuad(this.material);
    this.generateTrigger();
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    this.uniforms['tDiffuse']["value"] = readBuffer.texture;
    this.uniforms['seed']["value"] = Math.random(); //default seeding
    this.uniforms['byp']["value"] = 0;

    if (this.curF % this.randX == 0 || this.goWild == true) {
      this.uniforms['amount']["value"] = Math.random() / 30;
      this.uniforms['angle']["value"] = MathUtils.randFloat(-Math.pi, Math.pi);
      this.uniforms['seed_x']["value"] = MathUtils.randFloat(-1, 1);
      this.uniforms['seed_y']["value"] = MathUtils.randFloat(-1, 1);
      this.uniforms['distortion_x']["value"] = MathUtils.randFloat(0, 1);
      this.uniforms['distortion_y']["value"] = MathUtils.randFloat(0, 1);
      this.curF = 0;
      this.generateTrigger();
    } else if (this.curF % this.randX < this.randX / 5) {
      this.uniforms['amount']["value"] = Math.random() / 90;
      this.uniforms['angle']["value"] = MathUtils.randFloat(-Math.pi, Math.pi);
      this.uniforms['distortion_x']["value"] = MathUtils.randFloat(0, 1);
      this.uniforms['distortion_y']["value"] = MathUtils.randFloat(0, 1);
      this.uniforms['seed_x']["value"] = MathUtils.randFloat(-0.3, 0.3);
      this.uniforms['seed_y']["value"] = MathUtils.randFloat(-0.3, 0.3);
    } else if (this.goWild == false) {
      this.uniforms['byp']["value"] = 1;
    }

    this.curF++;

    if (this.renderToScreen) {
      renderer.setRenderTarget(null);
      this.fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);
      if (this.clear) renderer.clear();
      this.fsQuad.render(renderer);
    }
  }

  void generateTrigger() {
    this.randX = MathUtils.randInt(120, 240);
  }

  DataTexture generateHeightmap(dt_size) {
    final data_arr = Float32List(dt_size * dt_size * 3);
    final length = dt_size * dt_size;

    for (int i = 0; i < length; i++) {
      final val = MathUtils.randFloat(0, 1);
      data_arr[i * 3 + 0] = val;
      data_arr[i * 3 + 1] = val;
      data_arr[i * 3 + 2] = val;
    }

    return DataTexture(data_arr, dt_size, dt_size, RGBFormat, FloatType);
  }
}
