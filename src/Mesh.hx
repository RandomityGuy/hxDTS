package;

import haxe.Exception;
import math.Point2F;
import math.Point3F;
import math.Box3F;

@:expose
@:publicFields
class TSSortedMeshCluster {
	var startPrimitive:Int;
	var endPrimitive:Int;
	var normal:Point3F;
	var k:Float;
	var frontCluster:Int;
	var backCluster:Int;

	public function new() {}
}

@:expose
@:publicFields
class Mesh {
	var meshType:Int;
	var numFrames:Int;
	var numMatFrames:Int;
	var parent:Int;
	var bounds:Box3F;
	var center:Point3F;
	var radius:Float;
	var vertices:Array<Point3F>;
	var uv:Array<Point2F>;
	var normals:Array<Point3F>;
	var enormals:Array<Int>;
	var primitives:Array<Primitive>;
	var indices:Array<Int>;
	var mindices:Array<Int>;
	var vertsPerFrame:Int;
	var type:Int;
	var shape:DtsFile;
	var initialTransforms:Array<Array<Float>>;
	var vertexIndices:Array<Int>;
	var boneIndices:Array<Int>;
	var weights:Array<Float>;
	var nodeIndices:Array<Int>;

	// TSSortedMesh
	var clusters:Array<TSSortedMeshCluster>;
	var startCluster:Array<Int>;
	var firstVerts:Array<Int>;
	var numVerts:Array<Int>;
	var firstTVerts:Array<Int>;
	var alwaysWriteDepth:Bool;

	public function new() {}

	function readStandard(reader:DtsAlloc, version:Int) {
		reader.guard();

		numFrames = reader.readU32();
		numMatFrames = reader.readU32();
		parent = reader.readS32();
		bounds = reader.readBoxF();
		center = reader.readPoint3F();
		radius = reader.readF32();

		var numVerts = reader.readU32();
		vertices = [];
		if (this.parent < 0) {
			for (i in 0...numVerts) {
				vertices.push(reader.readPoint3F());
			}
		} else {
			vertices = shape.meshes[this.parent].vertices;
		}

		var numTVerts = reader.readU32();
		uv = [];
		if (this.parent < 0) {
			for (i in 0...numTVerts) {
				uv.push(reader.readPoint2F());
			}
		} else {
			uv = shape.meshes[this.parent].uv;
		}

		normals = [];
		if (this.parent < 0) {
			for (i in 0...numVerts) {
				normals.push(reader.readPoint3F());
			}
		} else {
			normals = shape.meshes[this.parent].normals;
		}

		enormals = [];
		if (this.parent < 0 && version > 21) {
			for (i in 0...numVerts) {
				enormals.push(reader.readU8());
			}
		}

		primitives = [];
		var numPrimitives = reader.readU32();
		for (i in 0...numPrimitives) {
			primitives.push(Primitive.read(reader));
		}

		indices = [];
		var numIndices = reader.readU32();
		for (i in 0...numIndices) {
			indices.push(reader.readS16());
		}

		mindices = [];
		var numMIndices = reader.readU32();
		for (i in 0...numMIndices) {
			mindices.push(reader.readS16());
		}

		vertsPerFrame = reader.readS32();
		type = reader.readS32();

		reader.guard();
	}

	function readSkinned(reader:DtsAlloc, version:Int) {
		readStandard(reader, version);

		var numVerts = reader.readS32();
		if (parent < 0) {
			vertices = [];
			for (i in 0...numVerts) {
				vertices.push(reader.readPoint3F());
			}
			normals = [];
			for (i in 0...numVerts) {
				normals.push(reader.readPoint3F());
			}
			if (parent < 0) {
				for (i in 0...numVerts) {
					reader.readU8();
				}
			}
			var sz = reader.readS32();
			initialTransforms = [];
			for (i in 0...sz) {
				initialTransforms.push(reader.readMatrixF());
			}

			sz = reader.readS32();
			vertexIndices = [];
			for (i in 0...sz) {
				vertexIndices.push(reader.readS32());
			}
			boneIndices = [];
			for (i in 0...sz) {
				boneIndices.push(reader.readS32());
			}
			weights = [];
			for (i in 0...sz) {
				weights.push(reader.readF32());
			}
			sz = reader.readS32();
			nodeIndices = [];
			for (i in 0...sz) {
				nodeIndices.push(reader.readS32());
			}
		} else {
			var other = this.shape.meshes[parent];
			if (other == null) {
				return;
			}
			vertices = other.vertices;
			normals = other.normals;
			if (parent < 0) {
				for (i in 0...numVerts) {
					reader.readU8();
				}
			}
			reader.readS32();
			initialTransforms = other.initialTransforms;
			reader.readS32();
			vertexIndices = other.vertexIndices;
			boneIndices = other.boneIndices;
			weights = other.weights;
			reader.readS32();
			nodeIndices = other.nodeIndices;
		}
		reader.guard();
	}

