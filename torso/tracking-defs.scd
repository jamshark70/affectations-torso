// motion tracking
// different objects per section

var ml = Library.at(\motionListener), mg = Library.at(\motionGui);

// abstract prototype

Proto({
	~listenKey = \allPtsReceived;

	~segReqd = 6;  // reqd for transition to next section
	~segTrigCount = 0;
	~segRange = #[0.008, 0.25];
	~nextSectionThresh = -0.3;

	~prep = {
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
	~nextSegCheck = { |obj, what, moreArgs|
		if(~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y < ~nextSectionThresh }) {
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
				~countAtLeast.(~last, { |pt| pt.y >= 0.5 }, ~reqd) and: {
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
	~wildThresh = 0.8;
	~magThresh = 0.7;
	~wildDuration = 4;
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
		{
			count = ~model.points.count { |pt| pt.mag.last > ~wildThresh };
			~model.normmag > ~magThresh and: {
				count >= 5 and: { (thisThread.beats - ~lastWildTime) > ~wildDuration }
			}
		} {
			[~model.normmag, count].debug("BP(%): wild process triggered".format(~soloproc.asCompileString));
			~lastWildTime = thisThread.beats;
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
		userprep: {
			~ctls = #[thr, fastnotes].collect { |key| BP(key).stretchCtl };
			~autoSynths = Array.newClear(2);
			~endResponders = Array.newClear(2);
		},
		userfree: {
			~endResponders.do(_.remove);
			~ctls.do(_.stopAuto);
		},
		respond: {
			var sum, attack;
			~ctls.do { |ctl, i|
				if(~autoSynths[i].isNil) {
					sum = 0;
					~ptSets[i].do { |ptI| sum = sum + (~model.points[ptI].mag.last / ~model.points[i].maxmag) };
					sum = sum / ~ptSets[i].size;  // in theory, this should range 0..1
					if(sum > ~magThresh) {
						~autoSynths[i] = ctl.automate(\ctlEnv, [
							time: rrand(2.25, 5.75),
							env: Env(
								[4, rrand(0.8, 1.25), 4],
								[attack = rrand(0.1, 0.3), 1 - attack],
								#[-4, 2]
							)
						], addAction: \addToHead);
						~endResponders[i] = SimpleController(~autoSynths[i])
						.put(\n_end, e {
							~autoSynths[i] = nil;
							~endResponders[i].remove;
						});
					};
				};
			};
		},
		// nextSegCheck: { |obj, what, moreArgs|
		// 	if(~model.normmag.inclusivelyBetween(*~segRange) and: { ~model.centroid.y < ~nextSectionThresh }) {
		// 		~segTrigCount = ~segTrigCount - 1;
		// 		if(~segTrigCount == 0) { \goAhead } { \notYet }
		// 	} {
		// 		\respond
		// 	};
		// },
		// resetSegCheck: { ~segTrigCount = ~segReqd }
	));
}, type: \bp) => Fact(\t2040trig);
