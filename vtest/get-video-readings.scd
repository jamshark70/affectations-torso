(
var	mypath = thisProcess.nowExecutingPath, indices, motionListener, motionGui;

"ps x | grep 'pd-extended' | grep -v 'grep'".unixCmd(e { |result|
	if(result > 0) {
		// pd is not running; load the video patch
		"pd-extended %".format(
			(HrVideoData.filenameSymbol.asString.dirname.dirname.dirname
				+/+ "common/frame-diff-gem-no-close.pd").escapeChar($ )
		).unixCmd;
	};
}, postOutput: true);  // postOutput is required to avoid "broken pipe"

l = HrVideoListener(3, 3);
motionGui = g = HrVideoAngleGui(l, pdAddr: NetAddr("127.0.0.1", 57122));

ShutDown.add { motionGui.pdAddr.sendMsg('/quitPd') };
)

l = Library.at(\motionListener);

u.remove; u = SimpleController(l);

c.free; c = GenericGlobalControl(\test, nil, 0, [0, 1]);
c => VP(0);
c.gui;
// c.spec = [0, 1].asSpec;
c =>.3 VP(4);

u.put(\allPtsReceived, { c.set(l.points[0].mag.last) });

u.put(\allPtsReceived, { c.set(l.normmag) });

u.put(\allPtsReceived, nil);

BP(\t2010trig).segRange = #[0.008, 0.25];

i = 6;
u.put(\allPtsReceived, {
	c.set(l.normmag);
	if(l.normmag.inclusivelyBetween(0.012, 0.25) and: { l.centroid.y < -0.3 }) {
		i = i - 1;
		if(i == 0) { "got 6 in a row".debug; u.put(\allPtsReceived, { c.set(l.normmag) }); };
	} {
		if(l.centroid.y >= -0.3) { "failed: y".debug }
		{ "failed: normmag".debug }
	};
});

BP(\t2000trig).listVars;

u.put(\allPtsReceived, {
	var sum = 0;
	#[0].do { |ptI| sum = sum + (l.points[ptI].mag.last / l.points[ptI].maxmag) };
	// sum = sum / 3;  // in theory, this should range 0..1
	c.set(sum);
});

[l.points[1].mag.last, l.points[1].maxmag]

ChuckableBrowser.newWindow;

BP(\thr).stretchCtl.watch.gui;
KrBusWatcher.newFrom(s).updateFreq = 6;

BP(\fastnotes).stretchCtl.watch.gui;

BP(\thr).amp = BP(\thr).stretchCtl.asPattern.linlin(1, 4, 6.dbamp, 1);

BP(\fastnotes).gate.postcs

BP(\fastnotes).gate = BP(\fastnotes).stretchCtl.asPattern.linlin(1, 4, 0.4, 1);

BP(\fastnotes).event.voicer
VC.keys;
VC(\tmel).v.nodes[0].initArgs
VC(\tmel).v.gui;

BP(\t2040trig)[\respond].postcs
VC(\tmel).globalControls[\finalAmp].watch;

KrBusWatcher.newFrom(s).nodes

(
BP(\t2040trig).autoEnvMiddle = [{ rrand(0.8, 1.25) }, { rrand(0.1, 0.4) }];
BP(\t2040trig).respond = {
	var sum, attack, autotime;
	~ctls.do { |ctl, i|
		if(~autoSynths[i].isNil) {
			sum = 0;
			~ptSets[i].do { |ptI| sum = sum + (~model.points[ptI].mag.last / ~model.points[i].maxmag) };
			sum = sum / ~ptSets[i].size;  // in theory, this should range 0..1
			if(sum > ~magThresh) {
				~autoSynths[i] = ctl.automate(\ctlEnv, [
					time: autotime = rrand(2.25, 5.75),
					env: Env(
						[4, ~autoEnvMiddle[i].value, 4],
						[attack = rrand(0.04, 0.16), 1.0 - attack],
						#[-4, 2]
					)
				], addAction: \addToHead);
				~endResponders[i] = SimpleController(~autoSynths[i])
				.put(\n_end, e {
					~autoSynths[i] = nil;
					~endResponders[i].remove;
				});
				// total hack: this is not properly abstracted
				if(i == 1) {
					VC(\tmel).globalControls[\finalAmp].automate(\ctlEnv, [
						time: autotime,
						env: Env(
							[0.11, rrand(0.175, 0.195), 0.11],
							[attack, 1.0 - attack],
							#[-2, 2]
						)
					], addAction: \addToHead);
				};
			};
		};
	};
};
)


