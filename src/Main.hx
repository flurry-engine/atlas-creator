import sys.FileSystem;
import sys.io.File;
import haxe.Timer;
import haxe.Exception;
import haxe.io.Path;
import haxe.ds.ReadOnlyArray;
import tink.Cli;
import binpacking.MaxRectsPacker;
import Blit;

using Lambda;

function main()
{
	Cli.process(Sys.args(), new AtlasCreator()).handle(Cli.exit);
}

class AtlasCreator
{
	/**
	 * The directory to read png images from.
	 */
	public var directory = '';

	/**
	 * The directory to place all produced atlas images and the definition file.
	 */
	public var output = '';

	/**
	 * Name of the atlas.
	 * The produced json definition file will be `name.json` and the images will `name_$i.png`, where `$i` is the image index.
	 */
	public var name = 'atlas';

	/**
	 * If the output atlas images should be forced to a power of two.
	 */
	public var pot = true;

	/**
	 * The maximum width of a atlas texture.
	 */
	@:flag('width') public var maxWidth = 2048;

	/**
	 * The maximum height of a atlas texture.
	 */
	@:flag('height') public var maxHeight = 2048;

	/**
	 * Number of pixels to add to the left and right hand side of each packed image.
	 */
	@:flag('x-pad') public var xPad = 0;

	/**
	 * Number of pixels to add to the top and bottom of each packed image.
	 */
	@:flag('y-pad') public var yPad = 0;

	/**
	 * Number of threads to use when writing atlas pages.
	 */
	public var threads = 8;

	public function new() {}

	/**
	 * Packs a directory of png images into atlas images and produces a json file mapping each file packed to its location in the atlas.
	 * Multiple atlas images will be produced if needed to pack all the images.
	 */
	@:defaultCommand public function create()
	{
		final files = FileSystem.readDirectory(directory)
			.map(f -> new Path(Path.join([ directory, f ])))
			.filter(f -> {
				final isFile = !FileSystem.isDirectory(f.toString());
				final isPng  = f.ext == 'png';

				return isFile && isPng;
			});
		final rects = [ for (f in files) readSize(f.toString()) ];
		final atlas = [];

		pack(rects, atlas);

		Timer.measure(() -> write(atlas, threads));
	}

	/**
	 * Prints this help document
	 */
	@:command public function help()
	{
		Sys.println(Cli.getDoc(this));
	}

	/**
	 * Opens a stream and seeks to the width and height bytes of the png header.
	 * Should probably be more robust and check for png magic bytes IHDR chunk.
	 * @param _path Path of the image to inspect.
	 * @return Immutable image object with the width, height, padding, and path inside.
	 */
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
	
	/**
	 * Recursivly packs images into as many atlases as needed until all have been processed.
	 * @throws ImageTooLargeException When a padded image exceeds the maximum atlas size.
	 * @throws NoImagesPackedException When a iteration fails to pack any images for some reason.
	 * @param _toPack The remaining images to be packed.
	 * @param _atlas All atlases generated thus far.
	 */
	function pack(_toPack : Array<Image>, _atlas : Array<PackedAtlas>)
	{
		final packer   = new MaxRectsPacker(maxWidth, maxHeight, false);
		final unpacked = new Array<Image>();
		final packed   = new Array<PackedImage>();
	
		for (size in _toPack)
		{
			final paddedWidth  = size.width + (size.xPad * 2);
			final paddedHeight = size.height + (size.yPad * 2);

			if (size.width > paddedWidth || size.height > paddedHeight)
			{
				throw new ImageTooLargeException(paddedWidth, paddedHeight, maxWidth, maxHeight);
			}
	
			final rect = packer.insert(paddedWidth, paddedHeight, BestShortSideFit);
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
			throw new NoImagesPackedException();
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

class ImageTooLargeException extends Exception
{
	public function new(_width : Int, _height : Int, _maxWidth : Int, _maxHeight : Int)
	{
		super('image of size $_width x $_height exceeds the maximum page size of $_maxWidth x $_maxHeight');
	}
}

class NoImagesPackedException extends Exception
{
	public function new()
	{
		super('No images were packed in this iteration');
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
