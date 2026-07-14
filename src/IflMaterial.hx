package;

import io.BytesReader;

@:expose
@:publicFields
class IflMaterial {
	var name:Int;
	var slot:Int;
	var firstFrame:Int;
	var time:Int;
	var numFrames:Int;

	public function new() {}

	public static function read(reader:DtsAlloc) {
		var ifl = new IflMaterial();
		ifl.name = reader.readU32();
		ifl.slot = reader.readU32();
		ifl.firstFrame = reader.readU32();
		ifl.time = reader.readU32();
		ifl.numFrames = reader.readU32();
		return ifl;
	}

	public function write(alloc:DtsWriteAlloc) {
		alloc.writeU32(name);
		alloc.writeU32(slot);
		alloc.writeU32(firstFrame);
		alloc.writeU32(time);
		alloc.writeU32(numFrames);
	}
}
