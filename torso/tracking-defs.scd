// motion tracking
// different objects per section

var ml = Library.at(\motionListener), mg = Library.at(\motionGui);

// abstract prototype

{ |key, ctlKey(~ctlKey)| BP(ctlKey).ctlAt(key) } => Func(\ctlKey);


Proto {
	~specs = OrderedIdentitySet[
		\dftSegReqd -> #[1, 25, \lin, 1, 6],
		\dftSegLo -> #[0, 1, 4, 0, 0.008],
		\dftSegHi -> #[0, 1, 4, 0, 0.25],
		\dftNextSectY -> #[-1, 1, \lin, 0, -0.33],
		\dftMagThresh -> #[0, 1, \lin, 0, 0.7],
		'10filtThresh' -> #[0, 1, \lin, 0, 0.6],
		'10wildThresh' -> #[0, 1, \lin, 0, 0.74],
		// '10magThresh' -> #[0, 1, \lin, 0, 0.7],
		'10wildPts' -> #[0, 10, \lin, 1, 5],
		'10wildDur' -> #[0, 10, \lin, 0, 3],
		'30magThresh' -> #[0, 1, \lin, 0, 0.14],
		'30decayThresh' -> #[0, 1, \lin, 0, 0.5],
		'30decayFactor' -> #[0, 1, \lin, 0, 0.905724],
		'50segThresh' -> #[0, 1, \lin, 0, 0.55],
		'50segReqd' -> #[0, 10, \lin, 1, 5],
		// '50trigReqd' -> #[0, 10, \lin, 1, 5],
		'50trigThresh' -> #[0, 1, \lin, 0, 0.25],
		'60segReqd' -> #[1, 25, \lin, 1, 5],
		'60nextSectY' -> #[-1, 1, \lin, 0, 0.33],
		'90schmidtUp' -> #[-1, 1, \lin, 0, 0.4],
		'90upRatio' -> #[0, 1, \lin, 0, 0.9],
		'90schmidtDown' -> #[0, 1, \lin, 0, 0.22],
		'90downRatio' -> #[-1, 1, \lin, 0, 0.05],
		'90nextSectY' -> #[-1, 1, \lin, 0, 0.4],
		'90segReqd' -> #[1, 25, \lin, 1, 8],
		'100chNumBelow' -> #[0, 10, \lin, 1, 6],
		'100chNumAbove' -> #[0, 10, \lin, 1, 4],
		'100chThresh' -> #[-1, 1, \lin, 0, 0.33],
	];
	~prep = {
		~ctls = IdentityDictionary.new;
		~specs.do { |assn|
			var spec = assn.value.asSpec;
			~ctls[assn.key] = GenericGlobalControl(assn.key, nil, spec.default, spec);
		};
	};
	~freeCleanup = {
		~window.tryPerform(\close);
		~ctls.free;
	};
	~ctlAt = { |key| ~ctls[key] };
	~makeGui = {
		var sbounds = Window.screenBounds;
		if(~window.isNil) {
			~window = Window("motion parameters", Rect(sbounds.right - 450, 0, 450, sbounds.height), scroll: true);
			~flow = FlowView(~window, ~window.view.bounds.height_(5000), 2@2, 4@4);
			Button(~flow, 220@40)
			.states_([["save"]])
			.action_(e {
				File.saveDialog(successFunc: e { |path| ~saveSet.(path) })
			});
			Button(~flow, 220@40)
			.states_([["load"]])
			.action_(e {
				File.openDialog(successFunc: e { |path| ~loadSet.(path) })
			});
			// ~window.view.decorator = FlowLayout(~window.view.bounds.height_(5000), 2@2, 4@4);
			~specs.do { |assn|  // ~specs for the order
				StaticText(~flow, 140@20).align_(\right).string_(assn.key);
				~ctls[assn.key].gui(~flow);
				~flow.startRow;
			};
			~flow.resizeToFitContents;
			~window.onClose_(e { ~window = nil }).front;
		};
		Environment.current;
	};
	~saveSet = { |path|
		~ctls.collect { |ctl| ctl.value }.writeArchive(path);
	};
	~loadSet = { |path|
		var saved = Object.readArchive(path);
		if(saved.isKindOf(Dictionary)) {
			saved.keysValuesDo { |key, value|
				if(~ctls[key].notNil) { ~ctls[key].value = value };
			};
		};
	};
} => PR(\thresholdSet);

\chuckIf.eval(PR(\thresholdSet), BP, \ts);

