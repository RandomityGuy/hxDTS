package;

import haxe.io.Bytes;
import haxe.Exception;
import io.BytesReader;
import io.BytesWriter;
import math.QuatF;
import math.Box3F;
import math.Point3F;

@:expose
@:publicFields
class DtsFile {
	var fileVersion:Int;
	var exporterVersion:Int;
	var sequences:Array<Sequence>;
	var matNames:Array<String>;
	var matFlags:Array<Int>;
	var matReflectanceMaps:Array<Int>;
	var matBumpMaps:Array<Int>;
	var matDetailMaps:Array<Int>;
	var matDetailScales:Array<Float>;
	var matReflectionAmounts:Array<Float>;
	var smallestVisibleSize:Float;
	var smallestVisibleDL:Float;

	var radius:Float;
	var radiusTube:Float;
	var center:Point3F;
	var bounds:Box3F;

	var nodes:Array<Node>;
	var objects:Array<Object>;
	var mats:Array<IflMaterial>;
	var subshapes:Array<SubShape>;

	var defaultRotations:Array<QuatF>;
	var defaultTranslations:Array<Point3F>;

	var nodeTranslations:Array<Point3F>;
	var nodeRotations:Array<QuatF>;

	var nodeUniformScales:Array<Float>;
	var nodeAlignedScales:Array<Point3F>;
	var nodeArbitraryScaleFactors:Array<Point3F>;
	var nodeArbitraryScaleRots:Array<QuatF>;

	var groundTranslations:Array<Point3F>;
	var groundRots:Array<QuatF>;

	var objectStates:Array<ObjectState>;
	var decalStates:Array<Int>;
	var triggers:Array<Trigger>;

	var detailLevels:Array<Detail>;
	var meshes:Array<Mesh>;

	var names:Array<String>;

	var alphaIn:Array<Int>;
	var alphaOut:Array<Int>;

	public function new() {}

	public function read(bytesInput:haxe.io.BytesData) {
		var bytes = Bytes.ofData(bytesInput);
		var br = new BytesReader(bytes);

		fileVersion = br.readInt16();
		exporterVersion = br.readInt16();
		fileVersion &= 0xFF;

		var memBuffer:BytesReader;
		var start32:Int;
		var start16:Int;
		var start8:Int;

		if (fileVersion > 24) {
			throw new Exception("Invalid DTS version");
		}

		if (fileVersion < 19) {
			var result = this.readOldShape(fileVersion, br);
			memBuffer = new BytesReader(result.bufferInfo.buffer);
			start32 = 0;
			start16 = result.bufferInfo.start16;
			start8 = result.bufferInfo.start8;

			sequences = result.sequences;
			// throw new Exception("Cant read this!");
		} else {
			var sizeMemBuffer = br.readInt32();
			memBuffer = br;
			start16 = br.readInt32();
			start8 = br.readInt32();
			start32 = br.tell();

			br.seek(br.tell() + sizeMemBuffer * 4);

			var numSequences = br.readInt32();
			sequences = [];
			for (i in 0...numSequences) {
				var seq = new Sequence();
				seq.read(br, fileVersion, true);
				sequences.push(seq);
			}

			parseMaterialList(br, fileVersion);
		}

		var alloc = new DtsAlloc(memBuffer, start32, start16, start8);
		this.assembleShape(alloc);
	}

