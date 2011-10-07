
// T2000 - new note when shifting side and in low quadrant
// last 5/10 centroids in opposite side (l/r)
// and y is low


(
s.waitForBoot {
	WrapInstr("analog.sawpulsepan", { |pan = 0|
		Pan2.ar(WrapInstr.wrap("analog.sawpulse", []), pan)
	}, [\bipolar]);

	p = WrapPatch("analog.sawpulsepan", [nil, nil, KrNumberEditor(1, \amp).lag_(nil), nil, Env.adsr(releaseTime: 0.05), Env.one, `2000, `1, `0.5, `0.8, `0, `1.003, 1, 0, 0, SinOsc]);
	d = p.asSynthDef;
	d.add;
	SynthDescLib.at(d.name.asSymbol).msgFuncKeepGate = true;
};
)


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



// t2010: first, detect wild motion
// kmeans centroids are above a certain distance apart

BP(\ml).kmeans.centroids  // if not enough motion, this is empty

BP(\ssd).gcs.pan.autoSynth.trace

(
//BP(\t2010).free;

PR(\viztrig).clone({
	~model = BP(\ml);
	~soloproc = \ssd;
	~panMulAdd = #[1, 0];
	~keep = 5;
	~reqd = 2;
	~i = 0;
	~filterMagThresh = 0.3;
	~wildThresh = 0.65;
	~magThresh = 0.6;
	~wildDuration = 4;
	~lastWildTime = 0;
	~ffreqIsOverridden = false;
	
	~userprep = {
		~last = Array.fill(~keep, 0);

		~panCtl = BP(~soloproc).gcs[\pan];
		~panLag = ~panCtl.automate({ |pan = 0, lag = 0.15|
			VarLag.kr(pan, lag).madd(*(~panMulAdd));
		});

		~ffreqCtl = BP(~soloproc).gcs[\ffreq];
		~ffreqUpd = Updater(BP(~soloproc), e { |obj, what, node, event|
			var	nodeupd;
			if(what == \node and: { event[\synthKey] == \ffreq }) {
				if(~ffreqIsOverridden) {
					NodeWatcher.register(node);
					nodeupd = SimpleController(node).put(\n_end, e {
						nodeupd.remove;
						~ffreqIsOverridden = false;
					});
				};
			};
		});
	};

	~userfree = {
		if(~panCtl.autoSynth === ~panLag) { ~panCtl.stopAuto };
		~ffreqUpd.remove;
	};

	~wildFire = {
		 // trigger main sequence event
		if(BP.exists(\segTrig)) {
			BP(~soloproc).unOverride(\synth);
			BP(\segTrig).eventTrigAction;
		};
	};

	~respond = {
		var	ct = ~model.kmeans.centroids;
		if(ct.size == 2) {
			~last[~i] = (ct[1] - ct[0]).squared.sum.sqrt; // sqrt(dx**2 + dy**2)

			if(
				~model.normmag > ~magThresh and: {
					~every.(~last, ~i - ~reqd + 1, ~i, _ > ~wildThresh)
					and: { (thisThread.beats - ~lastWildTime) > ~wildDuration }
				}
			) {
				~lastWildTime = thisThread.beats;
				~wildFire.();
			};

			~i = (~i + 1) % ~keep;
		} {
			~last.fill(~keep, 0);
			~i = 0;
		};

		// x -> pan, sth -> filter
		~panLag.set(\pan, ~model.centroid.x);
		if(~model.normmag >= ~filterMagThresh and: { ~ffreqIsOverridden.not }) {
			BP(~soloproc).override(\synth, Pn(\ffreq, 1));
			~ffreqIsOverridden = true;
		};
	};

	~every = { |array, i1, i2, func|
		block { |break|
			(i1..i2).do { |i|  // this does not make an array
				if(func.value(array.wrapAt(i)).not) { break.(false) };
			};
			true
		};
	};
}) => PR(\t2010trig);
)

// note, not OK to use BP(\ml) in the PR
// because the PR copies all its child elements, so then BP(\ml) inside !== BP(\ml) outside
// you must pass the model at chuck time
BP(\t2010).free; PR(\t2010trig).chuck(BP(\t2010), nil, (model: BP(\ml)));

