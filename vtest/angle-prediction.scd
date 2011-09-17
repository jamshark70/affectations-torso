// size is wrong
// frames are mapped wrong

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
		~x_origin = x_origin;
		~y_origin = y_origin;
		currentEnvironment
	};
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
	~predict = {
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

		// if(~x_origin + ~y_origin == 0) {
		// 	[~y, y_avg].debug("y");
		// 	[~x, x_avg, x_minus].debug("x");
		// 	[slope, intercept].debug("slope, intercept");
		// 	[new_x_slope, new_x_intercept].debug("new_x slope, intercept");
		// 	[~new_x, ~new_y].debug("new (cartesian)");
		// 	[~angle, ~radius].debug("new (polar)");
		// };

		~predicted = true;
		currentEnvironment
	};
	// must call this only from a drawing function
	~plot = {
		var	mag = ~magspec.map(~mag.last / ~maxmag) * 0.5,
			pt1 = Point(~x.last + ~x_origin, ~y.last + ~y_origin),
			pt2;
		Pen.color_(~color)
		.fillOval(Rect.aboutPoint(pt1, mag, mag));
		if(~predicted) {
			mag = mag * 0.5;
			pt2 = Point(~new_x + ~x_origin, ~new_y + ~y_origin);
			Pen.color_(~predict_color)
			.fillOval(Rect.aboutPoint(pt2, mag, mag))
			.moveTo(pt2).lineTo(pt1).stroke;
		};
	};
}, parentKeys: #[num, color, magspec, maxmag]) => PR(\regressionUnit);

Proto({
	~dim = 5;
	~prep = {
		~points = Array(~dim.squared);
		~dim.do { |xi|
			~dim.do { |yi|
				~points.add(PR(\regressionUnit).copy.prep(xi * 64, yi * 48));
			};
		};
		~makeResponder.();
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
				BP(~collIndex).changed(\allPtsReceived);
			};
		}, '/coord');
	};
	~removeResponder = { ~resp.free };
	// assumes a/ on AppClock b/ on a drawing func
	~updatePoints = {
		~points.do { |pt| pt.plot };
	};
}) => PR(\motionListener);

// let's do this right... don't fold gui into data-handling class
Proto({
	~gridColor = Color.gray(0.6);
	~prep = { |model|
		~model ?? { ~model = model };
		~makeController.();
		~makeViews.();
		currentEnvironment
	};
	~freeCleanup = {
		~controller.remove;
		~win.close;
	};
	~makeController = {
		var updateFunc = inEnvir { ~uview.refresh };
		~controller = SimpleController(~model)
		.put(\allPtsReceived, {
			defer(updateFunc)
		});
	};
	~makeViews = {
		~win = Window(\test, Rect(500, 50, 320, 240));
		// grid background, don't redraw on every userview refresh
		~win.drawFunc = e {
			Pen.color = ~gridColor;
			5.do { |i|
				Pen.moveTo(Point(0, i * 48)).lineTo(Point(320, i * 48))
				.moveTo(Point(i * 64, 0)).lineTo(Point(i * 64, 240));
			};
			Pen.stroke;
		};
		~uview = UserView(~win, ~win.view.bounds);
		~uview.drawFunc_(e {
			~model.updatePoints;
		});
		~win.front.refresh;
		~win.onClose = e { BP(~collIndex).free };
	};
}) => PR(\motionGui);
)

BP(#[mg, ml]).free;
PR(\motionListener) => BP(\ml);
PR(\motionGui).chuck(BP(\mg), nil, (model: BP(\ml)));


BP(\ml).listVars
BP.keys


BP(\ml).resp.func.inspect
BP(\ml).points[0].listVars

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