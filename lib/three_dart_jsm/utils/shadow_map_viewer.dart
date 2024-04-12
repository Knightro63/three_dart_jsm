import 'package:three_dart/three_dart.dart';
import 'package:three_dart_jsm/three_dart_jsm/shaders/index.dart';

// import { UnpackDepthRGBAShader } from '../shaders/UnpackDepthRGBAShader.js';

/**
 * This is a helper for visualising a given light's shadow map.
 * It works for shadow casting lights: DirectionalLight and SpotLight.
 * It renders out the shadow map and displays it on a HUD.
 *
 * Example usage:
 *	1) Import ShadowMapViewer into your app.
 *
 *	2) Create a shadow casting light and name it optionally:
 *		final light = new DirectionalLight( 0xffffff, 1 );
 *		light.castShadow = true;
 *		light.name = 'Sun';
 *
 *	3) Create a shadow map viewer for that light and set its size and position optionally:
 *		final shadowMapViewer = new ShadowMapViewer( light );
 *		shadowMapViewer.size.set( 128, 128 );	//width, height  default: 256, 256
 *		shadowMapViewer.position.set( 10, 10 );	//x, y in pixel	 default: 0, 0 (top left corner)
 *
 *	4) Render the shadow map viewer in your render loop:
 *		shadowMapViewer.render( renderer );
 *
 *	5) Optionally: Update the shadow map viewer on window resize:
 *		shadowMapViewer.updateForWindowResize();
 *
 *	6) If you set the position or size members directly, you need to call shadowMapViewer.update();
 */

class _Size{
  _Size(this.width,this.height);
  num width;
  num height;
}

class Position{
  Position(this.x,this.y);
  num x;
  num y;
}

class ShadowMapViewer {
  //- API
  // Set to false to disable displaying this shadow map
  bool enabled = true;
  bool userAutoClearSetting = false;

  late _Size size;
  late Position position;
  late Mesh mesh;

  late num innerHeight;
  late num innerWidth;

  late Map<String, num> frame;
  late Map<String, dynamic> uniforms;

  late Scene scene;
  late OrthographicCamera camera;

  late Light light;