	function readOldShape(version:Int, br:BytesReader) {
		var oldAlloc = new DtsOldAlloc(br, br.tell());

		oldAlloc.allocate32(15);
		oldAlloc.guard();

		oldAlloc.copyInto32(1); // Radius
		oldAlloc.copyInto32(1); // Tube radius
		oldAlloc.copyInto32(3); // Center
		oldAlloc.copyInto32(6); // Bounds

		oldAlloc.guard();

		var numNodes = oldAlloc.readS32(0);
		for (i in 0...numNodes) {
			oldAlloc.copyInto32(2);
			oldAlloc.allocate32(3);
		}

		oldAlloc.guard();

		var numObjects = oldAlloc.readS32(1);
		for (i in 0...numObjects) {
			oldAlloc.copyInto32(4);
			oldAlloc.allocate32(2);
		}

		oldAlloc.guard();

		var numDecals = oldAlloc.readS32(2);
		for (i in 0...numDecals) {
			oldAlloc.copyInto32(4);
			oldAlloc.allocate32(1);
		}

		oldAlloc.guard();

		var numIflMaterials = oldAlloc.readS32(4);
		for (i in 0...numIflMaterials) {
			oldAlloc.copyInto32(2);
			oldAlloc.allocate32(3);
		}

		oldAlloc.guard();

		var numSubShapes = oldAlloc.readS32(3);
		var subShapeFirstStart = oldAlloc.index32;
		oldAlloc.copyInto32(numSubShapes); // subShapeFirstNode
		oldAlloc.skip(4); // toss
		oldAlloc.copyInto32(numSubShapes); // subShapeFirstObject
		oldAlloc.skip(4); // toss
		oldAlloc.copyInto32(numSubShapes); // subShapeFirstDecal

		oldAlloc.guard();

		var subShapeNumStart = oldAlloc.index32;
		oldAlloc.allocate32(3 * numSubShapes);

		oldAlloc.guard();

		// compute subShapeNum* vectors
		var prev, first;
		for (i in 0...3) {
			prev = ((i == 0) ? numNodes : (i == 1 ? numObjects : numDecals));
			var j = numSubShapes - 1;
			while (j >= 0) {
				first = oldAlloc.buffer32.getInt32(subShapeFirstStart + j * 4);
				oldAlloc.buffer32.setInt32(subShapeNumStart + j * 4, prev - first);
				prev = first;
				j--;
			}

			subShapeFirstStart += numSubShapes;
			subShapeNumStart += numSubShapes;
		}

		var numNodeStates = oldAlloc.readS32(5);
		var nodeStateStart32 = oldAlloc.index32;
		var nodeStateStart16 = oldAlloc.index16;
		for (i in 0...numNodeStates) {
			oldAlloc.copyInto16(4); // read Quat16....rotation
			oldAlloc.copyInto32(3); // read Point3F...translation
		}

		oldAlloc.guard();

		var numObjectStates = oldAlloc.readS32(6);
		var objectStateStart = oldAlloc.index32;
		oldAlloc.copyInto32(numObjectStates * 3);

		oldAlloc.guard();

		var numDecalStates = oldAlloc.readS32(7);
		var decalStateStart = oldAlloc.index32;
		oldAlloc.copyInto32(numDecalStates);

		oldAlloc.guard();

		var numTriggers = oldAlloc.readS32(8);
		oldAlloc.copyInto32(numTriggers * 2);

		oldAlloc.guard();

		var numDetails = oldAlloc.readS32(9);
		for (i in 0...numDetails) {
			oldAlloc.copyInto32(4);
			oldAlloc.allocate32(3);
		}

		// There's some added detail filling-up code here, but we don't use these anyways. Screw it.

		oldAlloc.guard();

		br.seek(oldAlloc.sourceIndex);
		var numSequences = br.readInt32();
		var sequences = [];
		for (i in 0...numSequences) {
			var sequence = new Sequence();
			sequence.read(br, version, true);
			sequences.push(sequence);
		}

		oldAlloc.sourceIndex = br.tell();
		var numMeshes = oldAlloc.readS32(10);
		for (i in 0...numMeshes) {
			var meshType = oldAlloc.readS32(-1);
			this.readAllocMesh(oldAlloc, meshType);
		}

		oldAlloc.guard();

		var numNames = oldAlloc.readS32(12);
		for (i in 0...numNames) {
			var length = oldAlloc.readS32(null);
			oldAlloc.copyInto8(length);
			oldAlloc.writeU8(0); // end the string
		}

		oldAlloc.guard();

		br.seek(oldAlloc.sourceIndex);
		var gotList = br.readInt32();
		if (gotList > 0) {
			this.parseMaterialList(br, version);
		}
		oldAlloc.sourceIndex = br.tell();

		// Note: There would still be some skinned mesh or whatever code following this, but really, that's totally unnecessary. To prevent stupid "read out of range" errors when reading this buffer, we just add some extra bit to the end. Done.
		oldAlloc.allocate32(16);

		return {
			bufferInfo: oldAlloc.createBuffer(),
			sequences: sequences,
		};
	}

	function readAllocMesh(oldAlloc:DtsOldAlloc, meshType:Int) {
		if (meshType == 4)
			return;

		oldAlloc.guard();

		// numFrames, numMatFrames
		oldAlloc.copyInto32(2);

		// parentMesh
		oldAlloc.writeS32(-1);

		// allocate memory for mBounds,mCenter, and mRadius...just filler, will be computed later
		oldAlloc.allocate32(10);

		// read in verts
		var numVerts = oldAlloc.readS32(-1);
		oldAlloc.copyInto32(numVerts * 3);

		// read in tverts
		var numTverts = oldAlloc.readS32(-1);
		oldAlloc.copyInto32(numTverts * 2);

		// read in normals
		var numNormals = oldAlloc.readS32(null); // we could assume same as verts, but apparently in file.
		oldAlloc.copyInto32(numNormals * 3);

		// read in primitives
		var numPrimitives = oldAlloc.readS32(-1);
		for (i in 0...numPrimitives) {
			oldAlloc.copyInto16(2);
			oldAlloc.copyInto32(1);
		}

		// read in indices
		var numIndices = oldAlloc.readS32(-1);
		oldAlloc.copyInto16(numIndices);

		// mergeIndices...none
		oldAlloc.writeS32(0);

		// vertsPerFrame, flags
		oldAlloc.copyInto32(2);

		oldAlloc.guard();

		if (meshType == 1) {
			var numInitialVerts = oldAlloc.readS32(-1);
			oldAlloc.copyInto32(numInitialVerts * 3);

			var numInitialNorms = oldAlloc.readS32(null); // we assume same as verts
			oldAlloc.copyInto32(numInitialNorms * 3);

			var numInitialTransforms = oldAlloc.readS32(-1);
			oldAlloc.copyInto32(numInitialTransforms * 16);

			var numVertIndices = oldAlloc.readS32(-1);
			oldAlloc.copyInto32(numVertIndices);

			var numBoneIndices = oldAlloc.readS32(null);
			oldAlloc.copyInto32(numBoneIndices);

			var weightStart = oldAlloc.index32;
			oldAlloc.allocate32(numBoneIndices); // this is memory for the weights

			var numNodeIndices = oldAlloc.readS32(-1);
			oldAlloc.copyInto32(numNodeIndices);
			var returnToIndex = oldAlloc.index32;

			var numWeights = oldAlloc.readS32(null);
			oldAlloc.index32 = weightStart;
			oldAlloc.copyInto32(numWeights);
			oldAlloc.index32 = returnToIndex;

			oldAlloc.guard();
		}
	}

