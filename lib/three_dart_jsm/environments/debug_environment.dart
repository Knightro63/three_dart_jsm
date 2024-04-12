import 'package:three_dart/three_dart.dart';

class DebugEnvironment extends Scene {

	DebugEnvironment():super() {
		final geometry = BoxGeometry();
		geometry.deleteAttribute( 'uv' );
		final roomMaterial = MeshStandardMaterial( { 'metalness': 0, 'side': BackSide } );
		final room = Mesh( geometry, roomMaterial );
		room.scale.setScalar( 10 );
		this.add( room );

		final mainLight = PointLight( 0xffffff, 50, 0, 2 );
		this.add( mainLight );

		final material1 = MeshLambertMaterial( { 'color': 0xff0000, 'emissive': 0xffffff, 'emissiveIntensity': 10 } );

		final light1 = Mesh( geometry, material1 );
		light1.position.set( - 5, 2, 0 );
		light1.scale.set( 0.1, 1, 1 );
		this.add( light1 );

		final material2 = MeshLambertMaterial( { 'color': 0x00ff00, 'emissive': 0xffffff, 'emissiveIntensity': 10 } );

		final light2 = Mesh( geometry, material2 );
		light2.position.set( 0, 5, 0 );
		light2.scale.set( 1, 0.1, 1 );
		this.add( light2 );

		final material3 = MeshLambertMaterial( { 'color': 0x0000ff, 'emissive': 0xffffff, 'emissiveIntensity': 10 } );

		final light3 = Mesh( geometry, material3 );
		light3.position.set( 2, 1, 5 );
		light3.scale.set( 1.5, 2, 0.1 );
		this.add( light3 );

	}
}
