package atlascreator;

import haxe.io.Path;
import haxe.ds.ReadOnlyArray;

typedef PageJson = {
    final image : String;
    final width : Int;
    final height : Int;
    final packed : Array<ImageJson>;
}

typedef ImageJson = {
    final file : String;
    final x : Int;
    final y : Int;
    final width : Int;
    final height : Int;
}

@:structInit class Image
{
	public final width : Int;
	
	public final height : Int;

	public final xPad : Int;

	public final yPad : Int;

	public final path : Path;
}

@:structInit class PackedImage extends Image
{
	public final x : Int;

	public final y : Int;
}

@:structInit class PackedPage
{
	public final path : Path;

	public final width : Int;

	public final height : Int;

	public final images : ReadOnlyArray<PackedImage>;
}