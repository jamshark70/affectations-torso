
+ HJHInstr {
	patchClass { ^HJHPatch }
	synthDefClass { ^HJHInstrSynthDef }

	init { arg specs,outsp;
		if(path.isNil,{
			path = thisProcess.nowExecutingPath; //  ?? { Document.current.path };
		});
		this.makeSpecs(specs ? #[]);
		if(outsp.isNil,{
			outSpec = nil;
		},{
			outSpec = outsp.asSpec;
		});
		this.class.put(this);
	}

	*loadAll {
		var quarkInstr;
		(this.dir ++ "*").pathMatch.do({ arg path;
			if(path.last != $/,{
				path.loadPath(false)
			})
		});
		(this.dir ++ "WrapInstr/*").pathMatch.do({ arg path;
			if(path.last != $/,{
				path.loadPath(false)
			})
		});

		quarkInstr = (Platform.userExtensionDir ++ "/quarks/*/Instr/*").pathMatch
			.reject { |path| path.splitext[1] == "sc" };
		quarkInstr.do({ |path|
			if(path.last != $/,{
				path.loadPath(false);
			})
		});
	}
}

+ HJHInstrSynthDef {
	*clearCache { arg server;
		"Clearing AbstractPlayer SynthDef cache".inform;
		if(Library.at(SynthDef, server).notNil and: { server.serverRunning }) {
			Library.at(SynthDef, server).keysDo({ |key|
				server.sendMsg(\d_free, key);
			});
		};
		Library.put(SynthDef,server,nil);
	}
}

+ Object {
	adjustArgForSpec { ^this }
	hjhInstrArgFromControl { |control, i| ^this.instrArgFromControl(control, i) }
}

+ KrNumberEditor {
	hjhInstrArgFromControl { |control, i, lagMagic(true)|
		if(lagMagic) {
			^this.instrArgFromControl(control, i)
		} {
			^control
		}
	}
}

// allows easy override of controlspec defaults while still producing a control

+ Ref {
	adjustArgForSpec { |spec|
		value.isNumber.if({
			^KrNumberEditor(value, spec)
		}, {
			^value
		});
	}
}


// asWrapInstr

+ Instr {
	asWrapInstr {}
}
+ WrapInstr {
	asWrapInstr {}
}
+ SequenceableCollection {
	asWrapInstr {
		^WrapInstr.at(this)
	}
}

+ Symbol {
	asWrapInstr {
		^WrapInstr.at(this)
	}
}

+ String {
	asWrapInstr {
		^WrapInstr.at(this)
	}
}

+ Function {
	asWrapInstr {
		^WrapInstr("f" ++ this.hash,this)
	}
}

/*+ Patch {
	*new { arg name,inputs,outClass;
		^super.new.loadSubject(name).createArgs(inputs ? []).outClass_(outClass ? Out)
	}
}
*/

+ WrapInstr {
	miditest { arg channel = 0, initArgs, target, bus, ctlChannel, makeVoicerFunc, excludeCtls;
		var voicer, socket, patch, synthdef, layout, argsSize, parg, i, argNames;

		var close = {
			var	gctemp;
			voicer.active.if({
				"\n\nTest ended. Last settings of global controls:".postln;
					// must free midi controls in reverse order
					// globalControls is an IdentityDictionary, so this is the only way
				gctemp = Array.new(voicer.globalControls.size);

				voicer.globalControlsByCreation.do({ arg gc;
					gctemp.add(gc);
					Post << $\\ << gc.name << ", " << gc.value << ", \n";
				});
				gctemp.reverseDo({ |gc| gc.midiControl.free });
					// prevent infinite recursion
				layout.onClose = nil;
				layout.close;
				socket.free;	// clear and garbage objects
				voicer.free;
				socket = nil;
				voicer = nil;
			});
		};

		// MIDIPort.autoFreeSockets.not.if({
		// 	MethodError("MIDIPort.autoFreeSockets must be true to use miditest.", this).throw;
		// });

		channel = channel ? 0;
			// can have controllers on a different midi channel (or different device)
		ctlChannel = ctlChannel ? channel;

			// make the player
		voicer = makeVoicerFunc.(this, initArgs, target: target, bus: bus)
			?? { Voicer.new(20, this, initArgs, target: target, bus: bus) };
		socket = VoicerMIDISocket.new(channel, voicer);  // plug into MIDI

			// make guis for controls other than freq and gate
			// first get the InstrSynthDef
			// how to exempt args? provide non-SimpleNumber in initArgs
			// (Ref of SimpleNumber works to make fixed arg)
		patch = voicer.nodes.at(0).patch;
		synthdef = patch.asSynthDef;
		argNames = patch.argNames ?? { this.argNames };
		excludeCtls = excludeCtls ++ #[\freq, \gate, \out];

			// now make midi controllers, but only for kr inputs
			// we have to go to the synthdef because only it knows which are noncontrols
		synthdef.allControlNames.do({ |cname|
			(cname.rate == \control and:
				{ excludeCtls.includes(cname.name).not }
			).if({
				i = argNames.detectIndex({ |name| name == cname.name });
					// you might have added NamedControls in the Instr func
					// which will not have specs and shouldn't turn into midi controls
				if(i.notNil) {
					parg = patch.args[i];
					socket.addControl(
						nil,		// socket will allocate a controller for me
						argNames[i],
						(name == \pb).if(1, patch.args[i].value),
//							(name == \pb).if(
//								[7.midiratio.reciprocal, 7.midiratio, \exponential, 0, 1],
//								parg.tryPerform(\spec) ?? { patch.argSpecs[i] }),
						parg.tryPerform(\spec) ?? { patch.argSpecs[i] },
						ctlChannel
					);
				};
			});
		});
			// make stop button
		voicer.addProcess([["Stop test", close]], \toggle);  // so it's a button not a menu

		layout = voicer.gui.masterLayout;
		layout.onClose = close;

		// now user can play
		"\n\nTry your Instr using your midi keyboard. Arguments have been routed as shown".postln;
		"in the console window.".postln;
		^voicer
	}

	miditestMono { arg channel = 0, initArgs, target, bus, ctlChannel, excludeCtls;
		^this.miditest(channel, initArgs, target, bus, ctlChannel, { |instr, initArgs, target, bus|
			MonoPortaVoicer(1, instr, initArgs, bus, target)
		}, excludeCtls);
	}

	openFile {
		this.path.openTextFile;
	}

	argsAndIndices {
		var out;
		out = IdentityDictionary.new;
		func.def.argNames.do({ |name, i|
			out.put(name, i);
		});
		^out
	}

	listArgs { |inputs|
		var names = this.getWrappedArgs(inputs);
		("\n\n" ++ this.asString).postln;
		names.do({ arg assn;
			assn.key.post;
			" -> ".post;
			assn.value.asCompileString.postln;
		});
	}
	getWrappedArgs { |inputs|
		var	dummyPatch,	// Instrs that use Instr-wrap must be patched before revealing all args
			names, spc;
		try {	// this might fail, so set up a fallback position
			dummyPatch = this.patchClass.new(this, inputs);
			dummyPatch.asSynthDef;
			names = dummyPatch.argNames;
			spc = dummyPatch.argSpecs;
		} {		// on failure
			names = this.argNames;
			spc = specs;
		};
		^names.collect { |name, i| (name -> spc[i]) }
	}
}
