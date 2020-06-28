import sys.FileSystem;
import sys.io.File;
import haxe.Timer;
import haxe.io.Path;
import haxe.ds.ReadOnlyArray;
import binpacking.MaxRectsPacker;
import Blit;

using Lambda;

function main()
{
	final dir   = Sys.args()[0];
	final files = FileSystem.readDirectory(dir).map(f -> Path.join([ dir, f ]));
	final rects = [ for (f in files) readSize(f) ];
	final pages = [];

	pack(rects, pages);

	Timer.measure(() -> write(pages));
}

function readSize(_path) : Image
{
	final input = File.read(_path);
	input.bigEndian = true;

	input.seek(16, SeekBegin);
	final width = input.readInt32();
	input.seek(20, SeekBegin);
	final height = input.readInt32();

	input.close();

	return { width : width, height : height, path : _path }
}

function pack(_toPack : Array<Image>, _atlas : Array<PackedAtlas>)
{
	final maxWidth  = 4096;
	final maxHeight = 4096;
	final packer    = new MaxRectsPacker(maxWidth, maxHeight, false);

	final unpacked = new Array<Image>();
	final packed   = new Array<PackedImage>();

	for (size in _toPack)
	{
		if (size.width > maxWidth || size.height > maxHeight)
		{
			throw 'rectangle exceeds max page size';
		}

		final rect = packer.insert(size.width, size.height, BestShortSideFit);
		if (rect == null)
		{
			unpacked.push(size);
		}
		else
		{
			packed.push({
				path   : size.path,
				width  : size.width,
				height : size.height,
				x      : Std.int(rect.x),
				y      : Std.int(rect.y)
			});
		}
	}

	if (packed.length == 0)
	{
		throw 'failed to pack any images';
	}

	_atlas.push({
		width  : maxWidth,
		height : maxHeight,
		images : packed
	});

	if (unpacked.length > 0)
	{
		pack(unpacked, _atlas);
	}
}

@:structInit class Image
{
	public final width : Int;
	public final height : Int;
	public final path : String;
}

@:structInit class PackedImage extends Image
{
	public final x : Int;

	public final y : Int;
}

@:structInit class PackedAtlas
{
	public final width : Int;
	public final height : Int;
	public final images : ReadOnlyArray<PackedImage>;
}