	function readSorted(reader:DtsAlloc, version:Int) {
		readStandard(reader, version);

		var numClusters = reader.readS32();
		clusters = [];
		for (i in 0...numClusters) {
			var cluster = new TSSortedMeshCluster();
			cluster.startPrimitive = reader.readS32();
			cluster.endPrimitive = reader.readS32();
			cluster.normal = reader.readPoint3F();
			cluster.k = reader.readF32();
			cluster.frontCluster = reader.readS32();
			cluster.backCluster = reader.readS32();
			clusters.push(cluster);
		}

		var sz = reader.readS32();
		startCluster = [];
		for (i in 0...sz) {
			startCluster.push(reader.readS32());
		}

		sz = reader.readS32();
		firstVerts = [];
		for (i in 0...sz) {
			firstVerts.push(reader.readS32());
		}

		sz = reader.readS32();

		numVerts = [];
		for (i in 0...sz) {
			numVerts.push(reader.readS32());
		}

		sz = reader.readS32();
		firstTVerts = [];
		for (i in 0...sz) {
			firstTVerts.push(reader.readS32());
		}

		alwaysWriteDepth = reader.readS32() != 0;

		reader.guard();
	}

	public static function read(shape:DtsFile, reader:DtsAlloc, version:Int) {
		var mesh = new Mesh();
		mesh.shape = shape;
		mesh.meshType = reader.readS32() & 7;

		if (mesh.meshType == 0)
			mesh.readStandard(reader, version);
		else if (mesh.meshType == 1)
			mesh.readSkinned(reader, version);
		else if (mesh.meshType == 3)
			mesh.readSorted(reader, version);
		else if (mesh.meshType == 4)
			return null;
		else
			throw new Exception("idk how to read this");

		return mesh;
	}

	function writeStandard(alloc:DtsWriteAlloc, version:Int) {
		alloc.guard();

		alloc.writeU32(numFrames);
		alloc.writeU32(numMatFrames);
		alloc.writeS32(parent);
		alloc.writeBoxF(bounds);
		alloc.writePoint3F(center);
		alloc.writeF32(radius);

		// Child meshes share their parent's geometry: the declared counts are
		// still written, but the data itself is omitted.
		var shared = parent >= 0;

		alloc.writeU32(vertices.length);
		if (!shared)
			for (v in vertices)
				alloc.writePoint3F(v);

		alloc.writeU32(uv.length);
		if (!shared)
			for (t in uv)
				alloc.writePoint2F(t);

		if (!shared)
			for (n in normals)
				alloc.writePoint3F(n);

		if (!shared && version > 21)
			for (i in 0...vertices.length)
				alloc.writeU8(i < enormals.length ? enormals[i] : 0);

		alloc.writeU32(primitives.length);
		for (p in primitives)
			p.write(alloc);

		alloc.writeU32(indices.length);
		for (i in indices)
			alloc.writeS16(i);

		alloc.writeU32(mindices.length);
		for (i in mindices)
			alloc.writeS16(i);

		alloc.writeS32(vertsPerFrame);
		alloc.writeS32(type);

		alloc.guard();
	}

	function writeSkinned(alloc:DtsWriteAlloc, version:Int) {
		writeStandard(alloc, version);

		alloc.writeS32(vertices.length);
		for (v in vertices)
			alloc.writePoint3F(v);
		for (n in normals)
			alloc.writePoint3F(n);
		for (i in 0...vertices.length)
			alloc.writeU8(i < enormals.length ? enormals[i] : 0);

		alloc.writeS32(initialTransforms.length);
		for (tr in initialTransforms)
			alloc.writeMatrixF(tr);

		alloc.writeS32(vertexIndices.length);
		for (vi in vertexIndices)
			alloc.writeS32(vi);
		for (bi in boneIndices)
			alloc.writeS32(bi);
		for (w in weights)
			alloc.writeF32(w);

		alloc.writeS32(nodeIndices.length);
		for (ni in nodeIndices)
			alloc.writeS32(ni);

		alloc.guard();
	}

	function writeSorted(alloc:DtsWriteAlloc, version:Int) {
		writeStandard(alloc, version);

		alloc.writeS32(clusters.length);
		for (c in clusters) {
			alloc.writeS32(c.startPrimitive);
			alloc.writeS32(c.endPrimitive);
			alloc.writePoint3F(c.normal);
			alloc.writeF32(c.k);
			alloc.writeS32(c.frontCluster);
			alloc.writeS32(c.backCluster);
		}

		alloc.writeS32(startCluster.length);
		for (sc in startCluster)
			alloc.writeS32(sc);

		alloc.writeS32(firstVerts.length);
		for (fv in firstVerts)
			alloc.writeS32(fv);

		alloc.writeS32(numVerts.length);
		for (nv in numVerts)
			alloc.writeS32(nv);

		alloc.writeS32(firstTVerts.length);
		for (ftv in firstTVerts)
			alloc.writeS32(ftv);

		alloc.writeS32(alwaysWriteDepth ? 1 : 0);

		alloc.guard();
	}

	public function write(alloc:DtsWriteAlloc, version:Int) {
		// The dispatch word is the mesh-type enum; the trailing "type" field
		// (flags) is written separately at the end of the standard body.
		alloc.writeS32(meshType);

		if (meshType == 0)
			writeStandard(alloc, version);
		else if (meshType == 1)
			writeSkinned(alloc, version);
		else if (meshType == 3)
			writeSorted(alloc, version);
		else
			throw new Exception("idk how to write this");
	}
}
