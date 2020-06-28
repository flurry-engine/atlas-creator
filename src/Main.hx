import tink.Cli;
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
	Cli.process(Sys.args(), new AtlasCreator()).handle(Cli.exit);
}

class AtlasCreator
{
	@:flag('-d')
	public var directory : String;

	@:flag('-p')
	public var pot = true;

	@:flag('-w')
	public var maxWidth = 2048;

	@:flag('-h')
	public var maxHeight = 2048;

	@:flag('-x')
	public var xPad = 0;

	@:flag('-y')
	public var yPad = 0;

	@:flag('-t')
	public var threads = 8;

	public function new() {}

	@:defaultCommand
	public function create()
	{
		final files = FileSystem.readDirectory(directory)
			.map(f -> new Path(Path.join([ directory, f ])))
			.filter(f -> {
				final isFile = !FileSystem.isDirectory(f.toString());
				final isPng  = f.ext == 'png';

				return isFile && isPng;
			});
		final rects = [ for (f in files) readSize(f.toString()) ];
		final pages = [];

		pack(rects, pages);

		Timer.measure(() -> write(pages, threads));
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
	
		return {
			width  : width,
			height : height,
			xPad   : xPad,
			yPad   : yPad,
			path   : _path
		}
	}
	
	function pack(_toPack : Array<Image>, _atlas : Array<PackedAtlas>)
	{
		final maxWidth  = maxWidth;
		final maxHeight = maxHeight;
		final packer    = new MaxRectsPacker(maxWidth, maxHeight, false);
	
		final unpacked = new Array<Image>();
		final packed   = new Array<PackedImage>();
	
		for (size in _toPack)
		{
			if (size.width > maxWidth || size.height > maxHeight)
			{
				throw 'rectangle exceeds max page size';
			}
	
			final rect = packer.insert(size.width + (size.xPad * 2), size.height + (size.xPad * 2), BestShortSideFit);
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
					xPad   : size.xPad,
					yPad   : size.yPad,
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
}

@:structInit class Image
{
	public final width : Int;
	
	public final height : Int;

	public final xPad : Int;

	public final yPad : Int;

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