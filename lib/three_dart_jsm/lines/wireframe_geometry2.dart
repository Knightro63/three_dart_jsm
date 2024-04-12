import 'package:three_dart/three_dart.dart';

class WireframeGeometry2 extends WireframeGeometry{
	String type = 'WireframeGeometry2';
	bool isWireframeGeometry2 = true;

	WireframeGeometry2(BufferGeometry geometry):super(geometry);

	factory WireframeGeometry2.fromWireframeGeometry(WireframeGeometry geometry){
    return WireframeGeometry2(geometry);
  }
}
