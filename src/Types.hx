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