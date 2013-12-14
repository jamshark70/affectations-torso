DebugNetAddr : NetAddr {
	var <doc, <>active=true;
	var <>list;
	var funcs, <>dumpAll = true;

	sendRaw { arg rawArray;
		if(active) { this.dump(nil, rawArray) };
		super.sendRaw(rawArray);
	}
	sendMsg { arg ... args;
		if(active) { this.dump(nil, [args]) };
		super.sendMsg(*args);
	}
	sendBundle { arg time ... args;
		if(active) { this.dump(time, args) };
		super.sendBundle(time, *args);
	}
	dump { arg time, args;
		var str, docStr, beats, beatsThisThread;
		if(dumpAll) {
			if(#['/status', '/quit'].includes(args.tryPerform(\at, 0).tryPerform(\at, 0).asSymbol))
			{ ^this };
			if(doc.isNil) { this.makeDocument };

			// should get the beats outside the { }.defer block
			beats = SystemClock.beats;
			beatsThisThread = thisThread.clock.tryPerform(\beats);
			if(list.notNil) {
				list.add([beats, beatsThisThread, args])
			} {
				defer {
					str = "latency %\tSysClock logical time %\tthisThread's logical time %\n"
					.format(time, beats, beatsThisThread);
					args.do { arg msg;
						str = str ++ Char.tab;
						msg = msg.collect { arg el;
							if(el.isKindOf(RawArray) and: { el.size > 32 })
							{ "data[" + el.size + "]" } { el };
						};
						str = str ++ msg.asCompileString ++ Char.nl;
					};
					str.postln;
					str = str ++ Char.nl;

					doc !? { doc.selectedString_(str) }
				};
			};
		};
		args.do { |msg| funcs.value(msg, time) };
	}
	makeDocument {
		if(thisProcess.platform.ideName == "scapp") {
			try {
				doc = Document(this.asCompileString)
				.onClose_({ doc = nil; active = false })
				.background_(Color.grey(0.8));
			} {
				doc = nil; // active = false
			}
		} {
			doc = nil
		};
	}

	addFunc { |func|
		funcs = funcs.addFunc(func);
	}
	removeFunc { |func|
		funcs.removeFunc(func);
	}
	== { |that|
		^addr == that.addr and: { port == that.port }
	}
}


DebugSetnNetAddr : DebugNetAddr {
	dump { arg time, args;
		var str, docStr, beats, beatsThisThread;
		if(#['16', 'n_setn', '/n_setn'].includes(args.tryPerform(\at, 0).tryPerform(\at, 0).asSymbol).not)
			{ ^this };
//		if(#['/status', '/quit'].includes(args.tryPerform(\at, 0).tryPerform(\at, 0).asSymbol))
//			{ ^this };
		if(doc.isNil) { this.makeDocument };

			// should get the beats outside the { }.defer block
		beats = SystemClock.beats;
		beatsThisThread = thisThread.clock.tryPerform(\beats);
		str = "latency %\tSysClock logical time %\tthisThread's logical time %\n"
			.format(time, beats, beatsThisThread);
		args.do {�arg msg;
			str = str ++ Char.tab;
			msg = msg.collect { arg el;
				if(el.isKindOf(RawArray) and: { el.size > 15 })
					{ "data[" + el.size + "]" } { el };
			};
			str = str ++ msg.asCompileString ++ Char.nl;
		};
		str.postln;
		str = str ++ Char.nl;

		defer {
			doc !? { doc.selectedString_(str) };
		};

		this.dumpBackTrace;
	}

}


+ NetAddr {
	// DAMMIT! Stupid fucking Object:compareObject means that a DebugNetAddr
	// can never ever match the NetAddr provided with an incoming OSC message
	// so now I have to override a method... I hate SC some days
	matches { arg that;
		^that.isNil or: {
			this.addr == that.addr and: {
				that.port.isNil or: { this.port == that.port }
			}
		}
	}
}
