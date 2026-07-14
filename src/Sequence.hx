package;

import io.BytesReader;
import io.BytesWriter;

@:expose
@:publicFields
class Sequence {
	var nameIndex:Int;
	var numKeyFrames:Int;
	var duration:Float;
	var baseRotation:Int;
	var baseTranslation:Int;
	var baseScale:Int;
	var baseObjectState:Int;
	var baseDecalState:Int;
	var firstGroundFrame:Int;
	var numGroundFrames:Int;
	var firstTrigger:Int;
	var numTriggers:Int;
	var toolBegin:Float;

	var rotationMatters:Array<Int>;
	var translationMatters:Array<Int>;
	var scaleMatters:Array<Int>;
	var visMatters:Array<Int>;
	var frameMatters:Array<Int>;
	var matFrameMatters:Array<Int>;
	var decalMatters:Array<Int>;
	var iflMatters:Array<Int>;

	// The leading word of each bit set (read order); the exporter doesn't
	// always store numWords there, so keep it verbatim for writing.
	var bitSetDummies:Array<Int>;

	var priority:Int;
	var flags:Int;
	var dirtyFlags:Int;

	public function new() {}

	public function read(reader:BytesReader, fileVersion:Int, readNameIndex:Bool) {
		if (readNameIndex) {
			this.nameIndex = reader.readInt32();
		}
		this.flags = 0;

		if (fileVersion > 21) {
			this.flags = reader.readInt32();
		}
		this.numKeyFrames = reader.readInt32();
		this.duration = reader.readFloat();

		if (fileVersion < 22) {
			var tmp = reader.readByte();
			if (tmp > 0) {
				flags |= ShapeFlags.Blend;
			}
			tmp = reader.readByte();
			if (tmp > 0) {
				flags |= ShapeFlags.Cyclic;
			}
			tmp = reader.readByte();
			if (tmp > 0) {
				flags |= ShapeFlags.MakePath;
			}
		}

		this.priority = reader.readInt32();
		this.firstGroundFrame = reader.readInt32();
		this.numGroundFrames = reader.readInt32();

		if (fileVersion > 21) {
			this.baseRotation = reader.readInt32();
			this.baseTranslation = reader.readInt32();
			this.baseScale = reader.readInt32();
			this.baseObjectState = reader.readInt32();
			this.baseDecalState = reader.readInt32();
		} else {
			this.baseRotation = reader.readInt32();
			this.baseTranslation = this.baseRotation;
			this.baseObjectState = reader.readInt32();
			this.baseDecalState = reader.readInt32();
		}

		this.firstTrigger = reader.readInt32();
		this.numTriggers = reader.readInt32();
		this.toolBegin = reader.readInt32();

		bitSetDummies = [];
		rotationMatters = readBitSet(reader);
		translationMatters = readBitSet(reader);
		scaleMatters = readBitSet(reader);
		decalMatters = readBitSet(reader);
		iflMatters = readBitSet(reader);
		visMatters = readBitSet(reader);
		frameMatters = readBitSet(reader);
		matFrameMatters = readBitSet(reader);

		this.dirtyFlags = 0;
		return true;
	}

	function readBitSet(reader:BytesReader) {
		var dummy = reader.readInt32();
		var numWords = reader.readInt32();
		bitSetDummies.push(dummy);
		var ret = [];
		for (i in 0...numWords) {
			ret.push(reader.readInt32());
		}
		return ret;
	}

	// Always writes the modern (version >= 22) layout, which is what we export.
	public function write(writer:BytesWriter, writeNameIndex:Bool) {
		if (writeNameIndex) {
			writer.writeInt32(this.nameIndex);
		}
		writer.writeInt32(this.flags);
		writer.writeInt32(this.numKeyFrames);
		writer.writeFloat(this.duration);
		writer.writeInt32(this.priority);
		writer.writeInt32(this.firstGroundFrame);
		writer.writeInt32(this.numGroundFrames);
		writer.writeInt32(this.baseRotation);
		writer.writeInt32(this.baseTranslation);
		writer.writeInt32(this.baseScale);
		writer.writeInt32(this.baseObjectState);
		writer.writeInt32(this.baseDecalState);
		writer.writeInt32(this.firstTrigger);
		writer.writeInt32(this.numTriggers);
		writer.writeInt32(Std.int(this.toolBegin)); // read as a raw int32, so written back as one

		writeBitSet(writer, 0, rotationMatters);
		writeBitSet(writer, 1, translationMatters);
		writeBitSet(writer, 2, scaleMatters);
		writeBitSet(writer, 3, decalMatters);
		writeBitSet(writer, 4, iflMatters);
		writeBitSet(writer, 5, visMatters);
		writeBitSet(writer, 6, frameMatters);
		writeBitSet(writer, 7, matFrameMatters);
	}

	function writeBitSet(writer:BytesWriter, index:Int, words:Array<Int>) {
		// Preserve the exporter's leading word if we have it, else fall back to
		// the word count (matches the reference exporter's behaviour).
		var dummy = (bitSetDummies != null && index < bitSetDummies.length) ? bitSetDummies[index] : words.length;
		writer.writeInt32(dummy);
		writer.writeInt32(words.length);
		for (word in words) {
			writer.writeInt32(word);
		}
	}
}
