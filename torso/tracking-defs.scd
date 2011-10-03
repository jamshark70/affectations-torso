// motion tracking
// different objects per section


// abstract prototype

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


// t2000
(
make: { |name|
	BP(name).free;

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


(
make: { |name|
	BP(name).free;
	PR(\t2010trig).chuck(BP(name), nil, (model: BP(\ml)));
}, type: \bp) => Fact(\t2010trig);

(
make: { |name|
	BP(name).free;
	PR(\t2010trig).chuck(BP(name), nil, (
		model: BP(\ml),
		soloproc: \ssd2,
		panMulAdd: #[-1, 0]
	));
}, type: \bp) => Fact(\t2020trig);


// t2030, to come
