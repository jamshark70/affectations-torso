
// a fix for the ridiculous, pointless, stupid and damned inconvenient restriction on phase in the main implementation

+ TempoClock {
//	nextTimeOnGrid { arg quant = 1, phase = 0;
//		var offset;
//		if (quant < 0) { quant = beatsPerBar * quant.neg };
//		^roundUp(this.beats - baseBarBeat, quant) + baseBarBeat + phase;
//	}

	copy {}
	deepCopy {}
	shallowCopy {}
}
