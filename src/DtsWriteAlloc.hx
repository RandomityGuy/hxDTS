package;

import haxe.io.Bytes;
import io.BytesWriter;
import math.QuatF;
import math.Box3F;
import math.Point3F;
import math.Point2F;

// Write-side counterpart to DtsAlloc. Accumulates the three interleaved
// (32/16/8) buffers plus the guard sequence, then flushes them into the file
// header layout. Quaternions live in the 16-bit buffer as raw int16s (see
// DtsAlloc.readQuat16), so writeQuat16 emits them verbatim.
@:expose
class DtsWriteAlloc {
	public var buffer32:BytesWriter;
	public var buffer16:BytesWriter;
	public var buffer8:BytesWriter;

	public var sequence:Int = 0;

	public function new() {
		this.buffer32 = new BytesWriter();
		this.buffer16 = new BytesWriter();
		this.buffer8 = new BytesWriter();
	}

	public function writeU32(val:Int) {
		this.buffer32.writeInt32(val);
	}

	public inline function writeS32(val:Int) {
		this.buffer32.writeInt32(val);
	}

	public function writeF32(val:Float) {
		this.buffer32.writeFloat(val);
	}

	public function writePoint2F(p:Point2F) {
		this.writeF32(p.x);
		this.writeF32(p.y);
	}

	public function writePoint3F(p:Point3F) {
		this.writeF32(p.x);
		this.writeF32(p.y);
		this.writeF32(p.z);
	}

	public function writeBoxF(b:Box3F) {
		this.writeF32(b.minX);
		this.writeF32(b.minY);
		this.writeF32(b.minZ);
		this.writeF32(b.maxX);
		this.writeF32(b.maxY);
		this.writeF32(b.maxZ);
	}

	public function writeU16(val:Int) {
		this.buffer16.writeInt16(val & 0xFFFF);
	}

	public inline function writeS16(val:Int) {
		this.buffer16.writeInt16(val & 0xFFFF);
	}

	public function writeU8(val:Int) {
		this.buffer8.writeByte(val & 0xFF);
	}

	public function writeQuat16(quat:QuatF) {
		this.writeU16(Std.int(quat.x));
		this.writeU16(Std.int(quat.y));
		this.writeU16(Std.int(quat.z));
		this.writeU16(Std.int(quat.w));
	}

	public function writeMatrixF(mat:Array<Float>) {
		for (f in mat)
			this.writeF32(f);
	}

	public function writeString(str:String) {
		for (i in 0...str.length)
			this.writeU8(str.charCodeAt(i));
		this.writeU8(0);
	}

	public function guard() {
		this.buffer32.writeInt32(this.sequence);
		this.buffer16.writeInt16(this.sequence & 0xFFFF);
		this.buffer8.writeByte(this.sequence & 0xFF);
		this.sequence++;
	}

	// Emit the assembled header + the three buffers into the given stream.
	public function flush(out:BytesWriter, version:Int, exporterVersion:Int) {
		// Each buffer must be a whole number of 32-bit words.
		while (this.buffer16.getLength() % 4 != 0)
			this.buffer16.writeByte(0);
		while (this.buffer8.getLength() % 4 != 0)
			this.buffer8.writeByte(0);

		var b32 = this.buffer32.getBuffer();
		var b16 = this.buffer16.getBuffer();
		var b8 = this.buffer8.getBuffer();

		var end32 = b32.length >> 2;
		var end16 = end32 + (b16.length >> 2);
		var end8 = end16 + (b8.length >> 2);

		out.writeInt16(version);
		out.writeInt16(exporterVersion);
		out.writeInt32(end8);
		out.writeInt32(end32);
		out.writeInt32(end16);
		out.writeBytes(b32);
		out.writeBytes(b16);
		out.writeBytes(b8);
	}
}
