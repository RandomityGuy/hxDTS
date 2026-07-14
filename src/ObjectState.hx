package;

import io.BytesReader;

@:expose
@:publicFields
class ObjectState {
	var vis:Float;
	var frame:Int;
	var matFrame:Int;

	public function new() {}

	public static function read(reader:DtsAlloc) {
		var os = new ObjectState();
		os.vis = reader.readF32();
		os.frame = reader.readU32();
		os.matFrame = reader.readU32();
		return os;
	}

	public function write(alloc:DtsWriteAlloc) {
		alloc.writeF32(vis);
		alloc.writeU32(frame);
		alloc.writeU32(matFrame);
	}
}
