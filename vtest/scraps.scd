PR(\regressionUnit).v.clone({
	~proxthresh = 10;

	~prep = { |x_origin = 0, y_origin = 0, proximatePoints|
		~x = 0 ! ~num;
		~y = 0 ! ~num;
		~mag = 0 ! ~num;
		~x_origin = x_origin;
		~y_origin = y_origin;
		~proxPts = proximatePoints;
		currentEnvironment
	};

	~predict = {
		var	distances = ~proxPts.collect { |pt, i|
			hypot(~x.last + ~x_origin - (pt.x.last + pt.x_origin),
				~y.last + ~y_origin - (pt.y.last + pt.y_origin))
		},
		i = distances.minIndex,
		pt;
		~proxHit = if(distances[i] <= ~proxthresh) {
			pt = ~proxPts[i];
			Point(pt.x.last + pt.x_origin, pt.y.last + pt.y_origin)
		} { nil };
	};

	~plot = {
		var	mag = ~magspec.map(~mag.last / ~maxmag) * 0.5,
			pt1 = Point(~x.last + ~x_origin, ~y.last + ~y_origin),
			proxpt,
		pt2;
		Pen.color_(~color).width_(1)
		.fillOval(Rect.aboutPoint(pt1, mag, mag));
		// draw line for proximity?
		if(~proxHit.notNil) {
			Pen.width_(3)
			.line(pt1, ~proxHit)
			.stroke;
		};
	};
}/*, parentKeys*/) => PR(\proximityUnit);


PR(\motionListener).clone({
	~prep = {
		var	i = 0, proxpts;
		~points = Array(~dim.squared);
		~dim.do { |xi|
			~dim.do { |yi|
				~points.add(PR(\proximityUnit).copy.prep(xi * 64, yi * 48));
			};
		};
		~dim.do { |xi|
			~dim.do { |yi|
				proxpts = Array.new;
				#[-1, 0, 0, -1, 1, 0, 0, 1].pairsDo { |xinc, yinc|
					if(inclusivelyBetween(xi + xinc, 0, ~dim-1)
						and: { inclusivelyBetween(yi + yinc, 0, ~dim-1) }) {
							proxpts = proxpts.add(~points[(xi + xinc) * ~dim + (yi + yinc)]);
						};
				};
				~points[i].proxPts = proxpts;
				i = i + 1;
			};
		};		
		~makeResponder.();
		currentEnvironment
	};
}) => PR(\proxListener);



		// median filter on angles
		theta = (~centroid - ~prevCentroid).theta;
		theta = (theta - ~prevTheta).wrap(-pi, pi) + ~prevTheta;
[~centroid - ~prevCentroid, theta].debug("\ncentroid diff, theta");
		// don't do this for large array sizes!
		~anglebufSort.remove(~anglebuf[~anglebufIndex]);
		~anglebuf[~anglebufIndex] = theta;
		insertIndex = ~anglebufSort.detectIndex { |item| item > theta };
		if(insertIndex.isNil) {
			~anglebufSort = ~anglebufSort.add(theta);
		} {
			~anglebufSort = ~anglebufSort.insert(insertIndex, theta);
		};
~anglebufSort.round(0.01).debug("sorted");
~anglebufSort.sortedMedian.debug("median");
		~anglebufIndex = (~anglebufIndex + 1) % ~anglebufSize;
		~anglePoint = Polar(~magsum, ~anglebufSort.sortedMedian).asPoint;
~anglePoint.theta.debug("~anglePoint.theta");

		~prevTheta = theta;
		~prevCentroid = ~centroid;
