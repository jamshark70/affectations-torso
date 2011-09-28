
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
	~sign = 0;
	~userprep = {
		~last = Array.fill(~keep, 0@0);
		~i = 0;
	};
	~respond = { |obj|
		var mean;
		~last[~i] = obj.centroid;
		~i = (~i + 1) % ~keep;

~last.collect({ |pt| pt.y.round(0.01) }).debug("y");

		if(
			~countAtLeast.(~last, { |pt| pt.y >= 0.78 }, ~reqd)/*.debug("low y")*/ and: {
				mean = ~last.mean(_.x);
				(mean.abs >= 0.7)/*.debug("x edge")*/ and: { (mean.sign != ~sign)/*.debug("changed sign")*/ }
			}
		) {
			~sign = mean.sign;  // (mean must have been calc'ed to get here)
			"trigger".postln;
		};
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

BP(\t2000trig).checkX = 3;
BP(\t2000trig).respond = { |obj|
	var mean;
	~last[~i] = obj.centroid;
	~i = (~i + 1) % ~keep;

	// ~last.collect({ |pt| pt.y.round(0.01) }).debug("y");

	if(
		~countAtLeast.(~last, { |pt| pt.y >= 0.6 }, ~reqd)/*.debug("low y")*/ and: {
			mean = ~last.wrapAt((~i - ~checkX .. ~i - 1)).mean(_.x);
			(mean.abs >= 0.7)/*.debug("x edge")*/ and: { (mean.sign != ~sign)/*.debug("changed sign")*/ }
		}
	) {
		~sign = mean.sign;  // (mean must have been calc'ed to get here)
		"trigger".postln;
		(
			parent: ProtoEvent(\singleSynthPlayer).copy,
			instrument: \default,
			freq: rrand(60, 72).midicps,
			amp: 0.1,
			sustain: 0.5
		).play;
	};
};