	function assembleShape(ar:DtsAlloc) {
		var numNodes = ar.readS32();
		var numObjects = ar.readS32();
		var numDecals = ar.readS32();
		var numSubShapes = ar.readS32();
		var numIflMaterials = ar.readS32();

		var numNodeRots:Int;
		var numNodeTrans:Int;
		var numNodeUniformScales:Int;
		var numNodeAlignedScales:Int;
		var numNodeArbitraryScales:Int;
		if (this.fileVersion < 22) {
			numNodeRots = numNodeTrans = ar.readS32() - numNodes;
			numNodeUniformScales = numNodeAlignedScales = numNodeArbitraryScales = 0;
		} else {
			numNodeRots = ar.readS32();
			numNodeTrans = ar.readS32();
			numNodeUniformScales = ar.readS32();
			numNodeAlignedScales = ar.readS32();
			numNodeArbitraryScales = ar.readS32();
		}
		var numGroundFrames = 0;
		if (this.fileVersion > 23) {
			numGroundFrames = ar.readS32();
		}
		var numObjectStates = ar.readS32();
		var numDecalStates = ar.readS32();
		var numTriggers = ar.readS32();
		var numDetails = ar.readS32();
		var numMeshes = ar.readS32();
		var numSkins = 0;
		if (this.fileVersion < 23) {
			numSkins = ar.readS32();
		}
		var numNames = ar.readS32();
		this.smallestVisibleSize = ar.readF32();
		this.smallestVisibleDL = ar.readS32();

		ar.guard();

		radius = ar.readF32();
		radiusTube = ar.readF32();
		center = ar.readPoint3F();
		bounds = ar.readBoxF();

		ar.guard();

		nodes = [];
		for (i in 0...numNodes) {
			nodes.push(Node.read(ar));
		}
		ar.guard();

		objects = [];
		for (i in 0...numObjects) {
			objects.push(Object.read(ar));
		}
		ar.guard();
		ar.guard();

		mats = [];
		for (i in 0...numIflMaterials) {
			mats.push(IflMaterial.read(ar));
		}
		ar.guard();

		subshapes = [];

		for (i in 0...numSubShapes) {
			subshapes.push(new SubShape(0, 0, 0, 0, 0, 0));
			subshapes[i].firstNode = ar.readS32();
		}
		for (i in 0...numSubShapes)
			subshapes[i].firstObject = ar.readS32();
		for (i in 0...numSubShapes)
			subshapes[i].firstDecal = ar.readS32();

		ar.guard();

		for (i in 0...numSubShapes)
			subshapes[i].numNodes = ar.readS32();
		for (i in 0...numSubShapes)
			subshapes[i].numObjects = ar.readS32();
		for (i in 0...numSubShapes)
			subshapes[i].numDecals = ar.readS32();
		ar.guard();

		if (fileVersion < 16) {
			var num = ar.readS32();
			for (i in 0...num)
				ar.readS32();
		}

		defaultRotations = [];
		defaultTranslations = [];
		for (i in 0...numNodes) {
			defaultRotations.push(ar.readQuat16());
			defaultTranslations.push(ar.readPoint3F());
		}

		nodeTranslations = [];
		for (i in 0...numNodeTrans)
			nodeTranslations.push(ar.readPoint3F());

		nodeRotations = [];
		for (i in 0...numNodeRots)
			nodeRotations.push(ar.readQuat16());

		ar.guard();

		nodeUniformScales = [];
		nodeAlignedScales = [];
		nodeArbitraryScaleFactors = [];
		nodeArbitraryScaleRots = [];

		if (fileVersion > 21) {
			for (i in 0...numNodeUniformScales)
				nodeUniformScales.push(ar.readF32());
			for (i in 0...numNodeAlignedScales)
				nodeAlignedScales.push(ar.readPoint3F());
			for (i in 0...numNodeArbitraryScales)
				nodeArbitraryScaleFactors.push(ar.readPoint3F());
			for (i in 0...numNodeArbitraryScales)
				nodeArbitraryScaleRots.push(ar.readQuat16());
			ar.guard();
		} else {
			for (i in 0...numNodeUniformScales)
				nodeUniformScales.push(1);
			for (i in 0...numNodeAlignedScales)
				nodeAlignedScales.push(new Point3F(1, 1, 1));
			for (i in 0...numNodeArbitraryScales)
				nodeArbitraryScaleFactors.push(new Point3F(1, 1, 1));
			for (i in 0...numNodeArbitraryScales)
				nodeArbitraryScaleRots.push(new QuatF());
		}

		groundTranslations = [];
		groundRots = [];
		if (fileVersion > 23) {
			for (i in 0...numGroundFrames) {
				groundTranslations.push(ar.readPoint3F());
			}
			for (i in 0...numGroundFrames) {
				groundRots.push(ar.readQuat16());
			}
			ar.guard();
		} else {
			for (i in 0...numGroundFrames) {
				groundTranslations.push(new Point3F(1, 1, 1));
			}
			for (i in 0...numGroundFrames) {
				groundRots.push(new QuatF());
			}
		}

		objectStates = [];
		for (i in 0...numObjectStates) {
			objectStates.push(ObjectState.read(ar));
		}
		ar.guard();

		decalStates = [];
		for (i in 0...numDecalStates) {
			decalStates.push(ar.readS32());
		}
		ar.guard();

		triggers = [];
		for (i in 0...numTriggers) {
			triggers.push(Trigger.read(ar));
		}
		ar.guard();

		detailLevels = [];
		for (i in 0...numDetails) {
			detailLevels.push(Detail.read(ar));
		}
		ar.guard();

		meshes = [];
		for (i in 0...numMeshes) {
			meshes.push(Mesh.read(this, ar, fileVersion));
		}
		ar.guard();

		names = [];
		for (i in 0...numNames) {
			var str = "";

			while (true) {
				var charCode = ar.readU8();
				if (charCode == 0)
					break;

				str += String.fromCharCode(charCode);
			}

			names.push(str);
		}
		ar.guard();

		alphaIn = [];
		alphaOut = [];

		if (fileVersion >= 26) {
			for (i in 0...numDetails) {
				alphaIn.push(ar.readS32());
			}
			for (i in 0...numDetails) {
				alphaOut.push(ar.readS32());
			}
		}
	}

