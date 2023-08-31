use Exportable;

module Inline::J::Utils {

    #| accepts: list of values, optional shape
    #| returns: nested Array
    our sub batched(@a is copy, :@shape is copy) is exportable {
        for @shape.skip.reverse {
            @a = @a.batch(@shape.pop).map(*.Array)
        }
        return @a;
    }

    #| accepts: list of values, a type, and optional shape
    #| returns: shaped Array of type
    our sub shaped(@a, :$type!, :@shape) is exportable {
        Array[$type].new(batched(@a, :@shape), :@shape)
    }

    our sub reshape($a) is exportable {
        Array.new($a, shape => infer-shape($a))
    }

    our sub infer-shape($x) is exportable {
        $x ~~ List ?? ($x.elems, |infer-shape($x[0])) !! ()
    }

    our proto hex-unpack(|) is exportable { * }
    our multi hex-unpack($hex, $endian=LittleEndian) {
        $hex.comb(2).reverse.join.parse-base(16)
    }
    our multi hex-unpack($hex, BigEndian) {
        $hex.comb(2).join.parse-base(16)
    }

    our sub utf32-to-utf8(Buf $buf) is exportable {
        Buf.new(
            |(0 ..^ $buf.bytes ÷ 4).map: -> \i {
                given $buf.read-uint32(i × 4)  -> \c {
                    when c < 128 { c } 
                    when c < 2048 {
                        (192 +| (c +> 6)),
                        (128 +| (c +& 63))
                    }
                    when c < 65536 {
                        (224 +| (c +> 12)),
                        (128 +| ((c +> 6) +& 63)),
                        (128 +| (c +& 63))
                    }
                    when c < 2097152 {
                        (240 +| (c +> 18)),
                        (128 +| ((c +> 12) +& 63)),
                        (128 +| ((c +> 6) +& 63)),
                        (128 +| (c +& 63))
                    }
                }
            }
        ).decode
    }

}

