
//+ FxPatch {
//	*new { arg name,inputs,outClass;
//		var	new = super.new.loadSubject(name);
//		inputs.do({ |in, i|
//			if(in.respondsTo(\spec_) and: { in.tryPerform(\spec).isNil }) {
//				in.spec = new.instr.specs[i].asSpec;
//			}
//		});
//		^new.createArgs(loadDocument(inputs) ? []).outClass_(outClass ? Out)
//	}
//}

+ SequenceableCollection {
	fixArgsForInstr { |instr|
		instr = instr.asInstr;
		this.do({ |in, i|
			if(in.isKindOf(Ref)) {
				this[i] = KrNumberEditor(in.dereference, instr.specs[i].asSpec);
			};
//			if(in.respondsTo(\spec_) and: { in.tryPerform(\spec).isNil }) {
//				in.spec = instr.specs[i].asSpec;
//			};
		});
	}
}