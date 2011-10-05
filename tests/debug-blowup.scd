
// ~master = MixerChannel(\master, s, 2, 2);

(
z = PeakMonitor(~master);

u.remove;
u = Updater(z, { |obj|
	var i = 2;
	if(z.peaks.any(_ > 1)) {
		u.remove;
		s.volume.mute;
		topEnvironment[\seq].stop;
		// OSCFunc({ |msg|
		// 	topEnvironment[\scanTree].value(2, msg);
		// }, '/g_queryTree.reply', s.addr).oneShot;
		// s.sendMsg(\g_queryTree, 1, 0);
	};
});
)



// assumes 'i' points to a node ID; see Server Command Reference
~scanTree = { |i, msg|
//	var parent = msg[i];
	var	child;
	block { |break|
		msg[i+1].do {
			i = i + 2;  // advance to child
			child = msg[i];
			if(child.isNil) { break.() };
			if(msg[i+1] >= 0) {
				// it's a group: recursion
				i = ~scanTree.(i, msg);
			} {
				// it's a synth: trace
				s.sendMsg(\n_trace, child);
				// i = i + 2;  // skip synthdef name
			};
		};
	};
	i
};


OSCFunc({ |msg| msg.postcs }, '/g_queryTree.reply', s.addr).oneShot;

s.sendMsg(\g_queryTree, 1, 0);


"\n\n\n\n".postln

OSCFunc({ |msg| ~scanTree.(2, msg) }, '/g_queryTree.reply', s.addr).oneShot;

s.sendMsg(\g_queryTree, 1, 0);


~master.free;