u.put(\allPtsReceived, {
	VC(\tmel).v.set([mod_lev: l.centroid.y.linexp(-1, 1, 9.0, 0.8)]);
});


BP(\t2050trig).nextSegCondition = {
	~model.points.count({ |pt| pt.mag.last > ~segThresh }).debug("count") > ~reqdPoints
};

BP(\t2050trig).segThresh = 0.5;
BP(\t2050trig).reqdPoints = 4;


BP(\t2050trig).updateSynths = {
	~voicer.set([mod_lev: ~model.centroid.y.linexp(-1, 1, 9.0, 0.8)]);
	if(BP(\tp)[\rotSynth].notNil) {
		BP(\tp)[\rotSynth].set(\angleRate, ~model.normmag.linlin(0, 0.6, 0.5, 7.0));
	};
};

BP(\tp).rotSynth.get(\angleRate, { |d| d.debug("\tgot") });

BP(\tp).rotSynth.trace;

BP(\t2050trig).trigThresh = 0.25;

BP(\t2050trig).respond = {
	~updateSynths.();
	if(BP(\segTrig)[\eventTrigAction].notNil and: { ~model.normmag > ~trigThresh }) {
		~trigCount = ~trigCount - 1;
		if(~trigCount == 0) {
			BP(\segTrig).eventTrigAction;
		};
	} {
		~trigCount = ~segReqd;
	};
},



BP(\t2060trig).respond = {
	~stretchCtl.set(~model.normmag.linexp(0, 1, 4.8, 0.5));
	~voicer.set([mod_lev: ~model.centroid.y.linexp(-1, 1, 15.0, 0.8) * ~model.normmag.linexp(0, 1, 3, 1)]);
	if(BP(\segTrig)[\eventTrigAction].notNil and: { ~model.normmag > ~trigThresh }) {
		~trigCount = ~trigCount - 1;
		if(~trigCount == 0) {
			BP(\segTrig).eventTrigAction;
		};
	} {
		~trigCount = ~segReqd;
	};
};

VC.keys.detect { |vc| VC(vc).v === BP(\fastnotes).event.voicer };

VC(\tmel).globalControls[\mod_lev].spec
VC(\tmel).globalControls[\mod_lev].spec = ControlSpec(0.1, 50, \exp);


BP(\bel).panCtl =>.3 VP(4);
BP(\t2090trig).testCtl =>.2 VP(4);


BP(\bel).debug = true;


// walk away from machine
// centroid within all 3 at side will move inside --> outside

l.points[1].dump

u.put(\allPtsReceived, { c.set(l.points[1].x.last / l.points[1].plotsize.x) });

atan2(0, -1)

z = l.points[1].plotsize.x * 0.06;

u.put(\allPtsReceived, {
	if(#[3, 4, 5, 6, 7, 8].every { |i| l.points[i].mag.last < 0.012 } and: {
		l.points[1].radius >= z and: { l.points[1].angle.inclusivelyBetween(0.8pi, 1.2pi) }
	}) {
		"\n\nAlmost exited".postln;
		(degree: (0..7).scramble.keep(4), sustain: 2).play;
	};
});

u.put(\allPtsReceived, {
	l.points[1].angle.postln;
});

w = UserView(nil, Rect(800, 400, l.points[1].plotsize.x * 3, l.points[1].plotsize.y * 3)).front;

(
var color = Color.black, pt = l.points[1].plotsize * (0.5 * 3);

w.drawFunc = {
	var // Point(l.points[1].x.last, l.points[1].y.last),
	theta = l.points[1].angle;
	Pen.color_(color)
	.moveTo(pt)
	.lineTo(Polar(50, theta).asPoint + pt)
	.stroke;
};
)

w.refresh;

u.put(\allPtsReceived, { defer { w.refresh } });
u.put(\allPtsReceived, nil);



BP(\segTrig).eventTrigCmdByID(1);
BP(\segTrig).eventTrigsWaiting;

BP(\segTrig).eventTrigsWaiting[1][0].listVars

BP(\segTrig).eventTrigCmdByID(100);

BP(\segTrig).triggerEventByID(1);
BP(\segTrig).triggerEventByID(100);
