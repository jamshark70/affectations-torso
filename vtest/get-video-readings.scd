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
g = HrVideoAngleGui(l, pdAddr: NetAddr("127.0.0.1", 57122));

ShutDown.add { motionGui.pdAddr.sendMsg('/quitPd') };
)

u.remove; u = SimpleController(l);

c.free; c = GenericGlobalControl(\test, nil, 0, [0, 1]);
c => VP(0);
c.gui;
// c.spec = [0, 1].asSpec;

l = Library.at(\motionListener);

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