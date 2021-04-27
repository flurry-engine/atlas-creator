package atlascreator.cli;

import atlascreator.Types;
import atlascreator.Blit;
import sys.FileSystem;
import sys.io.File;
import haxe.Exception;
import haxe.io.Path;
import haxe.ds.ReadOnlyArray;
import binpacking.MaxRectsPacker;

using Lambda;

class AtlasCreator
{
#if (!no_atlascreator_cli)
	static function main()
	{
		tink.Cli.process(Sys.args(), new AtlasCreator()).handle(tink.Cli.exit);
	}
#end

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
	public var pot = false;

	/**
	 * If enabled the output atlas pages will not be png files but instead raw BGRA bytes.
	 */
	public var format = 'png';

	/**
	 * The format of the output file describing the packed images.
	 */
	@:flag('data-file') @:alias('s') public var dataFile = 'json';

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
		FileSystem.createDirectory(output);

		final files = FileSystem.readDirectory(directory)
			.map(f -> new Path(Path.join([ directory, f ])))
			.filter(f -> {
				final isFile = !FileSystem.isDirectory(f.toString());
				final isPng  = f.ext == 'png';

				return isFile && isPng;
			});
		final rects = [ for (f in files) readSize(f) ];
		final atlas = [];

		pack(rects, atlas, 0);		
		Blit.writeImages(atlas, threads);
		writeJson(atlas);
	}

	/**
	 * Prints this help document
	 */
	@:command public function help()
	{
#if (!no_atlascreator_cli)
		Sys.println(tink.Cli.getDoc(this));
#end
	}

	/**
	 * Opens a stream and seeks to the width and height bytes of the png header.
	 * Should probably be more robust and check for png magic bytes IHDR chunk.
	 * @param _path Path of the image to inspect.
	 * @return Immutable image object with the width, height, padding, and path inside.
	 */
	function readSize(_path : Path) : Image
	{
		final input = File.read(_path.toString());
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
	 * @param _pages All atlas pages generated thus far.
	 */
	function pack(_toPack : Array<Image>, _pages : Array<PackedPage>, _count : Int)
	{
		final packer   = new MaxRectsPacker(maxWidth, maxHeight, false);
		final unpacked = new Array<Image>();
		final packed   = new Array<PackedImage>();

		var accWidth  = 0;
		var accHeight = 0;
	
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
				// Manually track the maximum packed width and height
				// Will allow trimming the output image
				final xMost = Std.int(rect.x) + paddedWidth;
				final yMost = Std.int(rect.y) + paddedHeight;
				if (xMost > accWidth)
				{
					accWidth = xMost;
				}
				if (yMost > accHeight)
				{
					accHeight = yMost;
				}

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
	
		_pages.push({
			path   : new Path(Path.join([ output, '$name-$_count.$format' ])),
			width  : if (pot) nextPot(accWidth) else accWidth,
			height : if (pot) nextPot(accHeight) else accHeight,
			images : packed
		});
	
		if (unpacked.length > 0)
		{
			pack(unpacked, _pages, _count + 1);
		}
	}

	function writeJson(_pages : Array<PackedPage>)
	{
		switch dataFile
		{
			case 'json':
				File.saveContent(Path.join([ output, '$name.json' ]), tink.Json.stringify({
					name  : name,
					pages : [ for (i => page in _pages) writePage(page, i) ]
				}));
			case 'starling':
				for (i in 0..._pages.length)
				{
					final page = _pages[i];
					final root = Xml.createElement('TextureAtlas');
					root.set('imagePath', page.path.toString());
					root.set('width', Std.string(page.width));
					root.set('height', Std.string(page.height));

					for (image in page.images)
					{
						final child = Xml.createElement('SubTexture');
						child.set('name', image.path.file);
						child.set('x', Std.string(image.x + image.xPad));
						child.set('y', Std.string(image.y + image.yPad));
						child.set('width', Std.string(image.width));
						child.set('height', Std.string(image.height));

						root.addChild(child);
					}

					File.saveContent(Path.join([ output, '$name-$i.xml' ]), root.toString());
				}
		}
	}

	function writePage(_page : PackedPage, _index : Int) : PageJson
	{
		return {
			image  : '${ _page.path.file }.${ _page.path.ext }',
			width  : _page.width,
			height : _page.height,
			packed : [ for (r in _page.images) writeRect(r) ]
		}
	}

	function writeRect(_rect : PackedImage) : ImageJson
	{
		return {
			x      : _rect.x + _rect.xPad,
			y      : _rect.y + _rect.yPad,
			width  : _rect.width,
			height : _rect.height,
			file   : _rect.path.file
		}
	}

	/**
	 * Fetches the next power of two from the provided number.
	 * @param _in Input number.
	 * @return Int
	 */
	function nextPot(_in : Int) : Int
	{
		_in--;
		_in |= _in >> 1;
		_in |= _in >> 2;
		_in |= _in >> 4;
		_in |= _in >> 8;
		_in |= _in >> 16;
		_in++;

		return _in;
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