	function parseMaterialList(br:BytesReader, version:Int) {
		var matStreamType = br.readByte();
		var numMaterials = br.readInt32();
		matNames = [];
		matFlags = [];
		matReflectanceMaps = [];
		matBumpMaps = [];
		matDetailMaps = [];
		matDetailScales = [];
		matReflectionAmounts = [];
		for (i in 0...numMaterials) {
			var mname = br.readStr();
			mname = StringTools.replace(mname, '\x00', '');
			matNames.push(mname);
		}
		for (i in 0...numMaterials) {
			matFlags.push(br.readInt32());
		}
		for (i in 0...numMaterials) {
			matReflectanceMaps.push(br.readInt32());
		}
		for (i in 0...numMaterials) {
			matBumpMaps.push(br.readInt32());
		}
		for (i in 0...numMaterials) {
			matDetailMaps.push(br.readInt32());
		}
		if (version == 25) {
			for (i in 0...numMaterials) {
				br.readInt32();
			}
		}
		for (i in 0...numMaterials) {
			matDetailScales.push(br.readFloat());
		}
		for (i in 0...numMaterials) {
			matReflectionAmounts.push(br.readFloat());
		}
	}

	function readName(br:BytesReader, addName:Bool) {
		var sz = br.readInt32();
		var nameIndex = -1;
		if (sz > 0) {
			var str = "";
			for (i in 0...sz) {
				str += String.fromCharCode(br.readByte());
			}
			nameIndex = names.indexOf(str);
			if (nameIndex < 0 && addName) {
				nameIndex = names.length;
				names.push(str);
			}
		}
		return nameIndex;
	}

