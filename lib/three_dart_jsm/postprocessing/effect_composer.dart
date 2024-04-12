import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';
import "pass.dart";
import 'shader_pass.dart';
import 'mask_pass.dart';
import '../shaders/copy_shader.dart';

class EffectComposer {
  late WebGLRenderer renderer;
  late WebGLRenderTarget renderTarget1;
  late WebGLRenderTarget renderTarget2;

  late WebGLRenderTarget writeBuffer;
  late WebGLRenderTarget readBuffer;

  bool renderToScreen = true;

  double _pixelRatio = 1.0;
  late int _width;
  late int _height;

  List<Pass> passes = [];

  late Clock clock;

  late Pass copyPass;

  EffectComposer(WebGLRenderer renderer, WebGLRenderTarget? renderTarget) {
    this.renderer = renderer;

    if (renderTarget == null) {
      final parameters = {
        "minFilter": LinearFilter,
        "magFilter": LinearFilter,
        "format": RGBAFormat
      };

      final size = renderer.getSize(Vector2(null, null));
      this._pixelRatio = renderer.getPixelRatio();
      this._width = size.width.toInt();
      this._height = size.height.toInt();

      renderTarget = WebGLRenderTarget(
          (this._width * this._pixelRatio).toInt(),
          (this._height * this._pixelRatio).toInt(),
          WebGLRenderTargetOptions(parameters));
    } else {
      this._pixelRatio = 1;
      this._width = renderTarget.width;
      this._height = renderTarget.height;
    }

    this.renderTarget1 = renderTarget;
    this.renderTarget2 = renderTarget.clone();
    this.renderTarget2.texture.name = 'EffectComposer.rt2';

    this.writeBuffer = this.renderTarget1;
    this.readBuffer = this.renderTarget2;

    this.renderToScreen = true;

    this.passes = [];

    this.copyPass = ShaderPass.fromJson(copyShader);

    this.clock = Clock(false);
  }

  void swapBuffers() {
    final tmp = this.readBuffer;
    this.readBuffer = this.writeBuffer;
    this.writeBuffer = tmp;
  }

  void addPass(Pass pass) {
    this.passes.add(pass);
    pass.setSize((this._width * this._pixelRatio).toInt(), (this._height * this._pixelRatio).toInt());
  }

  void insertPass(Pass pass, int index) {
    splice(this.passes, index, 0, pass);
    pass.setSize((this._width * this._pixelRatio).toInt(), (this._height * this._pixelRatio).toInt());
  }

  void removePass(Pass pass) {
    final index = this.passes.indexOf(pass);

    if (index != -1) {
      splice(this.passes, index, 1);
    }
  }

  void clearPass() {
    this.passes.clear();
  }

  bool isLastEnabledPass(int passIndex) {
    for (int i = passIndex + 1; i < this.passes.length; i++) {
      if (this.passes[i].enabled) {
        return false;
      }
    }

    return true;
  }

  void render(num? deltaTime) {
    // deltaTime value is in seconds

    if (deltaTime == null) {
      deltaTime = this.clock.getDelta();
    }

    final currentRenderTarget = this.renderer.getRenderTarget();

    bool maskActive = false;

    Pass? pass;
    final il = this.passes.length;

    for (int i = 0; i < il; i++) {
      pass = this.passes[i];

      if (pass.enabled == false) continue;

      pass.renderToScreen = (this.renderToScreen && this.isLastEnabledPass(i));
      pass.render(this.renderer, this.writeBuffer, this.readBuffer,
          deltaTime: deltaTime, maskActive: maskActive);

      if (pass.needsSwap) {
        if (maskActive) {
          final context = this.renderer.getContext();
          final stencil = this.renderer.state.buffers["stencil"];

          //context.stencilFunc( context.NOTEQUAL, 1, 0xffffffff );
          stencil.setFunc(context.NOTEQUAL, 1, 0xffffffff);

          this.copyPass.render(this.renderer, this.writeBuffer, this.readBuffer,
              deltaTime: deltaTime);

          //context.stencilFunc( context.EQUAL, 1, 0xffffffff );
          stencil.setFunc(context.EQUAL, 1, 0xffffffff);
        }

        this.swapBuffers();
      }

      //if (pass != null) {
        if (pass is MaskPass) {
          maskActive = true;
        } 
        else if (pass is ClearMaskPass) {
          maskActive = false;
        }
      //}
    }

    this.renderer.setRenderTarget(currentRenderTarget);
  }

  void reset(WebGLRenderTarget? renderTarget) {
    if (renderTarget == null) {
      final size = this.renderer.getSize(Vector2());
      this._pixelRatio = this.renderer.getPixelRatio();
      this._width = size.width.toInt();
      this._height = size.height.toInt();

      renderTarget = this.renderTarget1.clone();
      renderTarget.setSize((this._width * this._pixelRatio).toInt(), (this._height * this._pixelRatio).toInt());
    }

    this.renderTarget1.dispose();
    this.renderTarget2.dispose();
    this.renderTarget1 = renderTarget;
    this.renderTarget2 = renderTarget.clone();

    this.writeBuffer = this.renderTarget1;
    this.readBuffer = this.renderTarget2;
  }

  void setSize(int width, int height) {
    this._width = width;
    this._height = height;

    int effectiveWidth = (this._width * this._pixelRatio).toInt();
    int effectiveHeight = (this._height * this._pixelRatio).toInt();

    this.renderTarget1.setSize(effectiveWidth, effectiveHeight);
    this.renderTarget2.setSize(effectiveWidth, effectiveHeight);

    for (int i = 0; i < this.passes.length; i++) {
      this.passes[i].setSize(effectiveWidth, effectiveHeight);
    }
  }

  void setPixelRatio(double pixelRatio) {
    this._pixelRatio = pixelRatio;

    this.setSize(this._width, this._height);
  }
}
