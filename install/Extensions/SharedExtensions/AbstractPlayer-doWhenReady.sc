
+ AbstractPlayer {
	doWhenPlaying { |func, retryTime = 0.05, timeout = 2.0, clock|
//		"doWhenReady function registered for %.\n".postf(this.asString);
		^Routine({
			var	elapsed = 0;
			loop {
				retryTime.yield;
				this.isPlaying.if({
					func.value(this);
//					"doWhenReady function done for %.\n".postf(this.asString);
					nil.yield;	// stop the routine
				});
				((elapsed = elapsed + retryTime) > timeout).if({
					"doWhenPlaying function timed out for %.\n".format(this.asString).warn;
					nil.yield;
				});
			};
		}).play(clock ? AppClock)
	}

	play { arg group,atTime,bus,callback;
		var timeOfRequest;
		if(this.isPlaying,{ ^this });
		timeOfRequest = Main.elapsedTime;
		if(bus.notNil,{ 
			bus = bus.asBus;
			if(group.isNil,{
				server = bus.server;
				this.group = server.asGroup;
			},{	
				this.group = group.asGroup;
				server = this.group.server;
			})
		},{
			this.group = group.asGroup;
			server = this.group.server;
			// leave bus nil
		});
		if(server.serverRunning.not,{
			server.startAliveThread(0.1,0.4);
			server.waitForBoot({
				if(server.dumpMode != 0,{ 
					server.stopAliveThread;
				});
				InstrSynthDef.clearCache(server);
				if(server.isLocal,{
					InstrSynthDef.loadCacheFromDir(server);
				});
				//"prPlay->".debug;
				this.prPlay(atTime,bus,timeOfRequest,callback);
				nil
			});
		},{
			this.prPlay(atTime,bus,timeOfRequest,callback)
		});
		
		CmdPeriod.add(this);
		// this gets removed in stopToBundle
		/*Library.put(AbstractPlayer,\serverDeathWatcher, 
			Updater(server,{ arg s, message;
				if(message == \serverRunning and: {s.serverRunning.not},{
					AppClock.sched(5.0,{ // don't panic to quickly
						if(s.serverRunning.not,{
							"Server dead ?".inform;
							//this.cmdPeriod; // stop everything, she's dead
						})
					})
				});
			})
		);*/
	}
	
	prPlay { arg atTime,bus,timeOfRequest,callback;
		var bundle;
		bundle = MixedBundle.new;
		if(status !== \readyForPlay,{ this.prepareToBundle(group, bundle, false, bus) });
		this.makePatchOut(group,false,bus,bundle);
		this.spawnToBundle(bundle);
		callback !? { bundle.addFunction(callback) };
		bundle.sendAtTime(this.server,atTime,timeOfRequest);
	}
}
