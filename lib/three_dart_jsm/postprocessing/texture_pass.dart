import 'package:three_dart/three_dart.dart';
import 'pass.dart';
import '../shaders/copy_shader.dart';

class TexturePass extends Pass {
  late Texture map;
  late num opacity;
  late Map<String, dynamic> uniforms;
  // ShaderMaterial material;
  // dynamic fsQuad;

  TexturePass(map, opacity) : super() {
    if (copyShader == null){
      print('THREE.TexturePass relies on CopyShader');
    }

    var shader = copyShader;

    this.map = map;
    this.opacity = (opacity != null) ? opacity : 1.0;

    this.uniforms = UniformsUtils.clone(shader["uniforms"]);

    this.material = new ShaderMaterial({
      "uniforms": this.uniforms,
      "vertexShader": shader["vertexShader"],
      "fragmentShader": shader["fragmentShader"],
      "depthTest": false,
      "depthWrite": false
    });

    this.needsSwap = false;

    this.fsQuad = FullScreenQuad(null);
  }

  void render(renderer, writeBuffer, readBuffer,
      {num? deltaTime, bool? maskActive}) {
    var oldAutoClear = renderer.autoClear;
    renderer.autoClear = false;

    this.fsQuad.material = this.material;

    this.uniforms['opacity']["value"] = this.opacity;
    this.uniforms['tDiffuse']["value"] = this.map;
    this.material.transparent = (this.opacity < 1.0);

    renderer.setRenderTarget(this.renderToScreen ? null : readBuffer);
    if (this.clear) renderer.clear(true, true, true);
    this.fsQuad.render(renderer);

    renderer.autoClear = oldAutoClear;
  }
}