	public function importSequences(bytesInput:haxe.io.BytesData) {
		var bytes = Bytes.ofData(bytesInput);
		var br = new BytesReader(bytes);

		var version = br.readInt32();
		var sz = br.readInt32();
		var checkForDups = [];
		var nodeMap = [];
		for (i in 0...sz)
			nodeMap.push(0);
		for (i in 0...sz) {
			var startSize = names.length;
			var nameIndex = readName(br, true);
			var count = 0;
			if (nameIndex >= 0) {
				while (checkForDups.length < nameIndex + 1)
					checkForDups.push(0);
				count = checkForDups[nameIndex]++;
			}
			if (count > 0) {
				nodeMap[i] = -1;
				var jout = 0;
				for (j in 0...nodes.length) {
					if (nodes[j].name == nameIndex && count-- == 0)
						break;
					jout++;
				}
				nodeMap[i] = jout;
				if (jout == nodes.length) {
					return false;
				}
			} else {
				nodeMap[i] = nodes.indexOf(nodes.filter(x -> x.name == nameIndex)[0]);
			}
			if (nodeMap[i] < 0) {
				// error -- node found in sequence but not shape
				if (names.length != startSize) {
					names.pop();
				}
				return false;
			}
		}

		sz = br.readInt32();
		var oldShapeNumObjects = br.readInt32();

		var keyframes = [];
		if (version < 17) {
			var sz = br.readInt32();
			for (i in 0...sz) {
				keyframes.push(KeyFrame.read(br));
			}
		}

		var adjNodeRots = version < 22 ? nodeRotations.length - nodeMap.length : nodeRotations.length;
		var adjNodeTrans = version < 22 ? nodeTranslations.length - nodeMap.length : nodeTranslations.length;
		var adjNodeScales1 = nodeUniformScales.length;
		var adjNodeScales2 = nodeAlignedScales.length;
		var adjNodeScales3 = nodeArbitraryScaleFactors.length;
		var adjObjectStates = objectStates.length - oldShapeNumObjects;
		var adjGroundStates = version < 22 ? 0 : groundTranslations.length; // groundTrans==groundRot

		for (i in 0...keyframes.length) {
			// have keyframes only for old shapes...use adjNodeRots for adjustment
			// since same as adjNodeScales...
			keyframes[i].firstNodeState += adjNodeRots;
			keyframes[i].firstObjectState += adjObjectStates;
		}

		function readS16() {
			var val = br.readInt16();
			if (val > 32767)
				val -= 65536;
			return val;
		}

		// add these node states to our own
		if (version > 21) {
			sz = br.readInt32();
			for (i in 0...sz) {
				var q = new QuatF();
				q.x = readS16();
				q.y = readS16();
				q.z = readS16();
				q.w = readS16();
				nodeRotations.push(q);
			}
			sz = br.readInt32();
			for (i in 0...sz) {
				var p = new Point3F();
				p.x = br.readFloat();
				p.y = br.readFloat();
				p.z = br.readFloat();
				nodeTranslations.push(p);
			}
			sz = br.readInt32();
			for (i in 0...sz)
				nodeUniformScales.push(br.readFloat());
			sz = br.readInt32();
			for (i in 0...sz) {
				var p = new Point3F();
				p.x = br.readFloat();
				p.y = br.readFloat();
				p.z = br.readFloat();
				nodeAlignedScales.push(p);
			}
			sz = br.readInt32();
			for (i in 0...sz) {
				var q = new QuatF();
				q.x = readS16();
				q.y = readS16();
				q.z = readS16();
				q.w = readS16();
				nodeArbitraryScaleRots.push(q);
			}
			for (i in 0...sz) {
				var p = new Point3F();
				p.x = br.readFloat();
				p.y = br.readFloat();
				p.z = br.readFloat();
				nodeArbitraryScaleFactors.push(p);
			}
			sz = br.readInt32();
			for (i in 0...sz) {
				var p = new Point3F();
				p.x = br.readFloat();
				p.y = br.readFloat();
				p.z = br.readFloat();
				groundTranslations.push(p);
			}
			for (i in 0...sz) {
				var q = new QuatF();
				q.x = readS16();
				q.y = readS16();
				q.z = readS16();
				q.w = readS16();
				groundRots.push(q);
			}
		} else {
			sz = br.readInt32();
			for (i in 0...sz) {
				var q = new QuatF();
				q.x = readS16();
				q.y = readS16();
				q.z = readS16();
				q.w = readS16();
				var p = new Point3F();
				p.x = br.readFloat();
				p.y = br.readFloat();
				p.z = br.readFloat();
				nodeRotations.push(q);
				nodeTranslations.push(p);
			}
		}

		sz = br.readInt32();
		sz = br.readInt32();
		var startSeqNum = sequences.length;
		for (i in 0...sz) {
			var seq = new Sequence();
			seq.nameIndex = readName(br, true);
			seq.read(br, fileVersion, false);

			if (version > 21) {
				seq.baseRotation += adjNodeRots;
				seq.baseTranslation += adjNodeTrans;
				if (seq.flags & 1 > 0)
					seq.baseScale += adjNodeScales1;
				else if (seq.flags & 2 > 0)
					seq.baseScale += adjNodeScales2;
				else if (seq.flags & 4 > 0)
					seq.baseScale += adjNodeScales3;
			} else if (version >= 17) {
				seq.baseRotation += adjNodeRots; // == adjNodeTrans
				seq.baseTranslation += adjNodeTrans; // == adjNodeTrans
			}

			var newTM = 0;
			var newRM = 0;
			var newSM = 0;
			for (j in 0...nodeMap.length) {
				if (seq.translationMatters[0] & (1 << j) > 0)
					newTM |= (1 << nodeMap[j]);
				if (seq.rotationMatters[0] & (1 << j) > 0)
					newRM |= (1 << nodeMap[j]);
				if (seq.scaleMatters[0] & (1 << j) > 0)
					newSM |= (1 << nodeMap[j]);
			}
			seq.translationMatters[0] = newTM;
			seq.rotationMatters[0] = newRM;
			seq.scaleMatters[0] = newSM;
			seq.firstTrigger += triggers.length;
			seq.firstGroundFrame += adjGroundStates;

			sequences.push(seq);
		}

		if (version < 17)
			return false; // Cannot, not actually needed in this game

		if (version < 22) {
			for (i in startSeqNum...sequences.length) {
				var oldSz = groundTranslations.length;
				for (j in 0...sequences[i].numGroundFrames) {
					groundTranslations.push(nodeTranslations[sequences[i].firstGroundFrame + adjNodeTrans + j]);
					groundRots.push(nodeRotations[sequences[i].firstGroundFrame + adjNodeRots + j]);
				}
				sequences[i].firstGroundFrame = oldSz;
			}
		}

		if (version > 8) {
			sz = br.readInt32();
			for (i in 0...sz) {
				var t = new Trigger();
				t.state = br.readInt32();
				t.position = br.readFloat();
			}
		}

		return true;
	}

