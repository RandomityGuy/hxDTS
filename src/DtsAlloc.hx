package;

import haxe.Exception;
import math.QuatF;
import math.Box3F;
import math.Point3F;
import math.Point2F;
import io.BytesReader;
import haxe.io.Bytes;

@:expose
class DtsAlloc {
	public var buf:BytesReader;

	public var index32:Int;

	public var index16:Int;

	public var index8:Int;

	public var lastGuardValue:Int = 0;

	public function new(buf:BytesReader, start32:Int, start16:Int, start8:Int) {
		this.buf = buf;
		this.index32 = start32;
		this.index16 = start32 + start16 * 4;
		this.index8 = start32 + start8 * 4;
	}

	public function readU32() {
		buf.seek(this.index32);
		var val = buf.readInt32();
		this.index32 += 4;
		return val;
	}

	public function readS32() {
		buf.seek(this.index32);
		var val = buf.readInt32();
		this.index32 += 4;
		return val;
	}

	public function readF32() {
		buf.seek(this.index32);
		var val = buf.readFloat();
		this.index32 += 4;
		return val;
	}

	public function readPoint2F():Point2F {
		return new Point2F(this.readF32(), this.readF32());
	}

	public function readPoint3F():Point3F {
		var x = this.readF32();
		var y = this.readF32();
		var z = this.readF32();
		return new Point3F(x, y, z);
	}

	public function readBoxF():Box3F {
		return new Box3F(this.readF32(), this.readF32(), this.readF32(), this.readF32(), this.readF32(), this.readF32());
	}

	public function readU16() {
		buf.seek(this.index16);
		var val = this.buf.readInt16();
		this.index16 += 2;
		return val;
	}

	public function readS16() {
		buf.seek(this.index16);
		var val = this.buf.readInt16();
		if (val > 32767)
			val -= 65536;
		this.index16 += 2;
		return val;
	}

	public function readU8() {
		buf.seek(this.index8);
		var val = this.buf.readByte();
		this.index8 += 1;
		return val;
	}

	public function readQuat16() {
		var quat = new QuatF();
		quat.x = this.readS16();
		quat.y = this.readS16();
		quat.z = this.readS16();
		quat.w = this.readS16();
		return quat;
	}

	public function readMatrixF() {
		var mat = [
			this.readF32(), this.readF32(), this.readF32(), this.readF32(),
			this.readF32(), this.readF32(), this.readF32(), this.readF32(),
			this.readF32(), this.readF32(), this.readF32(), this.readF32(),
			this.readF32(), this.readF32(), this.readF32(), this.readF32()
		];
		return mat;
	}

	public function guard() {
		var guard32 = this.readU32();
		var guard16 = this.readU16();
		var guard8 = this.readU8();
		if (!(guard32 == guard16 && guard16 == guard8 && guard8 == this.lastGuardValue)) {
			throw new Exception("Guard fail! Expected " + this.lastGuardValue + " but got " + guard32 + " for 32, " + guard16 + " for 16 and " + guard8
				+ " for 8.");
		}
		this.lastGuardValue++;
	}
}
