
// resettable watch for performance
// h. james harkins -- http://www.dewdrop-world.net

// just a rough draft for now, need to allow customized appearance

DDWTimer {
	var	<interval = 1,
		<now = 0,
		routine,
		clock, view, timeview, resetbutton,
		masterLayout;
	
	var	notResetting = true;
	
	*new { |layout, resize = true|
		^super.new.init(layout, resize)
	}
	
	init { |layout, resize|
		if(layout.isNil) {
			layout = masterLayout = ResizeFlowWindow("DDWTimer", Rect(20, 20, 190, 60));
			view = masterLayout.view;
		} {
			view = FlowView.new(layout, Rect(20, 20, 190, 60))
		};

		view.onClose_({ this.stop; });
		
		resetbutton = GUI.button.new(view, 50@50)
			.states_([["reset", Color.black, Color.gray]])
			.action_({ this.reset });
		
		timeview = GUI.staticText.new(view, 120@50)
			.font_(
				if(Font.default.notNil) {
					Font.default.copy.size_(24).tryPerform(\boldVariant)
				} {
					Font("Helvetica Bold", 24)
				}
			)
			.align_(\right)
			.background_(Color.white);
//			.keyDownAction_({ nil });	// swallow user input
		
		clock = TempoClock(1);
		
		this.reset.start;
		
		if(resize) {
			if(masterLayout.notNil) { masterLayout.recursiveResize }
				{ view.recursiveResize }
		};
		
		if(masterLayout.notNil) { masterLayout.front };
		
//		clock.sched(0, { clock.setMeterAtBeat(60, 0) });
		
//		clock.addDependant(this);	// need to know when gui closes
	}
	
	start {
		routine = Routine({
			loop {
				notResetting.if({ now = now + interval }, { notResetting = true });
				{ if(timeview.notClosed) { timeview.string_(this.timeString) } }.defer;
				interval.wait;
			}
		});
		clock.play(routine, 1);
	}
	
	stop {
		routine.stop;
		clock.stop;
		this.removeViews;
	}
	
	reset {
//		clock.play({ now = 0; nil }, 1);
		now = 0;
		notResetting = false;		// upon reset, routine should not increment
	}	
	
//	update { |changed, changer, whichgui|
//		(changer == \guiClosed and: { whichgui == gui }).if({
//			this.stop;
//		});
//	}
//	
	timeString {
		var	min = now div: 60,
			sec = now % 60,
			tenths = ((now - now.trunc) * 10).round;
		^"%:%%.%".format(
			min,
			(sec < 10).if({ "0" }, { "" }),
			sec,
			tenths
		)
	}
	
		// later
	removeViews {
		if(masterLayout.notNil) {
			view.onClose = nil;
			masterLayout.close;
		}
	}
}
