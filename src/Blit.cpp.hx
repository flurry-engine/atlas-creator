import sys.io.File;
import haxe.io.Bytes;
import Main.PackedPage;
import Main.PackedImage;
import stb.Image;
import stb.ImageWrite;
import hx.concurrent.thread.ThreadPool;

function writeImages(_pages : Array<PackedPage>, _threads : Int)
{
    final pool = new ThreadPool(_threads);

    for (page in _pages)
    {
        pool.submit(ctx -> {
            final bpp   = 4;
            final bytes = Bytes.alloc(page.width * page.height * bpp);

            for (image in page.images)
            {
                blit(image, bytes, page.width);
            }

            if (page.path.ext == 'raw')
            {
                final ptr = cpp.Pointer.arrayElem(bytes.getData(), 0);

                for (i in 0...page.width * page.height)
                {
                    // image_stb stores in RGBA but we want BGRA

                    final offset = i * bpp;
                    final r = ptr[offset];

                    ptr[offset + 0] = ptr[offset + 2];
                    ptr[offset + 2] = r;
                }

                File.saveBytes(page.path.toString(), bytes);
            }
            else
            {
                ImageWrite.write_png(page.path.toString(), page.width, page.height, bpp, bytes.getData(), 0, bytes.length, page.width * bpp);
            }
        });
    }

    pool.awaitCompletion(-1);
    pool.stop();
}

private function blit(_image : PackedImage, _out : Bytes, _outWidth : Int)
{
    final data = Image.load(_image.path.toString(), 4);
    final raw  = data.bytes;
    final bpp  = data.req_comp;
    final dst  = _out.getData();
    final srcX = _image.x + _image.xPad;
    final srcY = _image.y + _image.yPad;

    for (i in 0..._image.height)
    {
        final dstAddr = ((i + srcY) * _outWidth * 4) + (srcX * bpp);
        final srcAddr = (i * _image.width * bpp);
        final length  = _image.width * bpp;
        
        cpp.Native.memcpy(
            cpp.Pointer.arrayElem(dst, dstAddr).ptr,
            cpp.Pointer.arrayElem(raw, srcAddr).ptr,
            length);
    }
}