	// Counterpart to assembleShape: serialise the shape back into DTS bytes.
	// Each struct writes itself through DtsWriteAlloc, mirroring its read().
	public function write(?dtsVersion:Int):Bytes {
		if (dtsVersion == null)
			dtsVersion = this.fileVersion;

		if (dtsVersion < 19)
			return writeOldShape(dtsVersion);

		var alloc = new DtsWriteAlloc();

		// counts...
		alloc.writeU32(nodes.length);
		alloc.writeU32(objects.length);
		alloc.writeU32(0); // decals (not modelled)
		alloc.writeU32(subshapes.length);
		alloc.writeU32(mats.length);

		if (dtsVersion < 22) {
			alloc.writeU32(nodeRotations.length + nodes.length);
		} else {
			alloc.writeU32(nodeRotations.length);
			alloc.writeU32(nodeTranslations.length);
			alloc.writeU32(nodeUniformScales.length);
			alloc.writeU32(nodeAlignedScales.length);
			alloc.writeU32(nodeArbitraryScaleFactors.length);
		}

		if (dtsVersion > 23)
			alloc.writeU32(groundTranslations.length);

		alloc.writeU32(objectStates.length);
		alloc.writeU32(decalStates.length);
		alloc.writeU32(triggers.length);
		alloc.writeU32(detailLevels.length);
		alloc.writeU32(meshes.length);

		if (dtsVersion < 23)
			alloc.writeU32(0); // skins

		alloc.writeU32(names.length);
		alloc.writeF32(smallestVisibleSize);
		alloc.writeU32(Std.int(smallestVisibleDL));
		alloc.guard();

		// bounds...
		alloc.writeF32(radius);
		alloc.writeF32(radiusTube);
		alloc.writePoint3F(center);
		alloc.writeBoxF(bounds);
		alloc.guard();

		// nodes...
		for (node in nodes)
			node.write(alloc);
		alloc.guard();

		// objects...
		for (object in objects)
			object.write(alloc);
		alloc.guard();

		// decals (none)...
		alloc.guard();

		// ifl materials...
		for (ifl in mats)
			ifl.write(alloc);
		alloc.guard();

		// subshapes...
		for (s in subshapes)
			alloc.writeU32(s.firstNode);
		for (s in subshapes)
			alloc.writeU32(s.firstObject);
		for (s in subshapes)
			alloc.writeU32(s.firstDecal);
		alloc.guard();
		for (s in subshapes)
			alloc.writeU32(s.numNodes);
		for (s in subshapes)
			alloc.writeU32(s.numObjects);
		for (s in subshapes)
			alloc.writeU32(s.numDecals);
		alloc.guard();

		// default rotations & translations...
		for (i in 0...nodes.length) {
			alloc.writeQuat16(defaultRotations[i]);
			alloc.writePoint3F(defaultTranslations[i]);
		}

		// animation translations & rotations...
		for (p in nodeTranslations)
			alloc.writePoint3F(p);
		for (q in nodeRotations)
			alloc.writeQuat16(q);
		alloc.guard();

		// ...with scale
		if (dtsVersion > 21) {
			for (f in nodeUniformScales)
				alloc.writeF32(f);
			for (p in nodeAlignedScales)
				alloc.writePoint3F(p);
			for (p in nodeArbitraryScaleFactors)
				alloc.writePoint3F(p);
			for (q in nodeArbitraryScaleRots)
				alloc.writeQuat16(q);
			alloc.guard();
		}

		// ground transforms...
		if (dtsVersion > 23) {
			for (p in groundTranslations)
				alloc.writePoint3F(p);
			for (q in groundRots)
				alloc.writeQuat16(q);
			alloc.guard();
		}

		// object states...
		for (state in objectStates)
			state.write(alloc);
		alloc.guard();

		// decal states...
		for (d in decalStates)
			alloc.writeU32(d);
		alloc.guard();

		// triggers...
		for (trigger in triggers)
			trigger.write(alloc);
		alloc.guard();

		// details...
		for (detail in detailLevels)
			detail.write(alloc);
		alloc.guard();

		// meshes...
		for (mesh in meshes) {
			if (mesh == null)
				alloc.writeS32(4); // NullType, no body follows
			else
				mesh.write(alloc, dtsVersion);
		}
		alloc.guard();

		// names...
		for (name in names)
			alloc.writeString(name);
		alloc.guard();

		// per-detail alpha (v26+)...
		if (dtsVersion >= 26) {
			for (a in alphaIn)
				alloc.writeU32(a);
			for (a in alphaOut)
				alloc.writeU32(a);
		}

		var out = new BytesWriter();

		// header + the three buffers
		alloc.flush(out, dtsVersion, exporterVersion);

		// sequences
		out.writeInt32(sequences.length);
		for (seq in sequences)
			seq.write(out, true);

		// material list
		writeMaterialList(out, dtsVersion);

		return out.getBuffer();
	}

