
+ Array {
	*sawtoothAmps { |topPartial = 20| ^(1..topPartial).reciprocal }
	
	*squareAmps { |topPartial = 20| ^[(1, 3 .. topPartial).reciprocal, 0].lace(topPartial) }
	
	*triangleAmps { |topPartial = 20| ^[(1, 3 .. topPartial).reciprocal.squared * #[1, -1], 0].lace(topPartial) }
}

+ Signal {
	*sawtooth { |size, topPartial = 20|
		^Signal.sineFill(size, Array.sawtoothAmps(topPartial))
	}
	
	*square { |size, topPartial = 20|
		^Signal.sineFill(size, Array.squareAmps(topPartial))
	}
	
	*triangle { |size, topPartial = 20|
		^Signal.sineFill(size, Array.triangleAmps(topPartial))
	}
}

+ Buffer {
	sawtooth { |topPartial = 20, normalize = true, asWavetable = true, clearFirst = true|
		this.sine1(Array.sawtoothAmps(topPartial), normalize, asWavetable, clearFirst)
	}
	square { |topPartial = 20, normalize = true, asWavetable = true, clearFirst = true|
		this.sine1(Array.squareAmps(topPartial), normalize, asWavetable, clearFirst)
	}
	triangle { |topPartial = 20, normalize = true, asWavetable = true, clearFirst = true|
		this.sine1(Array.triangleAmps(topPartial), normalize, asWavetable, clearFirst)
	}
}
