import sys.io.File;
import haxe.io.Bytes;
import Main.PackedAtlas;
import Main.PackedImage;
import format.png.Tools;
import format.png.Writer;
import format.png.Reader;
import hx.concurrent.thread.ThreadPool;

function write(_atlas : Array<PackedAtlas>)
{
	final pool = new ThreadPool(8);

	for (i => atlas in _atlas)
    {
        pool.submit(ctx -> {
            final bytes = Bytes.alloc(atlas.width * atlas.height * 4);

            for (image in atlas.images)
            {
                copy(image, bytes, atlas.width);
            }
    
            final output = File.write('out_$i.png');
            final writer = new Writer(output);
            writer.write(Tools.build32BGRA(4096, 4096, bytes));
            output.close();
        });
    }

    pool.awaitCompletion(-1);
    pool.stop();
}

/**
 * Pure haxe image blit implementation.
 * @param _image Packed image to blit.
 * @param _out Output image bytes.
 * @param _outWidth Pixel width of the output image.
 */
private function copy(_image : PackedImage, _out : Bytes, _outWidth : Int)
{
    final bpp    = 4;
    final input  = File.read(_image.path);
    final reader = new Reader(input);
    final pixels = Tools.extract32(reader.read());
    input.close();

    for (i in 0..._image.height)
    {
        final dstAddr = ((i + _image.y) * _outWidth * 4) + (_image.x * bpp);
        final srcAddr = (i * _image.width * bpp);
        final length  = _image.width * bpp;

        _out.blit(dstAddr, pixels, srcAddr, length);
    }
}
