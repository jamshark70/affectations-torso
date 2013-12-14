
WrappableInstrSynthDef : HJHInstrSynthDef {
	classvar	<currentPlayer;	// used by Instr.wrap
	var	<instancePlayer;

	*build { arg instr,args,outClass = \Out, player, lagMagic;
		^super.prNew.build(instr,args,outClass, player, lagMagic)
	}
	build { arg argInstr,args,outClass= \Out, player, argLagMagic;
			// in the middle of a wrap, we will build a temporary synthdef
			// this one should not override the currentPlayer
		instr ?? { instr = argInstr };
		lagMagic = argLagMagic/*.debug("argLagMagic")*/ ?? { instr.lagMagic/*.debug("default lagMagic from Instr")*/ };
		player.notNil.if({ instancePlayer = currentPlayer = player; });
		this.initBuild
			.buildUgenGraph(instr,args ? #[],outClass)
			.finishBuild;
			// clear for the next synthdef
		instancePlayer.notNil.if({ currentPlayer = nil });
	}

	buildUgenGraph { arg instr,args,outClass;
		var result,fixedID="";
		var isScalarOut;
		var outputProxies;
		var	saveControlNames = controlNames;

		// restart controls in case of *wrap
		controlNames = nil;
//		controls = nil;

		// OutputProxy In InTrig Float etc.
		outputProxies = this.buildControlsWithObjects(instr,args);

		result = instr.valueArray(outputProxies);
		rate = result.rate;
		numChannels = max(1,result.size);

		if(result != 0.0,{
			outClass = outClass.asClass;
			if(outClass === XOut,{
				"XOut not tested yet.".error;
				//out = outClass.perform(if(this.rate == \audio,\ar,\kr),
				//			inputs.at(0),xfader.value,out)
			});

			if(rate == \audio,{
				result = outClass.ar(Control.names([\out]).ir([0]) , result);
				// can still add Out controls if you always use \out, not index
			},{
				if(rate == \control,{
					result = outClass.kr(Control.names([\out]).ir([0]) , result);
				},{
					("InstrSynthDef: scalar rate ? result of your function:" + result).error;
				})
			});
		});


		//is based on the instr name, ir, kr pattern, fixedValues
		// outClass,numChannels (in case it expanded)
		name = "";
		instr.name.do({ arg part;
			name = name ++ part.asString.asFileSafeString;
		});
		if(name.size > 8,{
			name = name.copyRange(0,7) ++ name.copyRange(8,name.size - 1).hash.asFileSafeString;
		});
		name = name ++ outClass.name.asString.first.toUpper;

		/* fixedValues.do({ arg fa,i;
			if(fa.notNil,{
				fixedID = fixedID ++ i ++ fa.asCompileString;
			})
		});
		name = name ++ fixedID.hash.asFileSafeString; */

		longName = name ++ this.class.defNameFromObjects(args);
		name = longName.hash.asFileSafeString;
// super.finishBuild already prints this
//		("WrappableInstrSynthDef built:" + name/* + longName*/).inform;

		controlNames = saveControlNames;
	}

}