// Analyses a soundfile into wavesets. // keeps global libs of analysed files and the resulting wavesets.// only works for single channels.Wavesets { 			classvar <>minLength = 10; 	// reasonable? => 4.4 kHz maxFreq.	classvar <all, formatDict; 		var <signal, <name, <numFrames, <sampleRate, 
		<xings, <numXings, <lengths, <fracXings, <fracLengths;
	var 	<minSet, <maxSet, <avgLength, <sqrAvgLength,		<amps, <minAmp, <maxAmp, <avgAmp, <sqrAvgAmp; 	
		*new { arg name, sig, sampleRate; 		^super.new.init(name, sig, sampleRate);	}

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
		init { arg argName, argSig, argSampleRate; 		
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
		this.analyse;
	}		*clear {  all = IdentityDictionary.new; }		*initClass { 		
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
		*at { |key| ^all[key] } 

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
				analyse { arg finishFunc;	//	var chunkSize = 400, pause = 0.01;	// not used yet				xings = Array.new;			amps = Array.new; 		lengths = Array.new; 		fracXings = Array.new; 
		( "Analysing" + name + "...").postcln; 		this.analyseFromTo;		this.calcAverages; 		("Finished signal" + name + ":" + numXings + " xings.").postcln; 	}	calcAverages { 		// useful statistics.		// calculate maxAmp, minAmp, avgAmp, sqAvgAmp;		// and maxSet, minSet, avgLength, sqAvgLength;	
		numXings = xings.size;		minSet = lengths.minItem;		maxSet = lengths.maxItem; 		minAmp = amps.minItem;		maxAmp = amps.maxItem; 		
		fracLengths = fracXings.drop(1) - fracXings.drop(-1); 
				avgLength = xings.last - xings.first / numXings;		sqrAvgLength = ( lengths.squared.sum / ( numXings - 1) ).sqrt;				avgAmp = amps.sum / numXings; 		sqrAvgAmp = (amps.squared.sum / numXings).sqrt;				^this;	}			// should eventually support analysis in blocks in realtime.						analyseFromTo { arg startFrame = 0, endFrame;			var lengthCount = 0, prevSample = 0.0, maxSamp = 0.0, minSamp = 0.0, wavesetAmp, frac;		// find xings, store indices, lengths, and amps. 					startFrame = max(0, startFrame);		endFrame = (endFrame ? signal.size - 1).min(signal.size - 1);				( startFrame to: endFrame ).do({ arg i; 			var thisSample; 			thisSample = signal.at(i);									// if Xing from non-positive to positive:			if (	(prevSample <= 0.0) and: (thisSample > 0.0) and: (lengthCount >= minLength), 							{ 						wavesetAmp = max(maxSamp, minSamp.abs);										if (xings.notEmpty, { // need to find first xing first.						amps = amps.add(wavesetAmp);						lengths = lengths.add(lengthCount) 					});					xings = xings.add(i); 			
										frac = prevSample / (prevSample - thisSample);
					fracXings = fracXings.add( i - 1 + frac );

					maxSamp = 0.0; 					minSamp = 0.0;					lengthCount = 0;				}			);			lengthCount = lengthCount + 1;			maxSamp = max(maxSamp, thisSample);			minSamp = min(minSamp, thisSample);			prevSample = thisSample;		});	}				// convenience methods not done yet.
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
	
	}