Proto({
	~ctlKey = \ts;
	~listenKey = \allPtsReceived;
	~waitBeforeAdvance = 5;  // no section should be shorter than 5 seconds

	~segReqd = \ctlKey.eval(\dftSegReqd);  // reqd for transition to next section
	~segTrigCount = 0;
	~segRange = [\ctlKey.eval(\dftSegLo), \ctlKey.eval(\dftSegHi)];
	~nextSectionThresh = \ctlKey.eval(\dftNextSectY);

	~prep = {
		~canAdvanceTime = (SystemClock.beats + ~waitBeforeAdvance); //.debug("set canAdvanceTime");
		~resetSegCheck.();

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
			~prRespond.value(obj, what, moreArgs)
		});
	};
	~nextSegCondition = {
		~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y < ~nextSectionThresh }
	};
	~nextSegCheck = { |obj, what, moreArgs|
		if(SystemClock.beats > ~canAdvanceTime and: { ~nextSegCondition.() }) {
			~segTrigCount = ~segTrigCount - 1;
			if(~segTrigCount == 0) { \goAhead } { \notYet }
		} {
			\respond
		};
	};
	~resetSegCheck = { ~segTrigCount = ~segReqd };
	~prRespond = { |obj, what, moreArgs|
		switch(~nextSegCheck.())
		{ \goAhead } {
			~collIndex.debug("trying to advance to next section");
			if(BP(\segTrig)[\segTrigAction].notNil) { BP(\segTrig).segTrigAction };
		}
		{ \respond } {
			~resetSegCheck.();
			~respond.valueArray(obj, what, moreArgs);
		}
		{ \notYet } {
			~respond.valueArray(obj, what, moreArgs);
		};
	};
}) => PR(\viztrig);



