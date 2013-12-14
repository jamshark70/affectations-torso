+ File {
	*fixWindowsText {
		GUI.dialog.getPaths({ |path|
			path.do({ |path|
				var	file = File(path, "r"),
					bakPath, outFile, char;

				if(file.isOpen) {
					file.close;
					bakPath = path ++ ".bak";
					"rm %".format(bakPath.escapeChar($ )).systemCmd;
					if("mv % %".format(path.escapeChar($ ), bakPath.escapeChar($ ))
					.systemCmd != 0) {
						Error("Could not back up original file. Aborting.").throw;
					};
					file = File(bakPath, "r");
					outFile = File(path, "w");
					protect {
						outFile.isOpen.if({
							while { (char = file.getChar).notNil } {
								if(char.ascii != 13) { outFile.putChar(char) };
							};
							"Wrote output file %.\nOriginal is backed up as %.\n".postf(path, bakPath);
						}, {
							"Output file % could not be opened. Skipped."
								.format(path.fileName).warn;
						});
					} { outFile.close; file.close };
				} {
					"Input file % could not be opened. Skipped.".format(path).warn;
				};
			});
			"done".postln;
		}, maxSize: 100);
	}
}
