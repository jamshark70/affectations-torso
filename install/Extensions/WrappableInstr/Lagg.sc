Lagg : KrNumberEditor {
	*new { arg value=1.0,spec;
		^super.new.init(value,spec)
	}
	init { arg val,aspec;
		if(aspec.notNil) {
			spec = (aspec.asSpec ?? {ControlSpec.new});
		} {
			spec = nil  // superclass set this
		};
		value = val;
	}

	// ho hum, another fucking override to allow for a nil spec
	spec_ { arg aspec;
		if(aspec.notNil) {
			spec = aspec.asSpec;
			this.value = spec.constrain(value);
			this.changed(\spec);
		} {
			spec = nil;
		}
	}

	// hm, that's a bad thing for .gui
	initForSynthDef { |def, i|
		if(spec.isNil) {
			// this is probably bad for wrapping
			// see line 29 in WrapInstr.sc
			spec = def.instr.specs[i];
		};
	}

	// by definition, this class should ignore lagMagic from the parent
	// it should always lag!
	hjhInstrArgFromControl { |control, i|
		^Lag.kr(control, lag ?? { defaultLag })
	}
}