// t2000
(
make: { |name|
	BP(name).free;

	PR(\viztrig).clone({
		~model = ml;
		~keep = 10;
		~reqd = 5;
		~checkX = 3;
		~yThresh = 0.33;
		~leftThresh = -0.55;
		~rightThresh = 0.55;
		~sign = 0;
		~moveAheadIndex = 3;  // index of point where centroid must hover
		~userprep = {
			var division = ~model.dim.reciprocal * 2;
			~last = Array.fill(~keep, 0@0);
			~i = 0;
			~moveAheadRect = Rect(
				(~moveAheadIndex div: ~model.dim) * division - 1,
				(~moveAheadIndex % ~model.dim) * division - 1,
				division, division
			).postcs;
		};
		~respond = { |obj|
			var mean;
			~last[~i] = obj.centroid;
			~i = (~i + 1) % ~keep;

			if(
				~countAtLeast.(~last, { |pt| pt.y >= ~yThresh }, ~reqd) and: {
					mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean(_.x);
					(mean.inclusivelyBetween(~leftThresh, ~rightThresh).not)
					and: { (mean.sign != ~sign) }
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

		~nextSegCondition = {
			~model.normmag.inclusivelyBetween(*~segRange) and: {
				~moveAheadRect.containsPoint(~model.centroid)
			}
		};
	}) => BP(name);
}, type: \bp) => Fact(\t2000trig);


// t2010 and 2020 -- same prototype for both

PR(\viztrig).clone({
	~model = ml;
	~soloproc = \ssd;
	~panMulAdd = #[1, 0];
	~keep = 5;
	~filterMagThresh = \ctlKey.eval('10filtThresh');
	~wildThresh = \ctlKey.eval('10wildThresh');
	~magThresh = \ctlKey.eval(\dftMagThresh);
	~wildPts = \ctlKey.eval('10wildPts');
	~wildDuration = \ctlKey.eval('10wildDur');
	~lastWildTime = 0;
	~ffreqIsOverridden = false;
	~wildGestureRunning = false;

	~userprep = {
		// ~last = Array.fill(~keep, 0);
		~panCtl = BP(~soloproc).gcs[\pan];
		~panLag = ~panCtl.automate({ |pan = 0, lag = 0.15|
			VarLag.kr(pan, lag).madd(*(~panMulAdd));
		});

		~ffreqCtl = BP(~soloproc).gcs[\ffreq];
		~ffreqUpd = Updater(BP(~soloproc), e { |obj, what, node, event|
			var	nodeupd;
			switch(what)
			{ \wildGestureEnded } {
				~wildGestureRunning = false;
				// guarantee minimum time between wild gestures
				~lastWildTime = SystemClock.beats;
				what.debug;
			}
			{ \node } {
				if(event[\synthKey] == \ffreq and: { ~ffreqIsOverridden }) {
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
			~wildGestureRunning = true;
			BP(\segTrig).eventTrigAction;
		};
	};

	// ~clusters = {
	// 	var km = KMeans(2);
	// 	~model.points.do { |pt| km.add([pt.xabs, pt.yabs]) };
	// 	km.update;
	// 	km
	// };

	~respond = {
		var	count;
		// x -> pan
		~panLag.set(\pan, ~model.centroid.x);

		case
		{	// condition
			~wildGestureRunning.not and: {
				count = ~model.points.count { |pt| pt.mag.last > ~wildThresh };
				~model.normmag > ~magThresh and: {
					count >= ~wildPts and: { (SystemClock.beats - ~lastWildTime) > ~wildDuration }
				}
			}
		} {	// action
			[~model.normmag, count].debug("BP(%): wild process triggered".format(~soloproc.asCompileString));
			~lastWildTime = SystemClock.beats;
			~wildFire.();
		}
		{ ~ffreqIsOverridden.not and: { ~wildGestureRunning.not and: { ~model.normmag >= ~filterMagThresh } } } {
			BP(~soloproc).override(\synth, Pn(\ffreq, 1));
			~ffreqIsOverridden = true;
			"BP(%): Overriding ffreq".format(~soloproc.asCompileString).debug;
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


(
make: { |name|
	BP(name).free;
	PR(\t2010trig).chuck(BP(name), nil, (model: ml));
}, type: \bp) => Fact(\t2010trig);

(
make: { |name|
	BP(name).free;
	PR(\t2010trig).chuck(BP(name), nil, (
		model: ml,
		soloproc: \ssd2,
		panMulAdd: #[-1, 0]
	));
}, type: \bp) => Fact(\t2020trig);


// t2030, to come
(
make: { |name|
	BP(name).free;
	PR(\viztrig).clone({
		~model = ml;
		~leftRange = [0.7pi, 1.3pi];
		~magThresh = \ctlKey.eval('30magThresh');
		~decay = 0;
		~decayThresh = \ctlKey.eval('30decayThresh');
		~decayFactor = \ctlKey.eval('30decayFactor');
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
				~sign = new_sign;
				~doAction.();
			};
		};
		~doAction = {
			// "switched to %\n".postf(
			// 	if(~sign < 0) { "left" } { "right" }
			// );
			BP(\thr).sign = ~sign;
			BP(\thr).triggerOneEvent(0);
		};
	}) => BP(name);
}, type: \bp) => Fact(\t2030trig);

(
make: { |name|
	BP(name).free;
	~ctlKey = \ts;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		ptSets: #[[0, 1, 2], [6, 7, 8]],
		magThresh: \ctlKey.eval(\dftMagThresh),
		minRetrigTime: 1.0,
		userprep: {
			~ctls = #[thr, fastnotes].collect { |key| BP(key).stretchCtl };
			~autoSynths = Array.newClear(2);
			// ~endResponders = Array.newClear(2);
			~autoTimes = Array.fill(2, 0);
		},
		userfree: {
			~endResponders.do(_.remove);
			~ctls.do(_.stopAuto);
		},
		autoEnvMiddle: [{ rrand(0.8, 1.25) }, { rrand(0.1, 0.4) }],
		respond: {
			var sum, attack, autotime;
			~ctls.do { |ctl, i|
				if(SystemClock.beats - ~autoTimes[i] > ~minRetrigTime) {
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
						~autoTimes[i] = SystemClock.beats;
						// ~endResponders[i] = SimpleController(~autoSynths[i])
						// .put(\n_end, e {
						// 	~autoSynths[i] = nil;
						// 	~endResponders[i].remove;
						// });
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
		},
	));
}, type: \bp) => Fact(\t2040trig);

(
make: { |name|
	BP(name).free;
	~ctlKey = \ts;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		userprep: {
			~voicer = VC(\tmel).v;  // avoid some dispatches in updateModLev
		},
		// userfree: { ~modlevUpdater.remove },
		updateSynths: {
			var angleLow = ~model.normmag.linlin(0, 0.6, 0.1, 1.5pi);
			~voicer.set([mod_lev: ~model.centroid.y.linexp(-1, 1, 9.0, 0.8)]);
			if(BP(\tp)[\rotSynth].notNil) {
				BP(\tp)[\rotSynth].set(\angleLow, angleLow, \angleHi, angleLow + 0.5);
			};
		},
		segThresh: \ctlKey.eval('50segThresh'),
		reqdPoints: 5,
		segReqd: \ctlKey.eval('50segReqd'),
		nextSegCondition: {
			~model.points.count { |pt| pt.mag.last > ~segThresh } >= ~reqdPoints
		},
		trigCount: 3,
		trigReqd: 3,  // unused?
		trigThresh: \ctlKey.eval('50trigThresh'),
		respond: {
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
	));
}, type: \bp) => Fact(\t2050trig);


(
make: { |name|
	BP(name).free;
	~ctlKey = \ts;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		userprep: {
			~stretchCtl = GenericGlobalControl((~collIndex ++ "Stretch").asSymbol, nil, 1, #[0.1, 10, \exp]);
			~voicer = VC(\tmel).v;  // avoid some dispatches in updateModLev
		},
		userfree: {
			var ctl = ~stretchCtl;
			{ ctl.free }.defer(3);  // seg 2060's processes might break if ctl is freed too soon
		},
		segReqd: \ctlKey.eval('60segReqd'),
		// segRange is inherited
		nextSectionThresh: \ctlKey.eval('60nextSectY'),
		nextSegCondition: {
			~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y > ~nextSectionThresh }
		},
		// trigCount: 3,
		// trigReqd: 3,
		// trigThresh: 0.25,
		respond: {
			~stretchCtl.set(~model.normmag.linexp(0, 1, 4.8, 0.5));
			~voicer.set([mod_lev: ~model.centroid.y.linexp(-1, 1, 15.0, 0.8) * ~model.normmag.linexp(0, 1, 3, 1)]);
			// if(BP(\segTrig)[\eventTrigAction].notNil and: { ~model.normmag > ~trigThresh }) {
			// 	~trigCount = ~trigCount - 1;
			// 	if(~trigCount == 0) {
			// 		BP(\segTrig).eventTrigAction;
			// 	};
			// } {
			// 	~trigCount = ~segReqd;
			// };
		}
	));
}, type: \bp) => Fact(\t2060trig);


{
	Fact(\t2060trig) => BP(\t2070trig);
	BP(\t2070trig).nextSegCondition = {
		~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y < ~nextSectionThresh }
	};
	BP(\t2070trig).nextSectionThresh = -0.33;
	BP(\t2070trig)
} => Func(\makeT2070trig);


(
make: { |name|
	BP(name).free;
	PR(\t2010trig).chuck(BP(name), nil, (
		model: ml,
		soloproc: \ssd2,
		panMulAdd: #[-1, 0],
		nextSegThresh: 0.02,
		nextSegCondition: {
			~model.normmag < ~nextSegThresh
		},
		voicer: VC(\tmel).v,  // cheat
		superRespond: PR(\t2010trig)[\respond],
		respond: {
			// need to continue control of VC(\tmel)'s mod_lev control
			~voicer.set([mod_lev: ~model.centroid.y.linexp(-1, 1, 15.0, 0.8) * ~model.normmag.linexp(0, 1, 3, 1)]);
			~superRespond.();
		}
	));
}, type: \bp) => Fact(\t2080trig);


(
make: { |name|
	BP(name).free;
	~ctlKey = \ts;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		userprep: {
			~testCtl = GenericGlobalControl((~collIndex ++ "TestMag").asSymbol, nil, 0);
		},
		userfree: { ~testCtl.free },
		useGui: { |vpi| ~testCtl => VP(vpi) },
		schmidtUp: \ctlKey.eval('90schmidtUp'),
		upRatio: \ctlKey.eval('90upRatio'),
		schmidtDown: \ctlKey.eval('90schmidtDown'),
		downRatio: \ctlKey.eval('90downRatio'),
		magNow: 0,
		schmidtActive: false,
		respond: {
			var mag = ~model.normmag;
			BP(\bel).panCtl.set(~model.centroid.x);
			if(mag > ~magNow) { mag = ~magNow.blend(mag, ~upRatio) }
			{ mag = ~magNow.blend(mag, ~downRatio) };
			~testCtl.set(mag);
			if(~magNow < ~schmidtUp and: { mag >= ~schmidtUp }) {
				if(~schmidtActive.not and: { BP(\segTrig)[\eventTrigAction].notNil }) {
					BP(\segTrig).eventTrigAction;
					~schmidtActive = true;
				};
			} {
				if(~magNow > ~schmidtDown and: { mag <= ~schmidtDown }) {
					~schmidtActive = false;
				};
			};
			~magNow = mag;
		},
		nextSegCondition: {
			~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y > ~nextSectionThresh }
		},
		segReqd: \ctlKey.eval('90segReqd'),
		nextSectionThresh: \ctlKey.eval('90nextSectY')
	));
}, type: \bp) => Fact(\t2090trig);


(
make: { |name|
	BP(name).free;
	~ctlKey = \ts;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		chordNumBelow: \ctlKey.eval('100chNumBelow'),
		chordNumAbove: \ctlKey.eval('100chNumAbove'),
		chordThresh: \ctlKey.eval('100chThresh'),
		movingAvgSize: 8,
		userprep: {
			// chord check needs to match chordNumBelow y points toward bottom of window,
			// then chordNumAbove points higher
			// easiest is a routine
			~chordCheck = Routine {
				var count, touchedAbove = (~model.centroid.y < ~chordThresh);
				var strings = ["vv MOVE DOWN vv", "^^ MOVE UP ^^"], strI;
				// initialize view
				(e {
					if(touchedAbove) {
						strI = 0;
						~text.background_(Color(1, 0.7, 0.7)).string_(strings[strI]);
					} {
						strI = 1;
						~text.background_(Color(0.7, 1.0, 0.7)).string_(strings[strI]);
					};
				}).defer;
				loop {
					count = 0;
					while { (~model.centroid.y >= ~chordThresh) } {
						false.yield;
						count = count + 1;
						if(count >= ~chordNumBelow and: { strI == 0 }) {
							strI = 1;
							(e {
								~text.background_(Color(0.7, 1.0, 0.7)).string_(strings[strI]);
							}).defer;
						};
					};
					// now centroid y is higher than threshold line
					// but we can only go ahead if the count is high enough
					if(count >= ~chordNumBelow) {
						// fire a chord only if centroid was above, went below, and went up again
						// do not fire a chord the first time if the centroid started below (normal)
						if(touchedAbove) { true.yield };
						// we must stay in the "above threshold" state before allowing a reset
						count = 0;
						while { count <= ~chordNumAbove or: { ~model.centroid.y < ~chordThresh } } {
							false.yield;
							count = count + 1;
							if(count >= ~chordNumAbove and: { strI == 1 }) {
								strI = 0;
								(e {
									~text.background_(Color(1, 0.7, 0.7)).string_(strings[strI]);
								}).defer;
								touchedAbove = true;
							};
						};
					} { false.yield };
				}
			};

			// I need to see the routine's current state during the show
			(e {
				var bounds = Library.at(\motionGui).slotAt(\win).bounds;
				bounds = bounds.moveBy(0, bounds.height).height_(70);
				~win = Window("where to move", bounds);
				~text = StaticText(~win, ~win.view.bounds.insetBy(2, 2))
				.align_(\center).font_(Font.default.copy.size_(18));
				~win.front;
			}).defer;

			~movingAvgBuf = 0 ! ~movingAvgSize;
			~movingAvgI = 0;
			~movingSum = 0;
			~filling = true;
			~stillGoing = true;
		},
		userfree: { (e { ~win.close }).defer },
		nextSegCondition: false,
		radiusThresh: ml.points[1].plotsize.x * 0.06,
		magThresh: 0.012,
		respond: {
			if(~stillGoing) {
				// moving average for filter-envelope opener
				~movingSum = ~movingSum - ~movingAvgBuf[~movingAvgI];
				~movingAvgBuf[~movingAvgI] = ~model.centroid.y.linlin(-0.8, 0.33, 0.8, 0.05);
				~movingSum = ~movingSum + ~movingAvgBuf[~movingAvgI];
				if(~filling) {
					~movingAvgI = ~movingAvgI + 1;
					VC(\wp).globalControls[\fenv_sens].set(~movingSum / ~movingAvgI);
					if(~movingAvgI == ~movingAvgSize) {
						~filling = false;
						~movingAvgI = 0;
					}
				} {
					~movingAvgI = (~movingAvgI + 1) % ~movingAvgSize;
					VC(\wp).globalControls[\fenv_sens].set(~movingSum / ~movingAvgSize);
				};
			};

			case
			{	// chord trigger
				// normally I would put the inexpensive check first,
				// but if the routine doesn't fire right away, it can get stuck in the wrong state
				~chordCheck.next and: { BP(\segTrig).eventTrigsWaiting[2].notNil }
			}
			{
				BP(\segTrig).triggerEventByID(2);
			}
			{	// end trigger: walked off to screen left
				BP(\segTrig).eventTrigsWaiting[100].notNil and: {
					#[3, 4, 5, 6, 7, 8].every { |i| ~model.points[i].mag.last < ~magThresh } and: {
						~model.points[1].radius >= ~radiusThresh and: {
							~model.points[1].angle.inclusivelyBetween(0.8pi, 1.2pi)
						}
					}
				}
			} {
				~stillGoing = false;
				BP(\segTrig).triggerEventByID(100);
			};
		}
	));
}, type: \bp) => Fact(\t2100trig);
