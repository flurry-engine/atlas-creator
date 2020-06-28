import sys.io.File;
import haxe.io.Bytes;
import Main.PackedPage;
import Main.PackedImage;
import format.png.Tools;
import format.png.Writer;
import format.png.Reader;
import hx.concurrent.thread.ThreadPool;

function writeImages(_pages : Array<PackedPage>, _threads : Int)
{
	final pool = new ThreadPool(_threads);

	for (page in _pages)
    {
        pool.submit(ctx -> {
            final bytes = Bytes.alloc(page.width * page.height * 4);

            for (image in page.images)
            {
                blit(image, bytes, page.width);
            }
    
            final output = File.write(page.path.toString());
            final writer = new Writer(output);
            writer.write(Tools.build32BGRA(4096, 4096, bytes));
            output.close();
        });
    }

    pool.awaitCompletion(-1);
    pool.stop();
}

private function blit(_image : PackedImage, _out : Bytes, _outWidth : Int)
{
    final bpp    = 4;
    final input  = File.read(_image.path.toString());
    final reader = new Reader(input);
    final pixels = Tools.extract32(reader.read());
    final srcX   = _image.x + _image.xPad;
    final srcY   = _image.y + _image.yPad;
    input.close();

    for (i in 0..._image.height)
    {
        final dstAddr = ((i + srcY) * _outWidth * 4) + (srcX * bpp);
        final srcAddr = (i * _image.width * bpp);
        final length  = _image.width * bpp;

        _out.blit(dstAddr, pixels, srcAddr, length);
    }
}
