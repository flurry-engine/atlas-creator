package atlascreator;

import sys.io.File;
import haxe.io.Bytes;
import atlascreator.Types.PackedPage;
import atlascreator.Types.PackedImage;
import format.png.Tools as PngTools;
import format.png.Writer as PngWriter;
import format.png.Reader as PngReader;
import format.jpg.Writer as JpgWriter;
import hx.concurrent.thread.ThreadPool;

class Blit
{
    public static function writeImages(_pages : Array<PackedPage>, _threads : Int)
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
                
                switch page.path.ext
                {
                    case 'png':
                        final output = File.write(page.path.toString());
                        final writer = new PngWriter(output);
                        writer.write(PngTools.build32BGRA(4096, 4096, bytes));
                        output.close();
                    case 'raw':
                        File.saveBytes(page.path.toString(), bytes);
                    case 'jpeg', 'jpg':
                        final output = File.write(page.path.toString());
                        final writer = new JpgWriter(output);
                        writer.write({
                            width   : page.width,
                            height  : page.height,
                            quality : 90,
                            pixels  : { PngTools.reverseBytes(bytes); bytes; }
                        });
                        output.close();
                    case other:
                        throw '$other is not supported on the haxe blitter';
                }
            });
        }

        pool.awaitCompletion(-1);
        pool.stop();
    }

    static function blit(_image : PackedImage, _out : Bytes, _outWidth : Int)
    {
        final bpp    = 4;
        final input  = File.read(_image.path.toString());
        final reader = new PngReader(input);
        final pixels = PngTools.extract32(reader.read());
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
}