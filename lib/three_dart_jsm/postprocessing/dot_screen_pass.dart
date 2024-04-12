import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import "pass.dart";

class DotScreenPass extends Pass {
  DotScreenPass(Vector2? center, num? angle, num? scale) : super() {
    if (dotScreenShader == null) {
      print('THREE.DotScreenPass relies on DotScreenShader');
    }

    var shader = dotScreenShader;

    this.uniforms = UniformsUtils.clone(shader["uniforms"]);

    if (center != null) this.uniforms['center']["value"].copy(center);
    if (angle != null) this.uniforms['angle']["value"] = angle;
    if (scale != null) this.uniforms['scale']["value"] = scale;

    this.material = new ShaderMaterial({
      "uniforms": this.uniforms,
      "vertexShader": shader["vertexShader"],
      "fragmentShader": shader["fragmentShader"]
    });

    this.fsQuad = new FullScreenQuad(this.material);
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    this.uniforms['tDiffuse']["value"] = readBuffer.texture;
    this.uniforms['tSize']["value"].set(readBuffer.width, readBuffer.height);

    if (this.renderToScreen) {
      renderer.setRenderTarget(null);
      this.fsQuad.render(renderer);
    } else {
      renderer.setRenderTarget(writeBuffer);
      if (this.clear) renderer.clear();
      this.fsQuad.render(renderer);
    }
  }
}
