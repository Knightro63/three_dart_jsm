import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

class WebgpuRtt extends StatefulWidget {
  final String fileName;
  const WebgpuRtt({Key? key, required this.fileName}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<WebgpuRtt> {
  three_jsm.WebGPURenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;
  late three.Mesh mesh;

  num dpr = 1.0;

  ui.Image? img;

  bool verbose = false;
  bool disposed = false;

  bool loaded = false;

  late three.Object3D box;

  late three.Texture texture;

  late three.WebGLRenderTarget renderTarget;

  @override
  void initState() {
    super.initState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    width = 256.0;
    height = 256.0;
    init();
  }

  void initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return SingleChildScrollView(child: _build(context));
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Text("render"),
        onPressed: () {
          clickRender();
        },
      ),
    );
  }

  Widget _build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          child: Stack(
            children: [
              Container(
                color: Colors.black,
                width: width.toDouble(),
                height: height.toDouble(),
                child: RawImage(image: img),
              )
            ],
          ),
        ),
      ],
    );
  }

  void init() {
    camera = three.PerspectiveCamera( 70, width / height, 0.1, 100 );
    camera.position.z = 40;

    scene = three.Scene();
    scene.background = three.Color( 0x0000ff );

    // textured mesh

    final geometryBox = three.BoxGeometry(10, 10, 10);
    final materialBox = three_jsm.MeshBasicNodeMaterial(null);
    materialBox.colorNode = three_jsm.ColorNode( three.Color(1.0, 1.0, 0.0) );

    box = three.Mesh( geometryBox, materialBox );

    box.rotation.set(0.1, 0.5, 1.2);

    scene.add( box );

    camera.lookAt(scene.position);

    renderer = three_jsm.WebGPURenderer({
      "width": width.toInt(),
      "height": height.toInt(),
      "antialias": false,
      "sampleCount": 1
    });
    dpr = 1.0;
    renderer!.setPixelRatio( dpr );
    renderer!.setSize( width.toInt(), height.toInt() );
    renderer!.init();

    final pars = three.WebGLRenderTargetOptions({"format": three.RGBAFormat, "samples": 1});
    renderTarget = three.WebGLRenderTarget(
        (width * dpr).toInt(), (height * dpr).toInt(), pars);
    renderer!.setRenderTarget(renderTarget);
    // sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
  }

  void animate() {
    box.rotation.x += 0.01;
    box.rotation.y += 0.02;
    box.rotation.z += 0.04;

    renderer!.render( scene, camera );

    final pixels = renderer!.getPixels();

    final target = three.Vector2();
    renderer!.getSize(target);

    // print(" -----------target: ${target.x} ${target.y}----------- pixels: ${pixels} ");

    if (pixels != null) {
      ui.decodeImageFromPixels(pixels!, target.x.toInt(), target.y.toInt(), ui.PixelFormat.rgba8888,
          (image) {
        setState(() {
          img = image;
        });
      });
    }

    // Future.delayed(const Duration(milliseconds: 33), () {
    //   animate();
    // });
  }

  void clickRender() {
    print(" click render .... ");
    animate();
  }

  @override
  void dispose() {
    print(" dispose ............. ");
    disposed = true;

    super.dispose();
  }
}
