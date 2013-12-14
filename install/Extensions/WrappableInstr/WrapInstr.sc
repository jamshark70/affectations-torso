// this extension requires other stuff, and new variables, in Patch and InstrSynthDef
// sometime later I will create alternate classes for support but not tonight

WrapInstr : HJHInstr {
		// added by HJH
	*wrap { |name, inputs, prefix, lagMagic|
		^this.at(name).wrap(inputs, prefix, lagMagic)
	}
	wrap { |inputs, prefix, lagMagic|
		var	default, synthdef, player, instr, args, argNames, argOffset, outputProxies, inp;
		var	saveControlNames;
		(inputs.size == 0).if({ inputs = [] });
		synthdef = UGen.buildSynthDef;
		saveControlNames = synthdef.controlNames;	// because I am going to call buildControls later
		synthdef.controlNames = nil;
		argNames = this.argNames;
		prefix.notNil.if({
			argNames = argNames.collect({ |name| (prefix ++ name).asSymbol })
		});
		player = WrappableInstrSynthDef.currentPlayer;
		if(lagMagic.isNil) {
			lagMagic = player.lagMagic ?? { this.lagMagic ?? { true } };
		};
		instr = player.tryPerform(\instr);
		args = (player.tryPerform(\args) ?? { [] });
		argOffset = args.size;	// for initForSynthDef call -- must do this before extend
		inp = player.addArgs(inputs, this, prefix, true);  // flag to indicate I'm wrapping
		inp.do({ |in, i|
			// maybe pass the spec here?
			in.initForSynthDef(synthdef, argOffset+i);
				// should I add all args to the patch, or only non-scalars?
				// for testing I'll just put them all in
			in.addToSynthDef(synthdef, argNames[i]);
			(in.notNil and: { inputs[i].isNil }).if({
				args = args.add(in);
			});
		});

		outputProxies = synthdef.buildControls
			[..this.argsSize]	// crop the array
			.collect({ |ctl, i| inp[i].hjhInstrArgFromControl(ctl, i, lagMagic) });
		synthdef.controlNames = saveControlNames;
			// if the current patch exposes instr args, add the args to the patch
		player.tryPerform(\args_, args);
		^func.valueArray(outputProxies)
	}

	patchClass { ^WrapPatch }
	synthDefClass { ^WrappableInstrSynthDef }
}
