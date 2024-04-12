part of three_webgpu;

int _clearAlpha = 0;
final _clearColor = Color();

class WebGPUBackground {
  late WebGPURenderer renderer;
  late bool forceClear;

  WebGPUBackground(renderer) {
    this.renderer = renderer;

    this.forceClear = false;
  }

  void clear() {
    this.forceClear = true;
  }

  void update(Scene scene) {
    final renderer = this.renderer;
    final background = scene.background;
    bool forceClear = this.forceClear;

    if (background == null) {
      // no background settings, use clear color configuration from the renderer

      _clearColor.copy(renderer._clearColor);
      _clearAlpha = renderer._clearAlpha;
    } else if (background.isColor == true) {
      // background is an opaque color

      _clearColor.copy(background);
      _clearAlpha = 1;
      forceClear = true;
    } else {
      Console.error(
          'THREE.WebGPURenderer: Unsupported background configuration.',
          background);
    }

    // configure render pass descriptor

    final renderPassDescriptor = renderer._renderPassDescriptor;
    final colorAttachment = renderPassDescriptor.colorAttachments;
    final depthStencilAttachment = renderPassDescriptor.depthStencilAttachment;

    if (renderer.autoClear == true || forceClear == true) {
      if (renderer.autoClearColor == true) {
        // colorAttachment.loadValue = { "r": _clearColor.r, "g": _clearColor.g, "b": _clearColor.b, "a": _clearAlpha };
        colorAttachment.clearColor = GPUColor(
            r: _clearColor.r.toDouble(),
            g: _clearColor.g.toDouble(),
            b: _clearColor.b.toDouble(),
            a: _clearAlpha.toDouble());
      } else {
        colorAttachment.loadValue = GPULoadOp.Load;
      }

      if (renderer.autoClearDepth == true) {
        // depthStencilAttachment.clearDepth = renderer._clearDepth.toDouble();

      } else {
        // depthStencilAttachment.depthLoadValue = GPULoadOp.Load;

      }

      if (renderer.autoClearStencil == true) {
        // depthStencilAttachment.clearStencil = renderer._clearStencil;

      } else {
        // depthStencilAttachment.stencilLoadValue = GPULoadOp.Load;

      }
    } else {
      colorAttachment.loadValue = GPULoadOp.Load;
      // depthStencilAttachment.depthLoadValue = GPULoadOp.Load;
      // depthStencilAttachment.stencilLoadValue = GPULoadOp.Load;

    }

    this.forceClear = false;
  }
}