	function writeMaterialList(out:BytesWriter, version:Int) {
		out.writeByte(0x1); // material stream type
		out.writeInt32(matNames.length);
		for (name in matNames) {
			out.writeByte(name.length);
			for (i in 0...name.length)
				out.writeByte(name.charCodeAt(i) & 0xFF);
		}
		for (v in matFlags)
			out.writeInt32(v);
		for (v in matReflectanceMaps)
			out.writeInt32(v);
		for (v in matBumpMaps)
			out.writeInt32(v);
		for (v in matDetailMaps)
			out.writeInt32(v);
		if (version == 25)
			for (i in 0...matNames.length)
				out.writeInt32(0);
		for (v in matDetailScales)
			out.writeFloat(v);
		for (v in matReflectionAmounts)
			out.writeFloat(v);
	}

	// ---------------------------------------------------------------------
	// Old (< v19) shape writing. The old on-disk format is a linear stream
	// (the tri-buffer is only an intermediate used while reading), so this is
	// a direct reversal of readOldShape.
	// ---------------------------------------------------------------------

	inline function oldVec3(out:BytesWriter, p:Point3F) {
		out.writeFloat(p.x);
		out.writeFloat(p.y);
		out.writeFloat(p.z);
	}

	inline function oldQuat16(out:BytesWriter, q:QuatF) {
		out.writeInt16(Std.int(q.x) & 0xFFFF);
		out.writeInt16(Std.int(q.y) & 0xFFFF);
		out.writeInt16(Std.int(q.z) & 0xFFFF);
		out.writeInt16(Std.int(q.w) & 0xFFFF);
	}

	function writeOldShape(version:Int):Bytes {
		var out = new BytesWriter();

		out.writeInt16(version);
		out.writeInt16(exporterVersion);

		// bounds
		out.writeFloat(radius);
		out.writeFloat(radiusTube);
		oldVec3(out, center);
		oldVec3(out, new Point3F(bounds.minX, bounds.minY, bounds.minZ));
		oldVec3(out, new Point3F(bounds.maxX, bounds.maxY, bounds.maxZ));

		// nodes: name, parent
		out.writeInt32(nodes.length);
		for (n in nodes) {
			out.writeInt32(n.name);
			out.writeInt32(n.parent);
		}

		// objects: name, numMeshes, firstMesh, node
		out.writeInt32(objects.length);
		for (o in objects) {
			out.writeInt32(o.name);
			out.writeInt32(o.numMeshes);
			out.writeInt32(o.firstMesh);
			out.writeInt32(o.node);
		}

		// decals (not modelled)
		out.writeInt32(0);

		// ifl materials: name, slot
		out.writeInt32(mats.length);
		for (ifl in mats) {
			out.writeInt32(ifl.name);
			out.writeInt32(ifl.slot);
		}

		// subshapes: firstNode[], (count), firstObject[], (count), firstDecal[]
		out.writeInt32(subshapes.length);
		for (s in subshapes)
			out.writeInt32(s.firstNode);
		out.writeInt32(subshapes.length);
		for (s in subshapes)
			out.writeInt32(s.firstObject);
		out.writeInt32(subshapes.length);
		for (s in subshapes)
			out.writeInt32(s.firstDecal);

		// node states: defaults first, then animation. Each = quat16 + point3f
		out.writeInt32(nodes.length + nodeRotations.length);
		for (i in 0...nodes.length) {
			oldQuat16(out, defaultRotations[i]);
			oldVec3(out, defaultTranslations[i]);
		}
		for (i in 0...nodeRotations.length) {
			oldQuat16(out, nodeRotations[i]);
			oldVec3(out, nodeTranslations[i]);
		}

		// object states: vis, frame, matFrame
		out.writeInt32(objectStates.length);
		for (st in objectStates) {
			out.writeFloat(st.vis);
			out.writeInt32(st.frame);
			out.writeInt32(st.matFrame);
		}

		// decal states
		out.writeInt32(decalStates.length);
		for (d in decalStates)
			out.writeInt32(d);

		// triggers: state, position (read as raw int32)
		out.writeInt32(triggers.length);
		for (t in triggers) {
			out.writeInt32(t.state);
			out.writeInt32(Std.int(t.position));
		}

		// details: name, subShape, objectDetail, size
		out.writeInt32(detailLevels.length);
		for (d in detailLevels) {
			out.writeInt32(d.name);
			out.writeInt32(d.subShape);
			out.writeInt32(d.objectDetail);
			out.writeFloat(d.size);
		}

		// sequences (old format)
		out.writeInt32(sequences.length);
		for (seq in sequences)
			writeOldSequence(out, seq, version);

		// meshes (old format)
		out.writeInt32(meshes.length);
		for (mesh in meshes)
			writeOldMesh(out, mesh);

		// names: length, chars (no null terminator on disk)
		out.writeInt32(names.length);
		for (name in names) {
			out.writeInt32(name.length);
			for (i in 0...name.length)
				out.writeByte(name.charCodeAt(i) & 0xFF);
		}

		// material list
		if (matNames != null) {
			out.writeInt32(1); // gotList
			writeMaterialList(out, version);
		} else {
			out.writeInt32(0);
		}

		// legacy skin count (skin data itself is not modelled)
		out.writeInt32(0);

		return out.getBuffer();
	}

