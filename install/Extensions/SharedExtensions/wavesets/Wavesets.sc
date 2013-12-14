// Analyses a soundfile into wavesets. 
		<xings, <numXings, <lengths, <fracXings, <fracLengths;
	var 	<minSet, <maxSet, <avgLength, <sqrAvgLength,
	

	*from { arg path, name; 
		var f, sig;
		f = SoundFile.new; 
		if (f.openRead(path).not) { 
			("Wavesets.from... File" + path + "not found.").warn; 
			^nil 
		};
		if (f.numChannels > 1) { 
			("File" + path + "has" + f.numChannels + "chans."
			"Wavesets only works on mono signals, so please ...").warn; 
			// could also take first chan...
			^nil
		};
						// sampleFormat is not updated correctly in SoundFile.read.
	//	sig = (formatDict[f.sampleFormat] ? Signal).newClear(f.numFrames);
		sig = Signal.newClear(f.numFrames);
		name = name ?? { PathName(path).fileName; };
		f.readData(sig);
		
		^this.new(name.asSymbol, sig, f.sampleRate);
	}
	
		if (all.at(argName).notNil and: { all.at(argName).signal.size == argSig.size }, 
			{ 
				("//	waveset" + argName + "seems identical to existing.\n"
				"// ignored.").postln;
				^all.at(name);
			});
		name = argName; 
		signal = argSig;
		numFrames = argSig.size;
		sampleRate = argSampleRate ? Server.default.sampleRate;
		all.put(name, this);

	}
		this.clear; 
		formatDict = (		// not used yet; maybe saves some memory eventually.
			'int8': 	Int16Array,
			'int16': 	Int16Array,
			'mulaw': 	Int16Array, 
			'alaw': 	Int16Array,
			'int24': 	Int32Array,
			'int32': 	Int32Array,
			'float':	Signal
		);
	}
	

			/**** support for live buffers from server ****/
			
	*fromBuf { arg buffer, name;
		^super.newCopyArgs(nil, name).getBuffer(buffer);
	}
	
	getBuffer { arg buffer, start=0, numFrames;

		numFrames = numFrames ? buffer.numFrames;
		if(numFrames < 1633) {
			buffer.getn(start, numFrames, 
				{ |values| this.signal = Signal.newFrom(values) });
		} {
			buffer.loadToFloatArray(start, numFrames, 
				{ |values| this.signal = Signal.newFrom(values) });
		};

	}
	
	signal_ { arg sig;
		signal = sig;
		this.analyse;
	}
			/**********************/ 
			

		numXings = xings.size;
		fracLengths = fracXings.drop(1) - fracXings.drop(-1); 
		
					
					fracXings = fracXings.add( i - 1 + frac );

					maxSamp = 0.0; 
	indicesFor { arg start=0, length=1, clip=true; 
		var end;
		// calc safe indices for these start and length;
		// wrap or clip if too close to file end. 
		^[ start, end, length]
	}
	
	framesFor { |start, end|
		^xings[[start, end]];
	}
	
	ampFor { |start, end|
		^amps.copyRange(start, end - 1).maxItem;
	}
	
	lengthFor { |start, end|
		^xings[end] - xings[start];
	}
	
	argsFor { arg start, length, rep, rate;
	//	^[\start, start, \end, end, \rate, rate, \sustain, sustain]
	}
	
	