
WrapPatch : HJHPatch {
	var	<>argNames,<>argSpecs;
		// used only for building
	var	argIndexForBuilding, allUserSuppliedArgs;
	
	argNameAt { arg i; ^argNames[i] }

	createArgs { arg argargs;
		argsForSynth = [];
		argNamesForSynth = [];
		patchIns = [];
		synthPatchIns = [];
		argNames = [];
		argSpecs = [];
		argIndexForBuilding = 0;
		allUserSuppliedArgs = argargs;
		this.addArgs(argargs);
	}

	addArgs { arg argargs, wrapInstr, namePrefix, wrapping = false;
		var argsSize, argsIndices, namesWithPrefix, addedToSynth;
		wrapInstr = wrapInstr ? this.instr;
		argsSize = wrapInstr.argsSize;
		namePrefix.notNil.if({	// this should be true only if wrapping
			namesWithPrefix = wrapInstr.argNames.collect({ |name| asSymbol(namePrefix ++ name) });
		}, {
			namesWithPrefix = wrapInstr.argNames/*.debug("new arg names")*/;
		});
			// if there are no args, should not touch argNames and argSpecs arrays
		(wrapInstr.argNames.size > 0).if({
			wrapping.if({
				argsIndices = Array.new(wrapInstr.argNames.size);
				wrapInstr.argNames.size.do({ |i|
					argargs[i].isNil.if({ argsIndices.add(i) });
				});
			}, {
				argsIndices = (0..argsSize-1);
			});
			argNames = argNames ++ namesWithPrefix[argsIndices]/*.debug("new arg names")*/;
				 // cruxxial doesn't need this but hjh does
			argSpecs = argSpecs ++ wrapInstr.specs[argsIndices];
		});

		argsIndices = Array.new(argsSize);
		
		args=Array.fill(argsSize,{arg i; 
			var proto,spec,ag,patchIn,darg;
			spec = wrapInstr.specs.at(i);
			ag = 
				argargs.at(i) // explictly specified in the instrument wrapping
				?? { 
					allUserSuppliedArgs[argIndexForBuilding]  // explicit in the patch
				?? 
				{ //  or auto-create a suitable control...
					darg = wrapInstr.initAt(i);
					if(darg.isNumber,{
						proto = spec.defaultControl(darg);
					},{
						proto = spec.defaultControl;
					});
					proto
				} };
				// subclasses may change the arg, see InstrSpawner
			ag = this.adjustArgForSynth(ag, spec);
				// for Refs to numbers especially
			ag = ag.adjustArgForSpec(spec);
			patchIn = PatchIn.newByRate(spec.rate);
			patchIns = patchIns.add(patchIn);

			// although input is control, arg could overide that
			// if you are not wrapping, always add based on rate
			// if you ARE wrapping and the arg was explicitly supplied in argargs,
			// should NOT add to synth
			if(addedToSynth = (wrapping.not or: { argargs[i].isNil })
					and: { spec.rate != \noncontrol and: { ag.rate != \noncontrol } }, {
				argsForSynth = argsForSynth.add(ag);
				argNamesForSynth = argNamesForSynth.add(namesWithPrefix[i]);
				synthPatchIns = synthPatchIns.add(patchIn);
//				synthArgsIndices.put(i,synthPatchIns.size - 1);
			},{
				// watch scalars for changes. 
				// if Env or Sample or quantity changed, synth def is invalid
				//if(ag.isNumber.not,{ ag.addDependant(this); });
			});
				// should advance through args array only if not wrapping, or
				// if wrapping but the arg is not supplied in the inputs
			(wrapping.not or: { argargs[i].isNil }).if({
					// must add something; but, if not added to synth, it should be nil
				argsIndices.add(addedToSynth.if(synthPatchIns.size - 1, nil));
				argIndexForBuilding = argIndexForBuilding + 1;
			});
			ag		
		});
		synthArgsIndices = synthArgsIndices ++ argsIndices;
		^args
	}

	adjustArgForSynth { |in| ^in }

	asSynthDef {
		// could be cached, must be able to invalidate it
		// if an input changes
		^synthDef ?? {
			if(this.spec.rate == 'stream',{
				("Output rate is 'stream', not yet supported").warn;
				^nil
			});
			synthDef = WrappableInstrSynthDef.build(this.instr,this.args,this.outClass, this);
			defName = synthDef.name;
			// the synthDef has now evaluated and can know the number of channels
			// but if it returned an Out.ar then it does not know
			// so we will have to trust the Instr outSpec 
			if(synthDef.numChannels.notNil,{
				numChannels = synthDef.numChannels;
			});
			if(synthDef.rate.notNil,{
				rate = synthDef.rate;
			});
			this.watchNoncontrols;
			this.instr.addDependant(this);
			stepChildren = synthDef.secretObjects;

			synthDef
		}
	}

	loadSubject { arg name;
		if(instr.notNil,{
			instr.removeDependant(this);
		});
		instr = name.asWrapInstr;
		if(instr.isNil,{
			("Instrument not found !!" + name).die;
		});
		//instr.addDependant(this);
	}
	guiClass { ^WrapPatchGui }

		// J-frickin'-C, I really need to cut my ties with crucial lib
	args_ { |array| args = array }
}