	function writeOldMesh(out:BytesWriter, mesh:Mesh) {
		if (mesh == null) {
			out.writeInt32(4); // NullType
			return;
		}

		out.writeInt32(mesh.meshType);

		if (mesh.meshType == 4)
			return;

		out.writeInt32(mesh.numFrames);
		out.writeInt32(mesh.numMatFrames);

		out.writeInt32(mesh.vertices.length);
		for (v in mesh.vertices)
			oldVec3(out, v);

		out.writeInt32(mesh.uv.length);
		for (t in mesh.uv) {
			out.writeFloat(t.x);
			out.writeFloat(t.y);
		}

		out.writeInt32(mesh.normals.length);
		for (n in mesh.normals)
			oldVec3(out, n);

		out.writeInt32(mesh.primitives.length);
		for (p in mesh.primitives) {
			out.writeInt16(p.firstElement & 0xFFFF);
			out.writeInt16(p.numElements & 0xFFFF);
			out.writeInt32(p.matIndex);
		}

		out.writeInt32(mesh.indices.length);
		for (i in mesh.indices)
			out.writeInt16(i & 0xFFFF);

		out.writeInt32(mesh.vertsPerFrame);
		out.writeInt32(mesh.type);

		if (mesh.meshType == 1) {
			// Skinned mesh extra data (old layout).
			out.writeInt32(mesh.vertices.length);
			for (v in mesh.vertices)
				oldVec3(out, v);
			out.writeInt32(mesh.normals.length);
			for (n in mesh.normals)
				oldVec3(out, n);

			out.writeInt32(mesh.initialTransforms.length);
			for (tr in mesh.initialTransforms)
				for (f in tr)
					out.writeFloat(f);

			out.writeInt32(mesh.vertexIndices.length);
			for (vi in mesh.vertexIndices)
				out.writeInt32(vi);
			out.writeInt32(mesh.boneIndices.length);
			for (bi in mesh.boneIndices)
				out.writeInt32(bi);
			out.writeInt32(mesh.nodeIndices.length);
			for (ni in mesh.nodeIndices)
				out.writeInt32(ni);
			out.writeInt32(mesh.weights.length);
			for (w in mesh.weights)
				out.writeFloat(w);
		}
	}

	function writeOldSequence(out:BytesWriter, seq:Sequence, version:Int) {
		out.writeInt32(seq.nameIndex);
		out.writeInt32(seq.numKeyFrames);
		out.writeFloat(seq.duration);
		out.writeByte((seq.flags & ShapeFlags.Blend) != 0 ? 1 : 0);
		out.writeByte((seq.flags & ShapeFlags.Cyclic) != 0 ? 1 : 0);
		out.writeByte((seq.flags & ShapeFlags.MakePath) != 0 ? 1 : 0);
		out.writeInt32(seq.priority);
		out.writeInt32(seq.firstGroundFrame);
		out.writeInt32(seq.numGroundFrames);
		out.writeInt32(seq.baseRotation);
		out.writeInt32(seq.baseObjectState);
		out.writeInt32(seq.baseDecalState);
		out.writeInt32(seq.firstTrigger);
		out.writeInt32(seq.numTriggers);
		out.writeInt32(Std.int(seq.toolBegin));

		writeOldBitSet(out, seq.rotationMatters);
		writeOldBitSet(out, seq.translationMatters);
		writeOldBitSet(out, seq.scaleMatters);
		writeOldBitSet(out, seq.decalMatters);
		writeOldBitSet(out, seq.iflMatters);
		writeOldBitSet(out, seq.visMatters);
		writeOldBitSet(out, seq.frameMatters);
		writeOldBitSet(out, seq.matFrameMatters);
	}

	function writeOldBitSet(out:BytesWriter, words:Array<Int>) {
		out.writeInt32(words.length);
		out.writeInt32(words.length);
		for (word in words)
			out.writeInt32(word);
	}
}
