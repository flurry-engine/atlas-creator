import haxe.io.Bytes;
import Main.PackedAtlas;
import Main.PackedImage;
import stb.Image;
import stb.ImageWrite;
import hx.concurrent.thread.ThreadPool;

function write(_atlas : Array<PackedAtlas>, _threads : Int)
{
    final pool = new ThreadPool(_threads);

    for (i => atlas in _atlas)
    {
        pool.submit(ctx -> {
            final bpp   = 4;
            final bytes = Bytes.alloc(atlas.width * atlas.height * bpp);

            for (image in atlas.images)
            {
                copy(image, bytes, atlas.width);
            }
    
            ImageWrite.write_png('out_$i.png', atlas.width, atlas.height, bpp, bytes.getData(), 0, bytes.length, atlas.width * bpp);
        });
    }

    pool.awaitCompletion(-1);
    pool.stop();
}

private function copy(_image : PackedImage, _out : Bytes, _outWidth : Int)
{
    final data = Image.load(_image.path, 4);
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