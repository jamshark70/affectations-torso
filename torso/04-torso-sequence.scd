// Affectations: Torso controller sequence

(thisProcess.nowExecutingPath.dirname.dirname +/+ "/torso/torso-defs.scd")/*.debug*/.loadPath;

[
	PR(\tlsAff).copy.putAll((
		name: "T2000-low tones",
		segID: 2000,
		initProcesses: {
			if(VC.exists(\tton).not) { Func(\makettoneVC).value(\tton) };
			\chuckIf.eval(Fact(\ttonesBP), BP, \tton, nil);

			BP(\t2000trig).free;
		},
		unloadProcesses: {
			VC(\tton).free; BP(\tton).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					subIterCmd: (
						clock108: TempoClock.default, //thisThread.clock,
						shouldSync: false,
						id: \ttonCmd,
						subIter: TLSequenceIterator([
							// bpCmd: (name: \tton, shouldSync: false, prepareBP: { |bp|
							// 	bp.speedMul.value = 0.1;
							// 	bp.fshift.value = 0;
							// 	bp.distance.value = 17;
							// }),
							{
								var bp = BP(\tton);
								bp.speedMul.value = 0.1;
								bp.fshift.value = 0;
								bp.distance.value = 17;
								bp.prepareForPlay;

								if(topEnvironment[\useVideo]) {
									Fact(\t2000trig) => BP(\t2000trig);
								};
								0
							},
							gcAutoSynthCmd: (gc: { VC(\tton).v.globalControls[\ffreq] },
								name: \ctlEnv, outName: \outbus,
								env: Env(#[800, 7000, 1000], #[0.5, 0.5], \exp),
								time: 140
							),
							10,
							gcAutoSynthCmd: (gc: { BP(\tton).fshift },
								name: \ctlEnv, outName: \outbus,
								env: Env(#[0, 60], #[1], 6),
								time: 60
							),
							30,
							gcAutoSynthCmd: (gc: { BP(\tton).speedMul },
								name: \ctlEnv, outName: \outbus,
								env: Env(#[0.1, 0.7], #[1], \exp),
								time: 45
							)
						])
					),
					\sync,
					{ "T2000-finished sync".debug; 0 }
				],
				// onStop: {
				// 	// BP(\tton).stop(0);
				// 	BP(\t2000trig).free;
				// },
				// dur: \trigger,  // or \sync
				dur: \sync,
				id: 2001  // trig id
				// init: Func(\nextThingTrig).v,
				// clear: Func(\clearNextTrig).v
			), 1)
		}
	)),


	PR(\tlsAff).copy.putAll((
		name: "T2001-dummy wait for solo",
		segID: 2001,
		initProcesses: {
			\chuckIf.eval(Fact(\torsoSolo), BP, \ssd);
		},
		unloadProcesses: { BP(\ssd).free },
		seqPattern: {
			Pn((
				sequence: [
					funcCmd: (
						setDoneSignal: { ~doneSignal = true },
						func: { "waiting for T2010 trigger".debug }
					),
					\sync
				],
				onStop: { BP(\t2000trig).debug("freeing").free },
				dur: \trigger,  // or \sync
				id: 2010,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2010-stephen solo",
		segID: 2010,
		initProcesses: {
			BP(\t2010trig).free;
		},
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ssd, shouldSync: false, prepareBP: {
						if(topEnvironment[\useVideo]) {
							Fact(\t2010trig) => BP(\t2010trig);
						};
					}),
					// [	15,
					funcCmd: (
						dur: 15,
						clearDoneSignal: {
							var cmd = ~iterator.findActive(\ttonCmd);
							if(cmd.notNil) { cmd.stop }
							{ "could not find \\ttonCmd to stop it".warn };
							BP(\tton).stop(0);
							BP(\t2000trig).debug("freeing").free;
							// 0
						}
					),
					// ],
					loopCmd: (
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							funcCmd: (
								doneSignal: true,
								func: {
									var p = BP(\ssd);
									if(p[\savesynthStream].isNil) {
										p.override(
											\synth, Pseq([\amp, Pxrand(#[distance, pan, ffreq], 10)], 1),
											nil,
											{ BP(~collIndex).changed(\wildGestureEnded) }
										);
										p.override(\delta, Pwhite(0.2, 0.8, 11));
										p.override(\sustain, Pseq([6, (Pkey(\delta) * Pwhite(1.5, 3.0, 10))], 1), false, e { ~doneSignal = nil; ~stop.() });
									} { ~doneSignal = nil; ~stop.() };
								}
							),
							\cmdSync
						]
					)
				],
				onStop: e {
					var	cmd;
					if((cmd = ~savedCmds.detect { |cmd| cmd.tryPerform(\id) == \ttonCmd })
						.notNil) {
						cmd.stop;
					};
					BP(\tton).stop(0);  // just in case...
					// BP(\t2000trig).free;
				},
				dur: \trigger,  // or \sync
				id: 2020,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2020-plus Ilana",
		segID: 2020,
		initProcesses: {
			\chuckIf.eval(Fact(\torsoSolo), BP, \ssd2, nil, (
				gcSpecs: (
					distance: #[5, 20],
					center: \freq.asSpec.copy.default_(exprand(100, 140)),
					width: #[0, 80, \lin, 0, 10],
					speed: #[0.05, 20, \exp, 0, 8],
					ffreq: \freq.asSpec.copy.default_(exprand(500, 900)),
					rq: \myrq.asSpec.copy.default_(0.2),
					amp: [0, 10.dbamp, \lin, 0, 0.4],
					pan: \bipolar
				)
			));

			BP(\ssd2).ffreqlevels = Pfunc({
				var	n = rrand(3, 5);
				[{ exprand(600.0, 1000.0) } ! n, { exprand(1800.0, 2100.0) } ! n]
				.lace(n*2).drop(#[-1, 0].choose)
			});
			BP(\ssd2).centerlevels = Ptuple([30, Pexprand(600.0, 2100.0, inf), Pexprand(80.0, 140.0, inf)], inf);
			BP(\ssd2).amplevels = (Ptuple([1, Pwhite(0.6, 0.8, inf), Pwhite(0.18, 0.23, inf)], inf) * 2.5);

			BP(\ssd2).panlevels = Pfunc({
				var	n = rrand(3, 5);
				[{ rrand(-1.0, -0.75) } ! n, { rrand(0.75, 1.0) } ! n]
				.lace(n*2).drop(#[-1, -2].choose).add(0.7.rand2)
				* #[-1, 1].choose
			});

			BP(\ssd2).delta = Pwhite(0.6, 1.8, inf);
			BP(\ssd2).sustain = Pkey(\delta) * Pwhite(0.8, 1.8, inf);

			BP(\t2020trig).free;
		},
		unloadProcesses: { BP(\ssd2).free },
		seqPattern: {
			Pn((
				sequence: [
					bpCmd: (name: \ssd, shouldSync: false, playWarning: false),
					bpCmd: (name: \ssd2, shouldSync: false, prepareBP: {
						if(topEnvironment[\useVideo]) {
							// t2010 may not advance to next segment: that's t2020's job now
							BP(\t2010trig).nextSegCheck = \respond;
							Fact(\t2020trig) => BP(\t2020trig);
						};
					}),
					loopCmd: (
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							funcCmd: (
								doneSignal: true,
								func: {
									var p = BP(\ssd);
									if(BP(\ssd)[\savesynthStream].isNil) {
										BP(#[ssd, ssd2]).do { |p|
											p.override(
												\synth, Pseq([\amp, Pxrand(#[distance, pan, ffreq], 10)], 1),
												nil,
												{ BP(~collIndex).changed(\wildGestureEnded) }
											);
											p.override(\delta, Pwhite(0.2, 0.8, 11));
											p.override(\sustain, Pseq([6, (Pkey(\delta) * Pwhite(1.5, 3.0, 10))], 1), false, e { ~doneSignal = nil; ~stop.() });
										};
									} { ~doneSignal = nil; ~stop.() };
								}
							),
							\cmdSync
						]
					)
				],
				onStop: {
					// BP(#[ssd, ssd2]).stop(0)
					BP(#[t2010trig, t2020trig]).free;
				},
				dur: \trigger,  // or \sync
				id: 2030,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2030-energy-exch",
		segID: 2030,
		initProcesses: {
			topEnvironment[\seq].sections.do { |sect|
				if(sect.segID < 2000) { sect.prUnload };
			};

			\chuckIf.eval(Fact(\torsoDrone), BP, \td);
			\chuckIf.eval(Fact(\nrgThrows), BP, \thr);
			BP(\td).sustain = Pkey(\delta) + Pwhite(5.0, 8.5, inf);
			BP(\td).droneamp = 4.dbamp;
			BP(\td).rq = 0.11;
			BP(\td).fshift = Pwhite(4.0, 12.0, inf);
			BP(\t2030trig).free;
		},
		unloadProcesses: { BP(#[td, thr]).free },
		seqPattern: {
			Pn((
				sequence: [
					{	var bp = BP(\thr);
						bp.delta = Pswitch1([
							Pwhite(1.5, 3.0, inf),
							Pexprand(0.2, 0.9, inf)
						], Pwrand([0, Pn(1, Prand(#[1, 2, 3, 4], inf).asStream)], #[0.7, 0.3], inf));
						bp.sustain = Pexprand(0.7, 2.8, inf);
						bp.throwfLow = Pwhite(200, 400, inf);
						bp.throwfHi = Pwhite(1000, 3000, inf);
						bp.throwampenv = `[Env(#[0, 0.1, 1, 0.1, 0] * 0.5, #[0.3, 0.1, 0.1, 0.5], \sin)];
						bp.amp = 1;
						bp.prepareForPlay;
						if(topEnvironment[\useVideo]) {
							Fact(\t2030trig) => BP(\t2030trig);
						};
						0
					},
					bpCmd: (name: \td, shouldSync: false, prepareBP: { |bp|
						bp.speedMul = Pwhite(0.7, 2.0, inf);
						bp.fshift = Pexprand(4.0, 36.0, inf);
					}),
					[10, { BP(#[ssd, ssd2]).stop(0); 0 }]
				],
				onStop: { BP(\t2030trig).free },
				dur: \trigger,  // or \sync
				id: 2040,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2040-ensemble",
		segID: 2040,
		initProcesses: {
			if(VC.exists(\tmel).not) { \makeTmelVC.eval(\tmel) };
			\chuckIf.eval(Fact(\fastnotesBP), BP, \fastnotes);
			VC(\tmel) => BP(\fastnotes);
			BP(\fastnotes)[\originalDelta] ?? {
				BP(\fastnotes).originalDelta = BP(\fastnotes).changingDelta
			};
			BP(\fastnotes)[\originalRotSynthDef] ?? {
				BP(\fastnotes).originalRotSynthDef = BP(\fastnotes).rotSynthDef;
			};
			BP(\t2040trig).free;
		},
		unloadProcesses: {
			VC(\tmel).free; BP(\fastnotes).free;
		},
		seqPattern: {
			Pn((
				sequence: [
					{
						if(topEnvironment[\useVideo]) {
							Fact(\t2040trig) => BP(\t2040trig);
						};
						0
					},
					bpCmd: (name: \thr, shouldSync: false, playWarning: false),
					bpCmd: (name: \td, shouldSync: false, playWarning: false),
					{	var r = BP(\thr);
						r.delta = Prand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
							Pexprand(0.08, 0.2, { rrand(8, 17) }),
							// Plazy({ Pgeom.fromEndpoints(rrand(0.06, 0.09), rrand(0.18, 0.35), rrand(8, 14).debug("endpts")) }),
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
							})
						], inf) * /*Env(#[4, 1], #[8], -2) **/ r.stretchCtl;
						r.stretchCtl.watch;

						r.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf) /** r.stretchCtl*/);

						r.throwfLow = Prand([
							Plazy({ Pser({ exprand(600, 1400) } ! 2, rrand(2, 4) * 2 + 1) }),
							Plazy({ Pgeom.fromEndpoints(rrand(200, 500), rrand(2000, 4500), rrand(8, 14)) }),
							Pexprand(600, 1800, { rrand(8, 17) })
						], inf);
						r.throwfHi = Pkey(\fLow) * Pwrand([1, Pwhite(0.6, 0.8, 1), Pwhite(1.2, 1.4, 1)], #[0.7, 0.15, 0.15], inf);
						r.throwampenv = Prand([
							[Env.perc(0.9, 0.1, 0.2).asArray],
							[Env.perc(0.1, 0.9, 0.2).asArray]
						], inf);
						r.amp = r.stretchCtl.asPattern.linlin(1, 4, 4.dbamp, 1);
						6
					},
					bpCmd: (name: \fastnotes, shouldSync: false, prepareBP: { |bp|
						bp.useModGCs = false;
						bp.num = 0;
						bp.mod_ratio = Pwhite(2, 7, inf) + Pwhite(0.14, 0.88, inf);
						bp.mod_lev = Pexprand(6, 14, inf);
						bp.finalAmp = VC(\tmel).v.globalControls[\finalAmp].asMap;
						bp.changingDelta = bp.originalDelta * bp.stretchCtl;
						// bp.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf) * bp.stretchCtl);
						bp.rotSynthDef = bp.originalRotSynthDef;
						bp.stretchCtl.watch;
						VC(bp.vcKey).env.modfx.set(\distFar, 20);
					}),
					gcAutoSynthCmd: (gc: { VC(\tmel).v.globalControls[\finalAmp] },
						name: \ctlEnv, outName: \outbus, shouldSync: false,
						env: Env(#[0.001, 0.16, 0.11], #[8, 2], \exp), connect: 0,
						time: 1
					),
				],
				onStop: {
					BP(#[thr, td]).stop(0);
					BP(\t2040trig).free;
				},
				dur: \trigger,  // or \sync
				id: 2050,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2050-Ilana to floor",
		segID: 2050,
		initProcesses: {
			\chuckIf.eval(PR(\tposes), BP, \tp);
			VC(\tmel) => BP(\tp);
			0 => BP(\tp);
			BP(\t2050trig).free;
		},
		unloadProcesses: { BP(\tp).free },
		seqPattern: {
			Pn((
				sequence: [
					{	// Pif stops this stream, which will stop the BP
						BP(\fastnotes).finalAmp = Pif(
							Ptime() <= 3.5,
							Env([VC(\tmel).v.globalControls[\finalAmp].value, 0.001], #[8], -1.7)
						);
						BP(\fastnotes).rotSynthDef = BP(\fastnotes).originalRotSynthDef;

						if(topEnvironment[\useVideo]) {
							Fact(\t2050trig) => BP(\t2050trig);
						};

						if(BP(\tp)[\originalChangingDelta].isNil) {
							BP(\tp).originalChangingDelta = BP(\tp).changingDelta;
						};

						BP(\tp).changingDelta = Pseq([
							12,
							Pwhite(1.0, 3.0, { rrand(3, 6) }),
							// Pwhite(6.0, 10.0, 1)
						], 1);
						BP(\tp).repeats = 1;
						BP(\tp).resetAllSources = true;
						0
					},
					// for slow notes
					gcAutoSynthCmd: (gc: { VC(\tmel).v.globalControls[\finalAmp] },
						name: \ctlEnv, outName: \outbus, shouldSync: false,
						env: Env(#[0.16, 0.16], #[1], \exp), connect: 1,
						time: 6,
						stopAction: { BP(\fastnotes).stretchCtl.stopWatching }
					),
					synthCmd: (
						name: \nrgxch2, target: VC(\tmel).env.target,
						outbus: [VC(\tmel).env.sideBus, BP(\ssd).noisebuf, 10, 4],
						amp: 16.dbamp, moveTime: 24,
						fenv: Env([100, 100, 71.midicps] * 2, #[0.12, 0.3], \exp),
						rqenv: Env(0.1 ! 2, #[1]),
						ampenv: Env.linen(0.05, 0.75, 0.2),
						ctrenv: Env([100, 100, 71.midicps], #[0.12, 0.3], \exp)
					),
					bpCmd: (name: \tp, prepareBP: { |bp|
						bp.controlsVCPos = true;
						bp.reset;
						bp.v.reset;  // it seems this func sometimes doesn't get called
					}),
					\cmdSync,
					loopCmd: (
						cmds: [
							funcCmd: topEnvironment[\trigParms],
							\cmdSync,
							{ BP(\tp).resetAllSources = false; 0 },
							bpCmd: (name: \tp, prepareBP: { |bp|
								bp.changingDelta = Pseq([
									Pwhite(1.0, 3.0, { rrand(3, 6) }),
									Pwhite(6.0, 10.0, 1)
								], 1);
							}),
							\cmdSync
						]
					)
				],
				onStop: { BP(\t2050trig).free },
				dur: \trigger,  // or \sync
				id: 2060,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2060-Fast ensemble",
		segID: 2060,
		initProcesses: { BP(\t2060trig).free },
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	var bp = BP(\fastnotes);

						if(topEnvironment[\useVideo]) {
							Fact(\t2060trig) => BP(\t2060trig);
						};

						// NOW DAMMIT DON'T GET CONFUSED ABOUT THIS AGAIN
						// THIS PART IS FOR FASTNOTES

						bp.useModGCs = false;
						bp.num = Pwrand(#[1, 2, 3], #[0.7, 0.2, 0.1], inf);
						bp.mod_ratio = blend(Pwhite(2, 7, inf) + Pwhite(0.14, 0.88, inf),
							3, Pseg(Pseq([0, 1], inf), Pwhite(2.0, 4.0, inf), \sine));
						bp.mod_lev = Pseg(Ppatlace([Pexprand(6, 14, inf), 1.6], inf),
							Pwhite(2.0, 4.0, inf), \sine);
						bp.changingDelta = Prand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
							Pexprand(0.08, 0.2, { rrand(8, 17) }),
							// Plazy({ Pgeom.fromEndpoints(rrand(0.06, 0.09), rrand(0.18, 0.35), rrand(8, 14).debug("endpts")) }),
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
							})
						], inf) * BP(\t2060trig).stretchCtl;
						bp.delta = bp.changingDelta;
						bp.rotSynthDef = bp.originalRotSynthDef;
						bp.finalAmp = Env(#[0.8, 0.6], #[15]);  // originally 0.16
						VC(bp.vcKey).env.modfx.set(\distFar, 20);


						// AND THIS PART IS FOR THR
						// DON'T PUT FASTNOTES PARMS BELOW HERE FOR F*CKS SAKE!!!!!

						bp = BP(\thr);
						bp.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf));

						bp.delta = Prand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1),
							Pexprand(0.08, 0.2, { rrand(8, 17) }),
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)).collect { |x| curve.envAt(x) }
							})
						], inf) * Env(#[4, 1], #[8], -2) * BP(\t2060trig).stretchCtl;

						bp.sustain = max(0.08, Pkey(\delta) * Pwhite(0.25, 0.6, inf));

						bp.throwfLow = Prand([
							Plazy({ Pser({ exprand(600, 1400) } ! 2, rrand(2, 4) * 2 + 1) }),
							Plazy({ Pgeom.fromEndpoints(rrand(200, 500), rrand(2000, 4500), rrand(8, 14)) }),
							Pexprand(600, 1800, { rrand(8, 17) })
						], inf);
						bp.throwfHi = Pkey(\fLow) * Pwrand([1, Pwhite(0.6, 0.8, 1), Pwhite(1.2, 1.4, 1)], #[0.7, 0.15, 0.15], inf);
						bp.throwampenv = Prand([
							[Env.perc(0.9, 0.1, 0.5).asArray],
							[Env.perc(0.1, 0.9, 0.5).asArray]
						], inf);

						0
					},
					loopCmd: (
						// proc: Pseq(#[fastnotes, thr], inf).asStream,
						cmds: [
							{	var dur = exprand(2.0, 3.5);
								// [thisThread.clock.beats, dur, thisThread.clock.beats + dur].debug("fastnotes");
								TLSequenceIterator([
									{ BP(\fastnotes).stop(0); 0.02 },
									bpCmd: (name: \fastnotes, shouldSync: false, dur: dur,
										prepareBP: { |bp|
											bp.finalAmp = Env([0.16, 0.01], [dur], 1);
										}
									),
									dur * rrand(0.45, 0.65)
									// funcCmd: topEnvironment[\trigParms],
									// \cmdSync
								], autoSync: false)
							},
							\sync,
							{	var dur = exprand(2.0, 3.5);
								// [thisThread.clock.beats, dur, thisThread.clock.beats + dur].debug("thr");
								TLSequenceIterator([
									{ BP(\thr).stop(0); 0.02 },
									bpCmd: (name: \thr, shouldSync: false, dur: dur,
										prepareBP: { |bp|
											bp.amp = Env([1, 0.01], [dur], 1);
										}
									),
									dur * rrand(0.45, 0.65)
									// funcCmd: topEnvironment[\trigParms],
									// \cmdSync
								], autoSync: false)
							},
							\sync
						]
					)
				],
				onStop: { BP(\t2060trig).free },
				dur: \trigger,  // or \sync
				id: 2070,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2070-Slow down",
		segID: 2070,
		initProcesses: { BP(\t2070trig).free },
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{	var	p = BP(\fastnotes), stretchBlend;

						if(topEnvironment[\useVideo]) { \makeT2070trig.eval };
						stretchBlend = blend(
							BP(\t2070trig).stretchCtl.asPattern,
							1,
							Env(#[1, 0], #[7])
						);

						p.stop(0);
						p.slowFactor = Env(#[1, 6], #[16], \exp).asStream;
						p.changingDelta = Pwrand([
							Pstutter(inf, Pexprand(0.08, 0.14, 1)) * Pseq([Pn(1, { rrand(3, 7) }), 3], 1) * p.slowFactor,
							Pexprand(0.08, 0.2, { rrand(8, 17) }) * p.slowFactor,
							Plazy({
								var	curve = Env([rrand(0.06, 0.09), rrand(0.18, 0.35)], #[1], 5).asArray;
								(Pseries.fromEndpoints(0.0, 1.0, rrand(8, 14)) * p.slowFactor).collect { |x| curve.envAt(x) }
							}),
							Pstutter(2, Pwhite(0.125, 0.18, 1))   // NOT slowed!
						], #[0.2, 0.2, 0.2, 0.4], inf) * stretchBlend;
						p.delta = p.changingDelta;

						p.sustain = Pkey(\delta) * Pif(Pkey(\delta) > 0.18, Pwhite(0.9, 1.2, inf), 0.5);
						p.finalAmp = 0.1;

						p.mod_ratio = Pwrand(#[2, 3, 4, 5], #[0.1, 0.5, 0.2, 0.2], inf) + Pwrand([0, Pwhite(0.2, 0.8, { rrand(1, 4) })], #[0.9, 0.1], inf);
						p.mod_lev = Pif(Pbinop('==', Pkey(\mod_ratio) % 1, 0), Pexprand(1.6, 5.0, inf), Pwhite(7.5, 15.0, inf));

						p.num = Pwrand(#[2, 3, 4], #[0.15, 0.45, 0.4], inf);
						p.freq2 = Pkey(\freq) * Pif(0.12.asPattern.coin, Pwhite(0.6, 0.8, inf), 1);
						p.freq = Pvbrown(39, 52, Pwhite(3, 6, inf), inf) - Pfunc({ |ev|
							var	n;
							~numStream ?? { ~makeStreamForKey.(\num) };
							n = ~numStream.next(ev);
							(#[0] ++ ({ #[1, 2, 3].wchoose(#[0.2, 0.45, 0.35]) } ! (n-1))).integrate
						});

						p.attackTimeScale = Pif(Pkey(\delta) > 0.18, Pwhite(0.6, 1.2, inf), 0.05);
						p.decayTimeScale = Pif(Pbinop('==', Pkey(\freq), Pkey(\freq2)),
							Pif(Pkey(\delta) > 0.18, 1.0, 0.05),
							(Pkey(\freqlag) - Pkey(\sustain) + Pwhite(0.8, 1.2, inf))
						);
						// HACK HACK hack hack hack
						"replacing rotsynth".debug;
						p[\rotSynth].free;
						VC(p.vcKey).env.modfx.set(\distFar, 45);
						p.rotSynth = SynthDef(\rotateGoBack, { |outbus|
							Out.kr(outbus, [
								LFDNoise1.kr(LFDNoise1.kr(0.4).range(0.1, 0.8)),
								Line.kr(5, 45, 25),
								LFDNoise1.kr(0.07).exprange(0.001, 8)
							]);
						}).play(VC(p.vcKey).env.target.fadergroup, [outbus: p.ctlBus], addAction: \addToHead);

						0.02
					},
					bpCmd: (name: \fastnotes, shouldSync: false),
					{ rrand(8.0, 14.0) },
					bpCmd: (name: \thr, shouldSync: false, prepareBP: { |bp|
						bp.sustain = Pwhite(8.0, 15.0, inf);
						bp.delta = Pwhite(7.0, 14.0, inf) * BP(\t2070trig).stretchCtl;
						bp.throwfLow = Pexprand(100, 170, inf);
						bp.throwfHi = Pkey(\fLow);
						bp.throwampenv = [Env.perc(0.01, 0.99, 0.4).asArray];
						bp.amp = 14.dbamp;
					}),
				],
				onStop: { BP(\t2070trig).free },
				dur: \trigger,  // or \sync
				id: 2080,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2080-Ilana up",
		segID: 2080,
		initProcesses: { BP(\t2080trig).free },
		// unloadProcesses: {},
		seqPattern: {
			Pn((
				sequence: [
					{
						if(topEnvironment[\useVideo]) {
							Fact(\t2080trig) => BP(\t2080trig);
						};
						0
					},
					[	6.0,
						{ BP(#[fastnotes, thr]).stop(0); 0 }
					],
					synthCmd: (
						name: \nrgxch2, target: VC(\tmel).env.target,
						outbus: [VC(\tmel).env.sideBus, BP(\ssd).noisebuf, 10, 4],
						amp: 16.dbamp, moveTime: 24,
						fenv: Env([100, 100, 71.midicps] * 2, #[0.12, 0.3], \exp),
						rqenv: Env(0.1 ! 2, #[1]),
						ampenv: Env.linen(0.05, 0.75, 0.2),
						ctrenv: Env([100, 100, 71.midicps], #[0.12, 0.3], \exp)
					),
					// should stop after 1 event
					bpCmd: (name: \tp, dur: 10, prepareBP: { |bp|
						bp.changingDelta = Pn(12, 1);
						bp.resetAllSources = true;
						bp.controlsVCPos = false;
						bp.reset;
						bp.v.reset;
					}),
					8.0,
					bpCmd: (name: \ssd2, shouldSync: false)
				],
				onStop: { BP(\t2080trig).free },
				dur: \trigger,  // or \sync
				id: 2090,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2090-Ilana solo",
		segID: 2090,
		master: topEnvironment[\master],
		glrvbmc: topEnvironment[\cRvbMc],
		lcrvbmc: topEnvironment[\lcrvbmc],
		initProcesses: {
			\chuckIf.eval(Fact(\bells), BP, \bel, nil, Library.at(\rvbs).copy.put(\glrvbmc, topEnvironment[\cRvbMc]));
			\chuckIf.eval(Fact(\bellfx), BP, \belfx, nil, (
				parentChan: BP(\bel).chan
			));
			BP(\t2090trig).free;
		},
		unloadProcesses: { BP(#[bel, belfx]).free },
		seqPattern: {
			Pn((
				sequence: [
					[	6.0,
						{ BP(\ssd2).stop(0); 0 }
					],
					{	var bp = BP(\bel);
						bp.delta = Pwhite(12.0, 18.0, inf);
						bp.prepareForPlay;
						if(topEnvironment[\useVideo]) {
							Fact(\t2090trig) => BP(\t2090trig);
						};
						0
					},
					loopCmd: (
						repeats: 2,
						cmds: [
							{	BP(\bel).triggerOneEvent(0);
								4 // rrand(11.0, 16.0)
							},
							funcCmd: topEnvironment[\trigParms]
						]
					),
					\cmdSync,

					{
						BP(\bel).delta = Pseq([
							Plazy({
								var	last = rrand(0.9, 1.2);
								Pgeom.fromEndpoints(
									rrand(1.8, 2.6), last,
									rrand(4, 9)
								) ++ Pn(last * 0.5, 1)
							}),
							Pwhite(10.0, 16.0, 1)
						], 1);
						0
					},
					loopCmd: (
						shouldSync: false,
						cmds: [
							{
								if(BP(\bel).continue ? true) {
									PR(\bpCmd).copy.putAll((
										name: \bel, // shouldSync: false,
										prepareBP: { |bp| bp.makeStreamForKey(\delta) }
									))
								} { nil }  // nil should stop the loop
							},
							\cmdSync,
							{
								if(BP(\bel).continue ? true) {
									PR(\funcCmd).copy.putAll(topEnvironment[\trigParms])
								} { nil }
							},
							\cmdSync
						],
					),
					8,
					bpCmd: (name: \belfx, shouldSync: false,
						setDoneSignal: {
							~doneSignal = Updater(BP(\bel), { |obj, what, more|
								if(more == \stopped) {
									BP(\belfx).clock.sched(8, { BP(\belfx).stop(0) });
								};
							});
						},
						clearDoneSignal: { ~doneSignal.remove }
					)
				],
				onStop: { BP(\t2090trig).free },
				dur: \trigger,  // or \sync
				id: 2100,  // trig id
				init: Func(\nextThingTrig).v,
				clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	PR(\tlsAff).copy.putAll((
		name: "T2100-Duet",
		segID: 2100,
		initProcesses: {
			Library.at(\rvbs).keysValuesDo { |key, val| key.envirPut(val) };
			~cRvbMc = topEnvironment[\cRvbMc];
			\chuckIf.eval(Fact(\wtpadnofx), VC, \wp);
			\chuckIf.eval(Fact(\waterch), BP, \wch);
			VC(\wp) => BP(\wch);
			\chuckIf.eval(Fact(\bellfx), BP, \wfx, nil, (
				parentChan: VC(\wp).env.target
			));
			\chuckIf.eval(Fact(\armsmelVC), VC, \am, nil, Library.at(\rvbs));
			\chuckIf.eval(Fact(\duetMelBP), BP, \duetm);
			VC(\tmel) => BP(\duetm);

			BP(\t2100trig).free;
		},
		unloadProcesses: { VC(\wp).free; BP(#[wch, wfx]).free },
		seqPattern: {
			Pn((
				sequence: [
					{
						BP(\bel).continue = false;
						if(topEnvironment[\useVideo]) {
							Fact(\t2100trig) => BP(\t2100trig);
						};
						BP(\wch).child.argPairs = [fenv_tscale: Pkey(\length)];
						BP(\wch).prepareForPlay;
						BP(\wch).reset;
						0
					},
					loopCmd: (
						id: \chordloop,
						cmds: [
							{
								BP(\wch).triggerOneEvent(0);
								4
							},
							funcCmd: topEnvironment[\trigParms].copy.put(\eventID, 2),
							\cmdSync,
						]
					),
					18,
					bpCmd: (name: \wfx),
					bpCmd: (name: \duetm),

					// separate event trigger for walking away
					// t2100trig will call this event by ID
					funcCmd: topEnvironment[\trigParms].copy.put(\eventID, 100),
					\cmdSync,

					gcAutoSynthCmd: (
						gc: { VC(\wp).globalControls[\fenv_sens] },
						name: \ctlPoint, outName: \outbus,
						value: 0.8, time: 2
					),
					funcCmd: (func: {
						var loop = ~iterator.findActive(\chordloop);
						if(loop.notNil) { loop.stop } { "couldn't stop chordloop cmd (not found)".warn };
					}),
					[
						{
							// how long until wch would have played on its own?
							// time of its last event + lastEvent.delta
							BP(\wch)[\eventSchedTime] + BP(\wch).lastEvent.delta - BP(\wch).clock.beats
						},
						bpCmd: (name: \wch)
					],
					mixerAutoSynthCmd: (
						mixer: topEnvironment[\master],
						name: \ctlPoint, outName: \outbus,
						value: 0, time: 30, curve: -2
					),
					\cmdSync,
					{
						BP.all.stop;  // is this safe?
						0
					}
				],
				onStop: { BP(\t2100trig).free },
				dur: \sync  // no trigger for next section; just stop when iterator is done
				// id: 2110,  // trig id
				// init: Func(\nextThingTrig).v,
				// clear: Func(\clearNextTrig).v
			), 1)
		}
	)),

	// PR(\tlsAff).copy.putAll((
	// 	name: "",
	// 	segID: 0,
	// 	initProcesses: {},
	// 	unloadProcesses: {},
	// 	seqPattern: {
	// 		Pn((
	// 			sequence: [
	// 			],
	// 			// onStop: {},
	// 			dur: \trigger,  // or \sync
	// 			id: 0,  // trig id
	// 			init: Func(\nextThingTrig).v,
	// 			clear: Func(\clearNextTrig).v
	// 		), 1)
	// 	}
	// )),

]