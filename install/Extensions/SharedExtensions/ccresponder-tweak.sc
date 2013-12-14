
+ MIDIResponder {
	*findMatching { |midiEvent|
		var	src, chan, data1, data2;
		src = this.fixSrc(midiEvent.port);
		chan = midiEvent.chan;
		data1 = midiEvent.b;
		data2 = midiEvent.c;
		^this.responders.select({ |resp| resp.matchEvent.match(src, chan, data1, data2) });
	}
	
	*make { |type = 'CC', function, src, chan, data1, data2, install = true|
		var	class = (type ++ "Responder").asSymbol.asClass;
		^class.new(function, src, chan, data1, data2, install);
	}

	*makeOneOnly { |type = 'CC', function, src, chan, data1, data2, install = true|
		var	class = (type ++ "Responder").asSymbol.asClass;
		class.findMatching(MIDIEvent(nil, src, chan, data1, data2)).do({ |resp| resp.remove });
		^class.new(function, src, chan, data1, data2, install);
	}
}
