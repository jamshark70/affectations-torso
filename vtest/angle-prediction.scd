(
Proto({
	~num = 5;
	~color = Color.red;
	~predict_color = Color.blue;
	~magspec = #[0, 20, -6].asSpec;
	~maxmag = 783360;
	~magThresh = 7000;  // below this, ignore the new point
	~predicted = false;
	~prep = { |x_origin = 0, y_origin = 0|
		~x = 0 ! ~num;
		~y = 0 ! ~num;
		~mag = 0 ! ~num;
		// these are fixed values used for the regression
		// calculate once, instead of every time
		~indices = (0 .. ~num-1);
		~i_avg = ~indices.mean;
		~i_minus = ~indices - ~i_avg;
		~i_minus_sqr_sum = ~i_minus.squared.sum;
		~x_origin = x_origin;
		~y_origin = y_origin;
		~color_.(~color);
		currentEnvironment
	};

	~xabs = { ~x.last + ~x_origin };
	~yabs = { ~y.last + ~y_origin };
	~ptabs = { Point(~xabs.(), ~yabs.()) };

	~addPoint = { |y, x, mag|
		var	x1, y1;
		if(mag < ~magThresh) {
			x1 = ~x.last;
			y1 = ~y.last;
		} {
			x1 = x;
			y1 = y;
		};
		~x = ~x.rotate(-1).put(~num-1, x1);
		~y = ~y.rotate(-1).put(~num-1, y1);
		~mag = ~mag.rotate(-1).put(~num-1, mag);
		~predicted = false;
		currentEnvironment
	};
	// two linear regressions: x vs time index, y vs time index
	// this is much more accurate than regressing x vs time and y vs x
	~predict = {
		var y_avg = ~y.mean,
			x_avg = ~x.mean,
			x_slope = (~i_minus * (~x - x_avg)).sum / ~i_minus_sqr_sum,
			y_slope = (~i_minus * (~y - y_avg)).sum / ~i_minus_sqr_sum,
			x_intercept = x_avg - (x_slope * ~i_avg),
			y_intercept = y_avg - (y_slope * ~i_avg);
		~new_x = x_intercept + (x_slope * ~num);  // ~num = high 'i' + 1
		~new_y = y_intercept + (y_slope * ~num);
		~angle = atan2(~y.last - ~new_y, ~x.last - ~new_x);
		~radius = sqrt((~x.last - ~new_x).squared + (~y.last - ~new_y).squared);
		~predicted = true;
		currentEnvironment
	};
	// must call this only from a drawing function
	~plot = {
		var	mag = ~magspec.map(~mag.last / ~maxmag) * 0.5, mg,
			pt1 = Point(~x.last + ~x_origin, ~y.last + ~y_origin),
			pt2;
		~x.do { |x, i|
			mg = mag * i / ~num;
			Pen.color_(~colors[i])
			.fillOval(Rect.aboutPoint(Point(x + ~x_origin, ~y[i] + ~y_origin), mg, mg));
		};
		if(~predicted) {
			mag = mag * 0.5;
			pt2 = Point(~new_x + ~x_origin, ~new_y + ~y_origin);
			Pen.color_(~predict_color)
			.fillOval(Rect.aboutPoint(pt2, mag, mag))
			.moveTo(pt2).lineTo(pt1).stroke;
		};
	};
	~color_ = { |color|
		var	white = Color.white;
		~color = color;
		~colors = Array.fill(~num, { |i|
			color.blend(white, i / ~num);
		}).reverse;
	};
}, parentKeys: #[num, color, magspec, maxmag]) => PR(\regressionUnit);

Proto({
	~dim = 5;
	~ptNum = 5;
	~anglebufSize = 3;
	~maxmag = 3000000;
	~magThresh = 7000;
	~kmSize = 2;
	~prep = {
		~points = Array(~dim.squared);
		~dim.do { |xi|
			~dim.do { |yi|
				~points.add(
					PR(\regressionUnit).copy
					.put(\num, ~ptNum)
					.put(\magThresh, ~magThresh)
					.prep(xi * 64, yi * 48)
				);
			};
		};
		~makeResponder.();

		~xbuf = Array.fill(~anglebufSize, 0);
		~ybuf = Array.fill(~anglebufSize, 0);
		// ~xbufSort = Array.new;
		// ~ybufSort = Array.new;
		~bufIndex = 0;
		// ~prevXMedian = 0;
		// ~prevYMedian = 0;
		~xsum = 0;
		~ysum = 0;
		~prevXSum = 0;
		~prevYSum = 0;

		currentEnvironment
	};
	~freeCleanup = {
		~removeResponder.();
	};
	~makeResponder = {
		if(~resp.notNil) { ~removeResponder.() };
		~resp = OSCFunc(e { |msg|
			~points[msg[4] - 1].addPoint(*msg[1..3]).predict;
			if(msg[4] == ~dim.squared) {
				~predict.();
				BP(~collIndex).changed(\allPtsReceived);
			};
		}, '/coord');
		CmdPeriod.add(currentEnvironment);
	};
	~removeResponder = { ~resp.free; CmdPeriod.remove(currentEnvironment) };
	// OSCFuncs get killed on cmd-period
	// I don't like it but this is the recommended solution
	~cmdPeriod = { "cmdPeriod".debug; ~makeResponder.() };
	// assumes a/ on AppClock b/ on a drawing func
	~updatePoints = {
		~points.do { |pt| pt.plot };
	};

	// rework: anglebuf is now the last few centroids
	// then calculate the slope from linear regression and get the angle from this
	~predict = {
		var /*sum = Point(0, 0),*/ temppt, centroidx = 0, centroidy = 0, magsum = 0,
			theta, insertIndex;
		~kmeans = KMeans(~kmSize);
		~points.do { |p|
			temppt = [p.xabs.linlin(0, 319, -1, 1), p.yabs.linlin(0, 239, -1, 1)];
			centroidx = centroidx + (temppt[0] * p.mag.last);
			centroidy = centroidy + (temppt[1] * p.mag.last);
			magsum = magsum + p.mag.last;
			// if(p.predicted) {
			// 	sum = sum + (Point(p.new_x - p.x.last, p.new_y - p.y.last) * p.mag.last);
			// };
			// 0.75 = y-extent / x-extent
			// preserve the same aspect ratio in kmeans
			if(p.mag.last >= ~magThresh) { ~kmeans.add(temppt * #[1, 0.75]) };
		};
		~rawCentroid = Point(
			(centroidx / max(magsum, 1)), // .linlin(-1, 1, 0, 319),
			(centroidy / max(magsum, 1)) // .linlin(-1, 1, 0, 239)
		);
		~kmeans.update;
		~magsum = magsum;
		~normmag = magsum / ~maxmag;

		~prevXSum = ~xsum;
		~prevYSum = ~ysum;
		~xsum = ~xsum - ~xbuf[~bufIndex] + ~rawCentroid.x;
		~ysum = ~ysum - ~ybuf[~bufIndex] + ~rawCentroid.y;
		~xbuf[~bufIndex] = ~rawCentroid.x;
		~ybuf[~bufIndex] = ~rawCentroid.y;
		~bufIndex = (~bufIndex + 1) % ~anglebufSize;
		~anglePoint = Point(~xsum - ~prevXSum, ~ysum - ~prevYSum);
		~centroid = Point(~xsum / ~anglebufSize, ~ysum / ~anglebufSize);

		currentEnvironment
	};

	// ~regress = { |pts|
	// 	var x = pts.collect(_.x),
	// 		y = pts.collect(_.y),
	// 		y_avg = y.mean,
	// 		x_avg = x.mean,
	// 		x_slope = (~i_minus * (x - x_avg)).sum / ~i_minus_sqr_sum,
	// 		y_slope = (~i_minus * (y - y_avg)).sum / ~i_minus_sqr_sum,
	// 		x_intercept = x_avg - (x_slope * ~i_avg),
	// 		y_intercept = y_avg - (y_slope * ~i_avg);
	// 	~new_x = x_intercept + (x_slope * ~anglebufSize);  // ~num = high 'i' + 1
	// 	~new_y = y_intercept + (y_slope * ~anglebufSize);
	// 	~anglePoint = Point(x.last - ~new_x, y.last - ~new_y);
	// 	// ~angle = ~anglePoint.theta;
	// 	// ~radius = ~anglePoint.rho; //sqrt((x.last - ~new_x).squared + (y.last - ~new_y).squared);
	// 	currentEnvironment
	// };

	/*
	~predict = {
		var sum = Point(0, 0), temppt, centroidx = 0, centroidy = 0, magsum = 0;
		~kmeans = KMeans(~kmSize);
		~points.do { |p|
			temppt = [p.xabs.linlin(0, 319, -1, 1), p.yabs.linlin(0, 239, -1, 1)];
			centroidx = centroidx + (temppt[0] * p.mag.last);
			centroidy = centroidy + (temppt[1] * p.mag.last);
			magsum = magsum + p.mag.last;
			if(p.predicted) {
				sum = sum + (Point(p.new_x - p.x.last, p.new_y - p.y.last) * p.mag.last);
			};
			// 0.75 = y-extent / x-extent
			// preserve the same aspect ratio in kmeans
			if(p.mag.last >= ~magThresh) { ~kmeans.add(temppt * #[1, 0.75]) };
		};
		~centroid = Point(
			(centroidx / max(magsum, 1)), // .linlin(-1, 1, 0, 319),
			(centroidy / max(magsum, 1)) // .linlin(-1, 1, 0, 239)
		);
		~kmeans.update;
		~magsum = magsum;
		~normmag = magsum / ~maxmag;
		~anglebuf.wrapPut(~anglebufIndex, sum);
		~anglebufIndex = ~anglebufIndex + 1;
		sum = Point(0, 0);
		~anglebuf.do { |pt| sum = sum + pt };
		~anglePoint = sum;
		currentEnvironment
	};
	*/
}) => PR(\motionListener);

// let's do this right... don't fold gui into data-handling class
Proto({
	~gridColor = Color.gray(0.6);
	~pdAddr = NetAddr("127.0.0.1", 57122);
	~noiseReduction = 64;
	~prep = { |model|
		~model ?? { ~model = model };
		~model.predict;  // need to fill some variables in the model
		~makeController.();
		~makeViews.();
		currentEnvironment
	};
	~freeCleanup = {
		~controller.remove;
		~win.tryPerform(\close);
	};
	~makeController = {
		var updateFunc = inEnvir { ~uview.refresh };
		~controller = SimpleController(~model)
		.put(\allPtsReceived, {
			defer(updateFunc)
		});
	};
	~makeViews = {
		~win = Window(\test, Rect(500, 50, 320, 270));
		// grid background, don't redraw on every userview refresh
		~win.drawFunc = e {
			Pen.color = ~gridColor;
			(~model.dim + 1).do { |i|
				Pen.moveTo(Point(0, i * 48)).lineTo(Point(320, i * 48))
				.moveTo(Point(i * 64, 0)).lineTo(Point(i * 64, 240));
			};
			Pen.stroke;
		};
		~uview = UserView(~win, Rect(0, 0, 320, 240));
		~uview.drawFunc_(e {
			~updateView.();
		});
		// 100 == (320 - 120) / 2
		~onoff = Button(~win, Rect(2, 245, 88, 20))
		.states_([["stopped"], ["running", Color.black, Color(0.6, 1.0, 0.6)]])
		.action_(e { |view|
			~pdAddr.tryPerform(\sendMsg, \onOffSwitch, view.value)
		});
		~noiseReduction = EZSlider.new(~win, Rect(92, 245, 318 - 92, 20), "nr", #[0, 127, \lin, 1], action: e { |view|
			~pdAddr.tryPerform(\sendMsg, \noiseReduction, view.value)
		}, initVal: ~noiseReduction, initAction: true, labelWidth: 30);
		~win.front.refresh;
		~win.onClose = e { BP(~collIndex).free };
	};
	~updateView = {
		~model.updatePoints;
	};
}) => PR(\motionGui);

PR(\motionGui).clone({
	~angleColor = Color.gray;
	~superPrep = ~prep;
	~prep = {
		var	colorTemp = [0.1, 0.1, 1.0];
		~superPrep.();
		~kmeansColors = Array.fill(~model.kmSize, {
			colorTemp = colorTemp.rotate(1);
			Color(*(colorTemp ++ #[0.4]))
		});
	};
	~updateView = {
		var bounds = ~uview.bounds, ctr, pt;
		pt = ~model.anglePoint;
		ctr = ~model.centroid * 0.5 + 0.5 * Point(319, 239);
		Pen.color_(~angleColor)
		.fillRect(Rect.aboutPoint(ctr, 6, 6))
		.width_(4)
		.line(ctr, ctr + Polar(bounds.height * 0.4 * ~model.normmag, atan2(pt.y, pt.x)).asPoint)
		.stroke.width_(1);
		~model.kmeans.centroids.do { |pair, i|
			pair = pair * 0.5 + 0.5 * #[319, 319];
			Pen.color_(~kmeansColors[i])
			.fillOval(Rect.aboutPoint(Point(*pair), 16, 16));
		};
		~model.updatePoints;
	};
}) => PR(\motionAngleGui);

Proto({
	~channels = 3;
	~chunkFrames = 1024;
	~model_ = { |newModel|
		~removeResponder.();
		~model = newModel;
		if(~soundfile.notNil) { ~makeResponder.() };
		currentEnvironment
	};
	~startLog = { |filename|
		var dir = ~dir ?? { thisProcess.nowExecutingPath.dirname },
			path = dir +/+ (filename ?? { "datalog%.aiff".format(Date.getDate.stamp) });
		if(~soundfile.isNil) {
			path = path.standardizePath;
			~soundfile = SoundFile(path).headerFormat_("AIFF").sampleFormat_("float")
			.numChannels_(~channels);
			if(~soundfile.openWrite.not) {
				~soundfile.close;
				~soundfile = nil;
				"couldn't open % for writing".format(path).error;
			} {
				~bufsize = ~channels * ~chunkFrames;
				~dataBuf = FloatArray.new(~bufsize);
				~makeResponder.();
			};
		} {
			"Already logging.".warn;
		};
		currentEnvironment
	};
	~stopLog = {
		if(~soundfile.notNil) {
			~removeResponder.();
			~soundfile.writeData(~dataBuf);
			~soundfile.close;
			~soundfile = nil;
		};
		currentEnvironment
	};
	~makeResponder = {
		if(~resp.isNil) {
			~resp = SimpleController(~model)
			.put(\allPtsReceived, e { ~addData.(); })
		};
	};
	~removeResponder = {
		if(~resp.notNil) { ~resp.remove; ~resp = nil; };
	};
	~addData = {
		~model.points.do { |pt|
			~dataBuf.add(pt.x.last).add(pt.y.last).add(pt.mag.last);
			if(~dataBuf.size == ~bufsize) {
				~soundfile.writeData(~dataBuf);
				~dataBuf = FloatArray.new(~bufsize);
			};
		};
	};
	~freeCleanup = {
		~stopLog.();
		~removeResponder.();
	};
}) => PR(\soundFileLogger);

Proto({
	~dir = thisProcess.nowExecutingPath.dirname;
	~file = "datalog110921_185859.aiff";
	~channels = 3;
	~frameRate = 50;
	~loop = 0;
	~alwaysReset = true;
	~prep = { |model|
		~buf = Buffer.readAndQuery(s, (~dir +/+ ~file).standardizePath);
		if(model.notNil) { ~model = model };
		~makeSynthDef.();
		~makeResponder.();
		currentEnvironment
	};
	~makeSynthDef = {
		var size = ~model.points.size;
		~def = SynthDef("logread%x%".format(size, ~channels).asSymbol,
			{ |bufnum, frameRate, loop = 0|
				var	t = Impulse.kr(frameRate),
				frames = BufFrames.kr(bufnum) / size,
				framePlus = (0 .. size - 1),
				frameCount = Demand.kr(t, 0, Dseq([Dseries(0, 1, frames)], inf)),
				xymags = BufRd.kr(~channels, bufnum,
					frameCount * size + framePlus,
					loop: 0, interpolation: 1);
				FreeSelf.kr((loop <= 0) * (frameCount >= (frames-1)));
				xymags.do { |point, i|
					SendReply.kr(t, '/coordlog', point, i);
				};
			}
		).add;
	};
	~makeResponder = {
		~resp = OSCFunc(e { |msg|
			~model.points[msg[2]].addPoint(*msg[3..]).predict;
			if(msg[2] + 1 == ~model.dim.squared) {
				~model.predict;
				~model.changed(\allPtsReceived);
			};
		}, '/coordlog', s.addr);
	};
	~freeCleanup = {
		[~buf, ~resp].free;
	};
	~asPattern = {
		Prout({
			var thisbp = BP(~collIndex);
			if(~synth.isNil) {
				if(~endResp.notNil) { ~endResp.free };
				~synth = Synth(~def.name, [bufnum: ~buf, frameRate: ~frameRate, loop: ~loop]);
				~endResp = OSCFunc(
					OSCArgsMatcher([~synth.nodeID], e { ~synth = nil; thisbp.stop(0) }),
					'/n_end', s.addr
				);
			};
			loop { 10.wait };
		});
	};
	~stopCleanup = {
		if(~synth.notNil) { ~synth.free; ~synth = nil };
		~endResp.free;
	};
}) => PR(\soundFileReader);
)

// launch pd patch (too lazy to do by gui)
// open this before creating BPs - the gui sends a /noiseReduction message on init
"xdg-open %".format((thisProcess.nowExecutingPath.dirname +/+ "frame-diff5.pd").escapeChar($ )).unixCmd;

BP(\mg).free;
BP(#[mg, ml]).free;
PR(\motionListener).chuck(BP(\ml), nil, (ptNum: 3, anglebufSize: 5));
PR(\motionAngleGui).chuck(BP(\mg), nil, (model: BP(\ml)));

BP(\ml).anglebufSort

u.remove;
u = SimpleController(BP(\ml)).put(\allPtsReceived, { BP(\ml).anglePoint.theta.debug("theta") });

l = List.new;
u.put(\allPtsReceived, {
	l.add(BP(\ml).anglePoint.theta);
	if(l.size == 200) {
		u.put(\allPtsReceived, nil);
		defer { l.asArray.plot2(minval: -pi, maxval: pi) };
	};
});

-21.053447383069.wrap(-pi, pi) / pi * 180

BP(\ml).kmeans.centroids.do(_.postln); ""

BP(\lp).free;
PR(\soundFileReader).chuck(BP(\lp), nil, (model: BP(\ml), quant: 0, frameRate: 8));

MT(1).gui;
BP(\lp) => MT(1);

BP(\lp).frameRate = 10;  // interesting - maybe not all data from pd come through?

BP(\lp).play;
BP(\lp).synth.trace;

BP(\lp).quant = 0;

BP(\lp).play;

BP(\lp).model.points[0].listVars;

BP(\ml).dependants.do { |dep| dep.instVarAt(1)[\allPtsReceived].def.dumpByteCodes }

BP(\log).free;
PR(\soundFileLogger).chuck(BP(\log), nil, (model: BP(\ml)));

BP(\log).startLog;
BP(\log).stopLog;

BP(\log).listVars;

BP(\ml).dependants


// watch magnitudes
// seems i can normalize to roughly 3000000
r = Routine {
	loop {
		BP(\ml).magsum.postln;
		3.do { 1.yield };
	};
};

u.remove;
u = Updater(BP(\ml), { |obj, what|
	if(what == \allPtsReceived) { r.next };
});



BP(#[mg, ml]).free;
PR(\proxListener) => BP(\ml);
PR(\motionGui).chuck(BP(\mg), nil, (model: BP(\ml)));

BP(\ml).points.do { |pt| pt.proxthresh = 24 };
BP(\ml).points.do { |pt| pt.magThresh = 0 };

BP.exists(\mg)

BP(\ml).listVars
BP.keys

BP(\ml).points.do { |pt, index|
	pt.plot = {
		var	mag = ~magspec.map(~mag.last / ~maxmag) * 0.5,
			pt1 = Point(~x.last + ~x_origin, ~y.last + ~y_origin),
			proxpt,
		pt2;
		Pen.color_(~color).width_(1)
		.fillOval(Rect.aboutPoint(pt1, mag, mag));
		// draw line for proximity?
		if(~proxHit.notNil) {
			// proxpt = ~proxPts[~proxIndex];
			// pt2 = Point(proxpt.x.last + proxpt.x_origin, proxpt.y.last + proxpt.y_origin);
[index, ~proxIndex, pt1, ~proxHit, rho(pt1 - ~proxHit)].asCompileString.debug("proximity line");
			Pen.width_(3)
			.line(pt1, ~proxHit)
			.stroke;
		};
	};
	pt.predict = {
		var	distances = ~proxPts.collect { |pt, i|
			hypot(~x.last + ~x_origin - (pt.x.last + pt.x_origin),
				~y.last + ~y_origin - (pt.y.last + pt.y_origin))
		},
		i = distances.minIndex;
		~proxHit = if(distances[i] <= ~proxthresh) {
			pt = ~proxPts[i];
			Point(pt.x.last + pt.x_origin, pt.y.last + pt.y_origin)
		} { nil };
		// if(~proxIndex.notNil) {
		// 	~proxIndex.debug("proxIndex");
		// 	[distances[i], ~x.last + ~x_origin, (),
		// 		~y.last + ~y_origin, (pt.y.last + pt.y_origin)].debug("points");
		// };
	};
};


BP(\ml).points[12].predict = {
		var	distances = ~proxPts.collect { |pt, i|
			hypot(~x.last + ~x_origin - (pt.x.last + pt.x_origin),
				~y.last + ~y_origin - (pt.y.last + pt.y_origin))
		},
		i = distances.debug("distances").minIndex;
		~proxIndex = if(distances[i] <= ~proxthresh) { i } { nil };
	~proxIndex.debug("proxIndex");
	};



BP(\ml).resp.func.inspect
BP(\ml).points[1].listVars

BP(\ml).points.select { |pt| pt.proxPts.size == 0 }.size


OSCFunc.allFuncProxies

x = BP(\ml).points.detect { |pt| pt.new_y == inf };
x.listVars


// points return to center when no activity
// try to find a threshold?

u.remove;
u = SimpleController(BP(\ml)).put(\allPtsReceived, {
	var	pt = BP(\ml).points[0];
	pt.mag.last.postln;
});


// averaging angles -- but I want a weighted average, so *not* unit vectors
p = BP(\ml).points[12];
p.listVars

p.angle / 2pi * 360

u = atan2(p.y.last - p.new_y, p.new_x - p.x.last);
u / 2pi * 360

p.x ++ p.new_x
p.y ++ p.new_y

z = ((p.x - p.x.mean) * (p.y - p.y.mean)).sum.neg / (p.x - p.x.mean).squared.sum;
t = atan(z);

// vector (non-unit) average
z = Point(0, 0);
BP(\ml).points.do { |p|
	// note, inverting 'y' because gui y coordinates increase going down
	z = z + (Point(p.new_x - p.x.last, p.y.last - p.new_y) * p.mag.last);
};
z

z.theta / 2pi * 360


		var y_avg = ~y.mean,
			x_avg = ~x.mean,
			x_minus = ~x - x_avg,
			slope = (x_minus * (~y - y_avg)).sum / max((x_minus.squared).sum, 0.0001),
			intercept = y_avg - (slope * x_avg),
			// really I just need to know if this is negative or positive
			new_x_slope = (~i_minus * x_minus).sum / (~i_minus.squared).sum,
			new_x_intercept = x_avg - (new_x_slope * ~i_avg);
		~new_x = new_x_intercept + (new_x_slope * ~num);  // ~num = high 'i' + 1
		~new_y = intercept + (slope * ~new_x);
		~angle = atan(slope) + (pi * binaryValue(new_x_slope < 0));
		~radius = sqrt((~x.last - ~new_x).squared + (~y.last - ~new_y).squared);


BP(\mg).anglebuf = Array.fill(3, { 0@0 });
BP(\mg).anglebufIndex = 0;
BP(\mg).anglebufSum = 0@0;

BP(\mg).updateView = {
	var sum = Point(0, 0), bounds = ~uview.bounds, ctr = bounds.center;
	~model.points.do { |p|
		if(p.predicted) {
			sum = sum + (Point(p.new_x - p.x.last, p.new_y - p.y.last) * p.mag.last);
		};
	};
//	~anglebufSum = ~anglebufSum.debug("sum before") - ~anglebuf.wrapAt(~anglebufIndex).debug("removing old") + sum.debug("adding new");
	~anglebuf.wrapPut(~anglebufIndex, sum);
	~anglebufIndex = ~anglebufIndex + 1;
	sum = Point(0, 0);
	~anglebuf.do { |pt| sum = sum + pt };
	// sum = ~anglebuf.sum;
// [sum, atan2(sum.y.neg, sum.x)].debug("sum, angle");
	Pen.color_(~angleColor).width_(5)
	.line(ctr, ctr + Polar(bounds.height * 0.4, atan2(sum.y, sum.x)).asPoint)
	.stroke.width_(1);
	~model.updatePoints;
};


[Point(1, 1), Point(2, 2)].sum

0 + Point(1, 1)


~pdAddr.tryPerform(\sendMsg, \onOffSwitch, 0)


f = SoundFile.openRead("datalog110921_185859.aiff".resolveRelative);
f.dump
f.readData(d = FloatArray.newClear(f.numFrames * f.numChannels));
f.close;

5125 / 25
205 / 50

d