import 'package:three_dart/three3d/three.dart';

class ConeGeometry extends CylinderGeometry {
	ConeGeometry(double radius, double height, int radialSegments, int heightSegments, bool openEnded, num thetaStart, double thetaLength ):super(0, radius, height, radialSegments, heightSegments, openEnded, thetaStart, thetaLength){
		this.type = 'ConeGeometry';
		this.parameters = {
			'radius': radius,
			'height': height,
			'radialSegments': radialSegments,
			'heightSegments': heightSegments,
			'openEnded': openEnded,
			'thetaStart': thetaStart,
			'thetaLength': thetaLength
		};
	}
}
