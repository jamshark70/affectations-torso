+ Synth {
	getControl { |index|
		var	condition, value;
		if(thisThread.isKindOf(Routine)) {
			condition = Condition.new;
			this.get(index, { |v| value = v; condition.unhang });
			condition.hang;
			^value
		} {
			MethodError("Getting values from a server is asynchronous. This method must be used only in a Routine.", this).throw;
		};
	}
}
