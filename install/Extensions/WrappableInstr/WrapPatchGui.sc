
// yet again, I have to copy/paste huge amounts of code from crucial b/c his is not sufficiently modular

WrapPatchGui : PatchGui {
	guiBody { arg layout;
		var bounds, maxHeight,vl;
		bounds = layout.bounds;
		maxHeight = bounds.height - 20 - (model.args.size * 15) / model.args.size;

		this.instrGui(layout);		

		//vl = SCVLayoutView(layout.startRow,layout.decorator.indentedRemaining);
		vl = layout;
		model.args.do({ arg a,i;
			var gui,disclosed=true,box;
			layout.startRow;
			//ArgNameLabel(model.instr.argNames.at(i),layout);
			GUI.dragSink.new(vl,Rect(0,0,100,15))
				.background_(Color( 0.47843137254902, 0.72941176470588, 0.50196078431373 ))
				.font_(GUI.font.new("Helvetica",10))
				.align_(\left)
				.canReceiveDragHandler_({  
					model.instr.specs.at(i).canAccept(GUI.view.currentDrag);
				})
				.object_(model.argNameAt(i))
				.action_({ arg sink;
					// assumes to copy the object
					model.setInput(i,sink.object.copy);
					sink.object = model.instr.argNames.at(i); // don't change the name
					if(gui.notNil,{
						gui.remove(true);
						// expand the box
						//layout.bounds = layout.bounds.resizeTo(1000,1000);
						box.bounds = box.bounds.resizeTo(900,900);
						gui = model.args.at(i).gui(box);
						box.resizeToFit(true,true);
						//layout.reflowAll;
					});
				});

			box = vl.flow({ arg layout;
				if(a.tryPerform('path').notNil,{
					Tile(a,layout);
				},{
					gui = a.gui(layout);
				});
			})
		});
	}
}