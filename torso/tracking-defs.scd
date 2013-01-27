// motion tracking
// different objects per section

var ml = Library.at(\motionListener), mg = Library.at(\motionGui);

// abstract prototype

Proto({
	~listenKey = \allPtsReceived;
	~waitBeforeAdvance = 5;  // no section should be shorter than 5 seconds

	~segReqd = 6;  // reqd for transition to next section
	~segTrigCount = 0;
	~segRange = #[0.008, 0.25];
	~nextSectionThresh = -0.3;

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
		// [SystemClock.beats, ~canAdvanceTime].debug("nextSegCheck");
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
			"trying to advance to next section".debug;
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
		~userprep = {
			~last = Array.fill(~keep, 0@0);
			~i = 0;
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
	}) => BP(name);
}, type: \bp) => Fact(\t2000trig);


// t2010 and 2020 -- same prototype for both

PR(\viztrig).clone({
	~model = ml;
	~soloproc = \ssd;
	~panMulAdd = #[1, 0];
	~keep = 5;
	~filterMagThresh = 0.6;
	~wildThresh = 0.74;
	~magThresh = 0.7;
	~wildPts = 5;
	~wildDuration = 3;
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
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		ptSets: #[[0, 1, 2], [6, 7, 8]],
		magThresh: 0.7,
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
		segThresh: 0.55,
		reqdPoints: 5,
		segReqd: 4,
		nextSegCondition: {
			~model.points.count { |pt| pt.mag.last > ~segThresh } >= ~reqdPoints
		},
		trigCount: 3,
		trigReqd: 3,
		trigThresh: 0.25,
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
		segReqd: 5,
		// segRange is inherited
		nextSectionThresh: 0.33,
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
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		userprep: {
			~testCtl = GenericGlobalControl((~collIndex ++ "TestMag").asSymbol, nil, 0);
		},
		userfree: { ~testCtl.free },
		useGui: { |vpi| ~testCtl => VP(vpi) },
		schmidtUp: 0.4,
		upRatio: 0.9,
		schmidtDown: 0.22,
		downRatio: 0.05,
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
		nextSectionThresh: 0.33
	));
}, type: \bp) => Fact(\t2090trig);


(
make: { |name|
	BP(name).free;
	PR(\viztrig).chuck(BP(name), nil, (
		model: ml,
		chordNumBelow: 6,
		chordNumAbove: 4,
		chordThresh: 0.33,
		movingAvgSize: 8,
		userprep: {
			// chord check needs to match chordNumBelow y points toward bottom of window,
			// then chordNumAbove points higher
			// easiest is a routine
			~chordCheck = Routine {
				var count;
				loop {
					count = 0;
					// I really don't understand: this should be > and the next, <=
					// but it works exactly opposite of how the logic looks
					while { ~model.centroid.y < ~chordThresh } {
						false.yield;
						count = count + 1
					};
					// now centroid y is higher than threshold line
					// but we can only go ahead if the count is high enough
					if(count >= ~chordNumBelow) {
						count = 0;
						while { ~model.centroid.y >= ~chordThresh } {
							false.yield;
							count = count + 1
						};
						(count >= ~chordNumAbove).yield;
					} { false.yield };
				}
			};
			~movingAvgBuf = 0 ! ~movingAvgSize;
			~movingAvgI = 0;
			~movingSum = 0;
			~filling = true;
			~stillGoing = true;
		},
		nextSegCondition: false,
		radiusThresh: ml.points[1].plotsize.x * 0.06,
		magThresh: 0.012,
		respond: {
			if(~stillGoing) {
				// moving average for filter-envelope opener
				~movingSum = ~movingSum - ~movingAvgBuf[~movingAvgI];
				~movingAvgBuf[~movingAvgI] = ~model.centroid.y.linlin(-1, 1, 0.8, 0.05);
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
			}
			{	// chord trigger
				BP(\segTrig).eventTrigsWaiting[1].notNil and: { ~chordCheck.next }
			}
			{
				BP(\segTrig).triggerEventByID(1);
			};
		}
	));
}, type: \bp) => Fact(\t2100trig);
