package;

import io.BytesReader;

@:expose
@:publicFields
class Trigger {
	var state:Int;
	var position:Float;

	public function new() {}

	public static function read(reader:DtsAlloc) {
		var t = new Trigger();
		t.state = reader.readU32();
		t.position = reader.readU32();
		return t;
	}

	public function write(alloc:DtsWriteAlloc) {
		alloc.writeU32(state);
		alloc.writeU32(Std.int(position)); // read as a raw int32, so written back as one
	}
}
