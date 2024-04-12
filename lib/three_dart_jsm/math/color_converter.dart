import 'package:three_dart/three_dart.dart';

class HSL{
  HSL([this.h = 0,this.s = 0,this.l = 0]);

  num h;
  num s;
  num l;

  Map<String,dynamic> toJson(){
    return{
      'h':h,
      's':s,
      'l':l 
    };
  }
}
class CMYK{
  CMYK([this.c = 0,this.m = 0,this.y = 0, this.k = 0]);

  num c;
  num m;
  num y;
  num k;

  Map<String,dynamic> toJson(){
    return{
      'c':c,
      'm':m,
      'y':y,
      'k':k 
    };
  }
}
class ColorConverter{
  Color setHSV(Color color, double h, double s, double v){
    return color.setHSL(h, ( s * v ) / ( ( h = ( 2 - s ) * v ) < 1 ? h : ( 2 - h ) ), h * 0.5);
  }
  HSL getHSV(Color color, HSL? target){
    HSL hsl = HSL();

    if ( target == null ) {
      print( 'THREE.ColorConverter: .getHSV() target is now required' );
      target = HSL();
    }

    color.getHSL(hsl.toJson());

    // based on https://gist.github.com/xpansive/1337890#file-index-js
    hsl.s *= ( hsl.l < 0.5 ) ? hsl.l : ( 1 - hsl.l );

    target.h = hsl.h;
    target.s = 2 * hsl.s / ( hsl.l + hsl.s );
    target.l = hsl.l + hsl.s;

    return target;
  }

	Color setCMYK(Color color, double c,double m,double y,double k){
		final r = ( 1 - c ) * ( 1 - k );
		final g = ( 1 - m ) * ( 1 - k );
		final b = ( 1 - y ) * ( 1 - k );

		return color.setRGB( r, g, b );
	}

	CMYK getCMYK(Color color, CMYK? target){
		if(target == null ){
			print( 'THREE.ColorConverter: .getCMYK() target is now required' );
			target = CMYK();
		}

		final r = color.r;
		final g = color.g;
		final b = color.b;

		final k = 1 - Math.max( r, Math.max(g, b ));
		final c = ( 1 - r - k ) / ( 1 - k );
		final m = ( 1 - g - k ) / ( 1 - k );
		final y = ( 1 - b - k ) / ( 1 - k );

		target.c = c;
		target.m = m;
		target.y = y;
		target.k = k;

		return target;
	}
}
