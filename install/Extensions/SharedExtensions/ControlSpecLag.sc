
ControlSpecLag : ControlSpec {
	var	<>lag;

	*new { |minval=0.0, maxval=1.0, warp='lin', step=0.0, default, units, lag = 0.1|
		^super.new(minval, maxval, warp, step, default ? minval, units ? "")
			.lag_(lag)
	}
	
	defaultControl { arg val;
		^KrNumberEditor.new(this.constrain(val ? this.default),this).lag_(lag);
	}
}
