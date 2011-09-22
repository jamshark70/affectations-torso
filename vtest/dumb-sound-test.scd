
m = MixerChannel(\test, s, 2, 2, level: -10.dbamp);
MixingBoard(\test, nil, m);

c = Bus.control(s, 4);

u.remove;
u = SimpleController(BP(\ml)).put(\allPtsReceived, { |bp|
	c.setn([bp.centroid.x, bp.centroid.y, bp.normmag, bp.anglePoint.theta]);
});

a = m.play({ |kb = 0|
	var x, y, mag, theta, sig;
	#x, y, mag, theta = Lag.kr(In.kr(kb, 4), 0.15);
	sig = PinkNoise.ar(mag.linlin(0, 1, 5, 15));
	sig = BPF.ar(sig, y.linexp(-1, 1, 2500, 400), 0.1);
	Pan2.ar(sig, x);
}, [kb: c]);

a.free;

a.trace

PeakMonitor(m);


SynthDef(\boop, { |outbus, freq, pan, sustain = 0.1, amp = 1|
	Out.ar(
		outbus,
		Pan2.ar(
			SinOsc.ar(freq, 0, amp),
			pan,
			EnvGen.ar(Env.perc(0.01, sustain), doneAction: 2)
		)
	)
}).add;

u.remove;
t = BP(\ml).anglePoint.theta;
u = SimpleController(BP(\ml)).put(\allPtsReceived, { |bp|
	var new_t = bp.anglePoint.theta,
		l_r = new_t.inclusivelyBetween(0.5pi, 1.5pi);
	if(t.inclusivelyBetween(0.5pi, 1.5pi) xor: l_r) {
		"switched to %\n".postf(
			if(l_r) { "left" } { "right" }
		);
		m.play(\boop, [freq: bp.centroid.y.linlin(-1, 1, 2500, 400),
			pan: l_r.not.binaryValue * 2 - 1]);
	};
	t = new_t;
});
