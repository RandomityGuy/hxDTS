package;

@:expose
@:publicFields
class Detail {
	var name:Int;
	var subShape:Int;
	var objectDetail:Int;
	var size:Float;
	var avgError:Float;
	var maxError:Float;
	var polyCount:Int;

	public function new() {}

	public static function read(reader:DtsAlloc) {
		var d = new Detail();
		d.name = reader.readU32();
		d.subShape = reader.readU32();
		d.objectDetail = reader.readU32();
		d.size = reader.readF32();
		d.avgError = reader.readF32();
		d.maxError = reader.readF32();
		d.polyCount = reader.readU32();
		return d;
	}

	public function write(alloc:DtsWriteAlloc) {
		alloc.writeU32(name);
		alloc.writeU32(subShape);
		alloc.writeU32(objectDetail);
		alloc.writeF32(size);
		alloc.writeF32(avgError);
		alloc.writeF32(maxError);
		alloc.writeU32(polyCount);
	}
}