BP(\t2020).free; PR(\t2010trig).chuck(BP(\t2020), nil, (model: BP(\ml), soloproc: \ssd2, panMulAdd: #[-1, 0]));

BP(\ssd).gcs.pan.autoSynth.trace

BP.exists(\t2010)
BP(\t2010).model.centroid

PR(\t2010trig).v[\prep].postcs
PR(\t2010trig).v[\makeListener].postcs
PR(\t2010trig).v[\listenKey].postcs

BP(\ml).dependants.includes(BP(\t2010).resp);

BP(\ml).dependants
PR(\t2010trig).v[\model].dependants

.inspect

x = SimpleController(BP(\ml));
x.remove;

Window.allWindows.do { |w| w.name.postln }; ""

BP(\t2010).use {
	~keep = 5;
	~reqd = 2;
	~last = Array.fill(~keep, 0);
	~i = 0;
	~wildThresh = 0.8;
};

BP(\t2010).wildFire = {
	(
		instrument: d.name.asSymbol,
		freq: (#[0, 2, 4] + rrand(28, 42)).degreeToKey(#[0, 2, 4, 5, 7, 9, 11], 12).midicps,
		pan: 0,
		gate: 0.15,
		sustain: 0.07, 
		vsens: 1,
		ffreq: 3000,
		parent: ProtoEvent(\polySynthPlayer).v,
		immediateOSC: true
	).play;
};


BP(\t2010).magThresh = 0.6;

g = GenericGlobalControl(\magthr, nil, 0); g.gui;

BP(\t2010).magThresh = g;  // heh heh... g will respond to math
BP(\t2010).wildThresh = 0.65;

BP(\t2010).wildDuration = 4;
BP(\t2010).lastWildTime = 0;
BP(\t2010).wasWild = false;

BP(\t2010).respond = {
	var	ct = ~model.kmeans.centroids;
	if(ct.size == 2) {
		~last[~i] = (ct[1] - ct[0]).squared.sum.sqrt; // sqrt(dx**2 + dy**2)
		// ~last.rotate(~i.neg - 1).round(0.001).debug("distance");

		// BP(\ml).listVars;
		// BP(\ml).normmag.debug("magnitude");

		if(
			~model.normmag > ~magThresh and: {
				~every.(~last, ~i - ~reqd + 1, ~i, _ > ~wildThresh) // .debug("latest bigger")
				and: { (thisThread.beats - ~lastWildTime) > ~wildDuration }
				// and: { ~every.(~last, ~i - ~keep + 1, ~i - ~reqd, _ <= ~wildThresh).debug("older smaller") }
			}
		) {
			~lastWildTime = thisThread.beats;
			~wildFire.();
		};

		~i = (~i + 1) % ~keep;
	} {
		~last.fill(~keep, 0);
		~i = 0;
	};

	// x -> pan, sth -> filter
};

// efficiency: don't create arrays when not needed
BP(\t2010).every = { |array, i1, i2, func|
[array, i1, i2, func].debug(">> every");
	block { |break|
		(i1..i2).do { |i|  // this does not make an array
			if(func.value(array.wrapAt(i)).not) { break.(false) };
		};
		true
	}.debug("<< every");
};


BP(\t2010).listVars



// t2030
// event on left-right change of direction
// close, but hyper-responsive: fires in one direction, then immediately the other
(
BP(\t2030trig).free;

PR(\viztrig).clone({
	~model = BP(\ml);
	~leftRange = [0.7pi, 1.3pi];
	~magThresh = 0.14;
	~decay = 0;
	~decayThresh = 0.5;
	~decayFactor = 0.905724;
	~isLeft = { |theta| theta.exclusivelyBetween(*(~leftRange)) };
	// ((pi - theta) % 2pi) flips the angle around the vertical axis
	~isRight = { |theta| ((pi - theta) % 2pi).exclusivelyBetween(*(~leftRange)) };
	~signForAngle = { |theta|
		case
		{ ~isLeft.(theta) } { -1 }
		{ ~isRight.(theta) } { 1 }
		{ 0 }
	};
	~respond = {
		var new_theta = ~model.anglePoint.theta,
			new_sign = ~signForAngle.(new_theta);
		if(
			~model.normmag > ~magThresh
			and: { new_sign != 0 and: { new_sign != ~sign } }
		) {
			~decay = 1;
		} {
			~decay = ~decay * ~decayFactor;
		};
		if(~decay > ~decayThresh) {
			~decay = 0;
			"switched to %\n".postf(
				if(new_sign < 0) { "left" } { "right" }
			);
			(
				instrument: d.name,
				freq: exprand(300, 800),
				gate: 0.1,
				sustain: 0.25,
				vsens: 1.0,
				pan: new_sign * 0.8, // ~isLeft.not.binaryValue * 2 - 1,
				immediateOSC: true,
				parent: ProtoEvent(\polySynthPlayer).v.parent
			).play;
			~sign = new_sign;
		};
	};
}) => BP(\t2030trig);
)

g = GenericGlobalControl(\normmag, nil, 0); g.gui;

BP(\t2030trig).magThresh = g;

BP(\t2030trig).leftRange = [0.6pi, 1.4pi];

BP(\t2030trig).leftRange / pi


BP(\t2030trig).keep = 6;
BP(\t2030trig).lastSigns = Array.fill(BP(\t2030trig).keep, 0);
BP(\t2030trig).signIndex = 0;
BP(\t2030trig).signSum = 0;

// this might be usable

BP(\t2030trig).decay = 0;
BP(\t2030trig).decayThresh = 0.5;
BP(\t2030trig).decayFactor = 0.905724;

BP(\t2030trig).respond = {
	var new_theta = ~model.anglePoint.theta,
		new_sign = ~signForAngle.(new_theta);
	// ~prevSum = ~signSum;
	// ~signSum = ~signSum - ~lastSigns[~signIndex] + new_sign;
	// ~lastSigns[~signIndex] = new_sign;
	// ~signIndex = (~signIndex + 1) % ~keep;
	if(
		~model.normmag > ~magThresh
		and: { new_sign != 0 and: { new_sign != ~sign } }
	) {
		~decay = 1;
	} {
		~decay = ~decay * ~decayFactor;
	};
	if(~decay > ~decayThresh) {
		~decay = 0;
		"switched to %\n".postf(
			if(new_sign < 0) { "left" } { "right" }
		);
		(
			instrument: d.name,
			freq: exprand(300, 800),
			gate: 0.1,
			sustain: 0.25,
			vsens: 1.0,
			pan: new_sign * 0.8, // ~isLeft.not.binaryValue * 2 - 1,
			immediateOSC: true,
			parent: ProtoEvent(\polySynthPlayer).v.parent
		).play;
	};
	~sign = new_sign;
};
