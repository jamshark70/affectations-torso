
// T2000 - new note when shifting side and in low quadrant
// last 5/10 centroids in opposite side (l/r)
// and y is low

u.remove;
u = SimpleController(BP(\ml));

u.put(\allPtsReceived, { |obj|  // obj === BP(\ml)
	
});

(
Proto({
	~listenKey = \allPtsReceived;
	~prep = {
		~makeListener.();
		~userprep.();
		currentEnvironment
	};
	~freeCleanup = {
		~resp.remove;
		~userfree.();
	};
	~makeListener = {
		~resp = SimpleController(~model)
		.put(~listenKey, e { |obj, what ... moreArgs|
			~respond.valueArray(obj, what, moreArgs)
		});
	};
}) => PR(\viztrig);
)

(
BP(\t2000trig).free;

PR(\viztrig).clone({
	~model = BP(\ml);
	~keep = 10;
	~reqd = 5;
	~checkX = 3;
	~leftThresh = -0.55;
	~rightThresh = 0.7;
	~sign = 0;
	~userprep = {
		~last = Array.fill(~keep, 0@0);
		~i = 0;
	};
	~respond = { |obj|
		var mean;
		~last[~i] = obj.centroid;
		~i = (~i + 1) % ~keep;

		if(
			~countAtLeast.(~last, { |pt| pt.y >= 0.5 }, ~reqd)/*.debug("low y")*/ and: {
				mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean(_.x);
				(mean.inclusivelyBetween(~leftThresh, ~rightThresh).not)/*.debug("x edge")*/ and: { (mean.sign != ~sign)/*.debug("changed sign")*/ }
			}
		) {
			~sign = mean.sign;  // (mean must have been calc'ed to get here)
			~fire.();
		};
	};

	~fire = {
		BP(\tton).triggerOneEvent(0);
	};

	~countAtLeast = { |coll, func, num|
		block { |break|
			coll.do { |item, i|
				if(func.(item, i)) {
					num = num - 1;
					if(num == 0) { break.(true) };
				};
			};
			false
		};
	};
}) => BP(\t2000trig);
)

BP(\ml).dependants


Library.at(WrapInstr, \analog).keys

WrapInstr("analog.sawpulse").listArgs;
WrapInstr("analog.sawpulse").openFile;

WrapInstr("analog.sawpulsepan", { |pan = 0|
	Pan2.ar(WrapInstr.wrap("analog.sawpulse", []), pan)
}, [\bipolar]);

p = WrapPatch("analog.sawpulsepan", [nil, nil, KrNumberEditor(1, \amp).lag_(nil), nil, Env.adsr(releaseTime: 0.05), Env.one, `2000, `1, `0.5, `0.8, `0, `1.003, 1, 0, 0, SinOsc]);
d = p.asSynthDef;
d.add;
SynthDescLib.at(d.name.asSymbol).msgFuncKeepGate = true;

p.insp

(instrument: d.name.asSymbol, freq: 440, gate: 0.1, sustain: 1, vsens: 1, parent: ProtoEvent(\singleSynthPlayer).copy, immediateOSC: true).play;

OSCFunc({ |msg| s.sendMsg(\n_trace, msg[1]) }, '/n_go', s.addr).oneShot;

/*
(
BP(\t2000trig).checkX = 3;
BP(\t2000trig).respond = { |obj|
	var mean, event;
	~last[~i] = obj.centroid;
	~i = (~i + 1) % ~keep;

	// ~last.collect({ |pt| pt.y.round(0.01) }).debug("y");

	mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean;

	// low-level audio feedback for position
	event = (
		instrument: d.name.asSymbol,
		freq: mean.y.linexp(-1, 1, 260, 65),
		pan: mean.x,
		gate: 0.05,
		sustain: 0.07, 
		vsens: 1,
		ffreq: 1200,
		parent: ProtoEvent(\polySynthPlayer).v,
		immediateOSC: true
	);

	if(~countAtLeast.(~last, { |pt| pt.y >= 0.5 }, ~reqd)) {
		event[\gate] = event[\gate] * 2.5;
	};

	if(
		~countAtLeast.(~last, { |pt| pt.y >= 0.5 }, ~reqd)/*.debug("low y")*/ and: {
			// mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean(_.x);
			(mean.x.abs >= 0.7)/*.debug("x edge")*/ and: { (mean.x.sign != ~sign)/*.debug("changed sign")*/ }
		}
	) {
		~sign = mean.x.sign;  // (mean must have been calc'ed to get here)
		"trigger".postln;
		event[\freq] = (#[0, 2, 4] + rrand(28, 42)).degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12).midicps;
		event[\ffreq] = 2800;
		event[\rq] = 0.1;
		// (
		// 	parent: ProtoEvent(\singleSynthPlayer).copy,
		// 	immediateOSC: true,
		// 	instrument: \default,
		// 	freq: rrand(60, 72).midicps,
		// 	amp: 0.1,
		// 	sustain: 0.5
		// ).play;
	};
	event.play;
};
)
*/

(
var bp = BP(\tton);

bp.speedMul.value = 0.1;
bp.fshift.value = 0;
bp.distance.value = 17;
bp.prepareForPlay;
)

BP(\tton).triggerOneEvent(0);

BP(\t2000trig).sign

// for some reason, meanx is biased toward the right??? maybe lighting problem
BP(\t2000trig).leftThresh = -0.58;
BP(\t2000trig).rightThresh = 0.7;
BP(\t2000trig).respond = { |obj|
	var mean;
	~last[~i] = obj.centroid;
	~i = (~i + 1) % ~keep;

	if(
		~countAtLeast.(~last, { |pt| pt.y >= 0.5 }, ~reqd)/*.debug("low y")*/ and: {
			mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean(_.x);
			(mean.inclusivelyBetween(~leftThresh, ~rightThresh).not)/*.debug("x edge")*/ and: { (mean.sign != ~sign)/*.debug("changed sign")*/ }
		}
	) {
		~sign = mean.sign;  // (mean must have been calc'ed to get here)
		~fire.();
	};
};

BP(\tton).mayRelease = true