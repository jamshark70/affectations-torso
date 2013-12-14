
// miscellaneous extensions I don't want to publish in my lib

// I *HATE* BeatClockPlayer. I want TrigSpec to produce a simple trigger
+ TrigSpec {
	defaultControl { ^SimpleTrigger.new(this) }
}


//
//// Patch spec getter
//
//+ Patch {
//	specFromName { |name|
//		var	index;
//		(index = this.indexFromName(name)).notNil.if({ ^argSpecs[index] }, { ^nil });
//	}
//}

//+ JSCTextView{
// 	open { arg path;
//		path = path.replace( ' ', '%20' );
//		this.openURL( "file://"++path );
//	}
//}
