// support code
// reads visual analysis OSC messages from PD
// and forwards data to dependents

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
	~viewSize = Point(320, 240);
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
					.prep(xi * ~viewSize.x / ~dim, yi * ~viewSize.y / ~dim)
				);
			};
		};
		~makeResponder.();

		~xbuf = Array.fill(~anglebufSize, 0);
		~ybuf = Array.fill(~anglebufSize, 0);
		~bufIndex = 0;
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
			if(msg[4] == (dim.squared + 1)) {
				// if(~invertY) {
				// 	~blobxy = Point(msg[1], 1.0 - msg[2]);
				// } {
				~blobxy = Point(msg[1], msg[2]);
				// };
				~magsum = msg[3];
				~predict.();
				BP(~collIndex).changed(\allPtsReceived);
			} {
				~points[msg[4] - 1].addPoint(*msg[1..3]).predict;
			};
		}, '/coord');
		CmdPeriod.add(currentEnvironment);
	};
	~removeResponder = { ~resp.free; CmdPeriod.remove(currentEnvironment) };
	// OSCFuncs get killed on cmd-period
	// I don't like it but this is the recommended solution
	~cmdPeriod = { ~makeResponder.() };
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

}) => PR(\motionListener);

// let's do this right... don't fold gui into data-handling class
Proto({
	// ~viewSize = Point(320, 240);
	~gridColor = Color.gray(0.6);
	~pdAddr = NetAddr("127.0.0.1", 57122);
	~noiseReduction = 64;
	~prep = { |model|
		~model ?? { ~model = model };
		~viewSize = ~model.tryPerform(\viewSize) ?? { Point(320, 240) };
		~gridSize = ~viewSize / ~model.dim;
		~model.predict;  // need to fill some variables in the model
		~makeController.();
		~makeViews.();
		~pdHandshake.();
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
		var drawfunc = if(Window.implClass.findRespondingMethodFor(\drawFunc_).notNil)
		{ \drawFunc_ } { \drawHook_ };
		~win = Window(\test, Rect(500, 50, ~viewSize.x, ~viewSize.y + 30));
		// grid background, don't redraw on every userview refresh
		~win.perform(drawfunc, e {
			Pen.color = ~gridColor;
			(~model.dim + 1).do { |i|
				Pen.moveTo(Point(0, i * ~gridSize.y)).lineTo(Point(320, i * ~gridSize.y))
				.moveTo(Point(i * ~gridSize.x, 0)).lineTo(Point(i * ~gridSize.x, 240));
			};
			Pen.stroke;
		});
		~uview = UserView(~win, Rect(0, 0, ~viewSize.x, ~viewSize.y));
		~uview.drawFunc_(e {
			~updateView.();
		});
		// 100 == (320 - 120) / 2
		~onoff = Button(~win, Rect(2, 245, 88, 20))
		.states_([["stopped"], ["running", Color.black, Color(0.6, 1.0, 0.6)]])
		.action_(e { |view|
			~cameraPowerSwitch.(view.value);
		});
		~noiseReduction = EZSlider.new(~win, Rect(92, 245, 318 - 92, 20), "nr", #[0, 127, \lin, 1], action: e { |view|
			~pdAddr.tryPerform(\sendMsg, \noiseReduction, view.value)
		}, initVal: ~noiseReduction, /*initAction: true,*/ labelWidth: 30);
		~win.front.refresh;
		~win.onClose = e { BP(~collIndex).free };
	};
	~updateView = {
		~model.updatePoints;
	};
	~cameraPowerSwitch = { |onoff = 0|
		~pdAddr.tryPerform(\sendMsg, \onOffSwitch, onoff);
		defer(e { ~onoff.value = (onoff > 0).binaryValue });
	};
	~pdHandshake = {
		~handshakeResp = OSCFunc(e {
			~handshakeResp = nil;
			~handshakeThread.stop;
			~handshakeThread = nil;
			~pdAddr.tryPerform(\sendMsg, \noiseReduction, ~noiseReduction.value);
			"Communication with pd is established.".postln;
		}, '/handshakeReply', nil).oneShot;
		~handshakeThread = Task({
			loop {
				~pdAddr.tryPerform(\sendMsg, \handshake);
				0.5.wait;
			};
		}).play;
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