  ShadowMapViewer(Light light, num innerWidth, num innerHeight) {
    this.light = light;
    this.innerWidth = innerWidth;
    this.innerHeight = innerHeight;

    //- Internals
    //final scope = this;
    //final doRenderLabel = light.name != '';

    //Holds the initial position and dimension of the HUD
    frame = {"x": 10, "y": 10, "width": 256, "height": 256};

    camera = new OrthographicCamera(innerWidth / -2, innerWidth / 2,
        innerHeight / 2, innerHeight / -2, 1, 10);
    camera.position.set(0, 0, 2);
    scene = new Scene();
    // scene.background = Color.fromHex(0xff00ff);

    //HUD for shadow map
    final shader = unpackDepthRGBAShader;

    uniforms = UniformsUtils.clone(shader["uniforms"]);
    final material = new ShaderMaterial({
      "uniforms": uniforms,
      "vertexShader": shader["vertexShader"],
      "fragmentShader": shader["fragmentShader"]
    });
    final plane = new PlaneGeometry(frame["width"]!, frame["height"]!);
    mesh = new Mesh(plane, material);

    scene.add(mesh);

    //Label for light's name
    // final labelCanvas, labelMesh;

    // if ( doRenderLabel ) {

    // 	labelCanvas = document.createElement( 'canvas' );

    // 	final context = labelCanvas.getContext( '2d' );
    // 	context.font = 'Bold 20px Arial';

    // 	final labelWidth = context.measureText( light.name ).width;
    // 	labelCanvas.width = labelWidth;
    // 	labelCanvas.height = 25;	//25 to account for g, p, etc.

    // 	context.font = 'Bold 20px Arial';
    // 	context.fillStyle = 'rgba( 255, 0, 0, 1 )';
    // 	context.fillText( light.name, 0, 20 );

    // 	final labelTexture = new Texture( labelCanvas );
    // 	labelTexture.magFilter = LinearFilter;
    // 	labelTexture.minFilter = LinearFilter;
    // 	labelTexture.needsUpdate = true;

    // 	final labelMaterial = new MeshBasicMaterial( { map: labelTexture, side: DoubleSide } );
    // 	labelMaterial.transparent = true;

    // 	final labelPlane = new PlaneGeometry( labelCanvas.width, labelCanvas.height );
    // 	labelMesh = new Mesh( labelPlane, labelMaterial );

    // 	scene.add( labelMesh );

    // }

    // Set the size of the displayed shadow map on the HUD
    this.size = _Size(frame["width"]!, frame["height"]!);
    // this.size = {
    // 	width: frame.width,
    // 	height: frame.height,
    // 	set: function ( width, height ) {

    // 		this.width = width;
    // 		this.height = height;

    // 		mesh.scale.set( this.width / frame.width, this.height / frame.height, 1 );

    // 		//Reset the position as it is off when we scale stuff
    // 		resetPosition();

    // 	}
    // };

    // Set the position of the displayed shadow map on the HUD
    this.position = Position(frame["x"]!, frame["y"]!);
    // this.position = {
    // 	x: frame.x,
    // 	y: frame.y,
    // 	set: function ( x, y ) {

    // 		this.x = x;
    // 		this.y = y;

    // 		final width = scope.size.width;
    // 		final height = scope.size.height;

    // 		mesh.position.set( - window.innerWidth / 2 + width / 2 + this.x, window.innerHeight / 2 - height / 2 - this.y, 0 );

    // 		if ( doRenderLabel ) labelMesh.position.set( mesh.position.x, mesh.position.y - scope.size.height / 2 + labelCanvas.height / 2, 0 );

    // 	}
    // };

    //Force an update to set position/size
    this.update();
  }

  void setPosition(num x, num y) {
    this.position.x = x;
    this.position.y = y;

    final width = this.size.width;
    final height = this.size.width;

    mesh.position.set(
        -innerWidth / 2 + width / 2 + x, innerHeight / 2 - height / 2 - y, 0);

    // if ( doRenderLabel ) labelMesh.position.set( mesh.position.x, mesh.position.y - scope.size.height / 2 + labelCanvas.height / 2, 0 );
  }

  void setSize(num width, num height) {
    this.size.width = width;
    this.size.height = height;

    mesh.scale.set(width / (frame["width"]??0), height / (frame["height"]??0), 1);

    //Reset the position as it is off when we scale stuff
    resetPosition();
  }

  void resetPosition() {
    this.setPosition(this.position.x, this.position.x);
  }

  void update() {
    this.setPosition(this.position.x, this.position.y);
    this.setSize(this.size.width, this.size.height);
  }

  void render(renderer) {
    if (this.enabled) {
      print("shadowmap view render   ");

      //Because a light's .shadowMap is only initialised after the first render pass
      //we have to make sure the correct map is sent into the shader, otherwise we
      //always end up with the scene's first added shadow casting light's shadowMap
      //in the shader
      //See: https://github.com/mrdoob/three.js/issues/5932
      uniforms["tDiffuse"]["value"] = light.shadow!.map!.texture;

      userAutoClearSetting = renderer.autoClear;
      renderer.autoClear = false; // To allow render overlay
      renderer.clearDepth();
      renderer.render(scene, camera);
      renderer.autoClear = userAutoClearSetting; //Restore user's setting
    }
  }

  void updateForWindowResize() {
    if (this.enabled) {
      camera.left = innerWidth / -2;
      camera.right = innerWidth / 2;
      camera.top = innerHeight / 2;
      camera.bottom = innerHeight / -2;
      camera.updateProjectionMatrix();

      this.update();
    }
  }
}
