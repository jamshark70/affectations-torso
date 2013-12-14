+ Function {
	tryNoTrace { arg handler;
		var result = this.prTryNoTrace;
		if (result.isException) { ^handler.value(result); }
			{ ^result }
	}
	prTryNoTrace {
		var result, thread = thisThread;
		var next = thread.exceptionHandler,
			wasInProtectedFunc = Exception.inProtectedFunction;
		thread.exceptionHandler = {|error|
			thread.exceptionHandler = next; // pop
			^error
		};
		Exception.inProtectedFunction = false;
		result = this.value;
		Exception.inProtectedFunction = wasInProtectedFunc;
		thread.exceptionHandler = next; // pop
		^result
	}
}