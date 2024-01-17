unit module Inline::J::Conversion;

use NativeCall;

use Inline::J::Utils < batched shaped reshape hex-unpack utf32-to-utf8 >;
use Inline::J::NativeHelpers < blob-from-pointer >;
use Inline::J::Datatype;

our proto setm-values(|) {*}

multi sub setm-values(Int $n) {
    return (Inline::J::Datatype::integer, 0, 0,
            nativecast(Pointer, CArray[uint64].new($n.List)).Int);
}

multi sub setm-values(Num(Real) $n) {
    return (Inline::J::Datatype::floating, 0, 0,
            nativecast(Pointer, CArray[num64].new($n.List)).Int);
}

multi sub setm-values(Str $s) {
    return setm-values($s.comb);
}

multi sub setm-values(Array() $a) {

    # XXX Will attempt to infer shape/type of unshaped/untyped lists
    # Assume unshaped Arrays have homogenous shape
    if $a.shape.head ~~ Whatever {
        return setm-values(reshape($a))
    }
    # Assume untyped Arrays have homogeneous type
    if $a.of.^name eq 'Mu' {
        return setm-values(shaped($a, shape => $a.shape, type => $a[*].head.WHAT));
    }

    my int64 $rank  = $a.shape.elems;
    my int64 $shape = nativecast(Pointer, CArray[int64].new($a.shape));

    my int64 ($type, $data) = do given $a.of {
        when Bool {
            Inline::J::Datatype::boolean,
            nativecast(Pointer, CArray[int8].new($a.List)).Int;
        }
        when Str {
            my @ords = $a.map(&ord);
            given @ords.max -> \n {
                when n > 65535 {  # UTF-32
                    Inline::J::Datatype::unicode4,
                    nativecast(Pointer, CArray[int32].new(@ords)).Int;
                }
                when n > 255 {    # UTF-16
                    Inline::J::Datatype::unicode,
                    nativecast(Pointer, CArray[int16].new(@ords)).Int;
                }
                default {
                    Inline::J::Datatype::literal,
                    nativecast(Pointer, CArray[int8].new(@ords)).Int;
                }
            }
        }
        when Int {
            Inline::J::Datatype::integer,
            nativecast(Pointer, CArray[uint64].new($a.List)).Int;
        }
        when Num {
            Inline::J::Datatype::floating,
            nativecast(Pointer, CArray[num64].new($a.List)).Int;
        }
        default {
            my $datatype = Inline::J::Datatype($type);
            fail("$datatype values are currently unsupported for setm");
        }
    }

    return ($type, $rank, $shape, $data);
}

our sub getm-data($type, $rank, $shape, $data, :$shaped=True, :$raw) {
    my $shape-buf = blob-from-pointer(Pointer.new($shape), elems => $rank × 8);
    my @shape = (0 ..^ $rank).map(-> $o { $shape-buf.read-int64($o × 8) });
    my $elems = [×] @shape;
    return getm-conv(Inline::J::Datatype($type), $data, $elems, @shape, :$shaped, :$raw);

}

our sub geta-data($type, $data, $elems, @shape, :$shaped=True, :$raw) {
    return getm-conv(Inline::J::Datatype($type), $data, $elems, @shape, :$shaped, :$raw);
}

proto sub getm-conv(|) { * }

multi getm-conv(Inline::J::Datatype::boolean, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), :$elems);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::boolean
        )
    }
    if !@shape {
        return $buf.read-int8(0).Bool
    }
    my $bools = (0 ..^ $elems).map(-> $o { Bool($buf.read-int8($o)) });
    return $shaped
      ?? shaped($bools, :@shape, :type(Bool))
      !! batched($bools, :@shape)
}

multi getm-conv(Inline::J::Datatype::literal, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), :$elems);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::literal
        )
    }
    my $str = $buf.decode('UTF8');
    if !@shape {
        return $str
    }
    return $shaped
      ?? shaped($str.comb, :@shape, :type(Str))
      !! batched($str.comb, :@shape)
}

multi getm-conv(Inline::J::Datatype::integer, Int $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 8);
    getm-conv(Inline::J::Datatype::integer, $buf, $elems, @shape, :$shaped, :$raw)
}

multi getm-conv(Inline::J::Datatype::integer, Buf $data, $elems, @shape, :$shaped, :$raw) {
    if $raw {
        return %(
            :$elems, :@shape, :$data,
            datatype => Inline::J::Datatype::Datatype::integer
        )
    }
    if !@shape {
        return $data.read-int64(0).Int
    }
    my $ints = (0 ..^ $elems).map(-> $o { $data.read-int64($o × 8) });
    return $shaped
      ?? shaped($ints, :@shape, :type(Int))
      !! batched($ints, :@shape)
}

multi getm-conv(Inline::J::Datatype::floating, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 8);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::floating
        )
    }
    if !@shape {
        return $buf.read-num64(0).Num
    }
    my $nums = (0 ..^ $elems).map(-> $o { $buf.read-num64($o × 8) });
    return $shaped
      ?? shaped($nums, :@shape, :type(Num))
      !! batched($nums, :@shape)
}

multi getm-conv(Inline::J::Datatype::complex, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 16);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::complex
        )
    }
    fail("{Inline::J::Datatype::complex} values unsupported.");
}

# TODO Figure out extended data representation
# multi getm-conv(Inline::J::Datatype::extended, $data, $elems, @shape, *%_) { !!! }

# TODO Figure out rational data representation
# multi getm-conv(Inline::J::Datatype::rational, $data, $elems, @shape, *%_) { !!! }

multi getm-conv(Inline::J::Datatype::unicode, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 2);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::unicode
        )
    }
    my $str = $buf.decode('UTF-16');
    if !@shape {
        return $str
    }
    return $shaped
      ?? shaped($str.comb, :@shape, :type(Str))
      !! batched($str.comb, :@shape)
}

multi getm-conv(Inline::J::Datatype::unicode4, $data, $elems, @shape, :$shaped, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 4);
    if $raw {
        return %(
            :$elems, :@shape, :$buf,
            datatype => Inline::J::Datatype::unicode4
        )
    }
    my $str = utf32-to-utf8($buf);
    return $shaped
      ?? shaped($str.comb, :@shape, :type(Str))
      !! batched($str.comb, :@shape)
}

multi getm-conv(Inline::J::Datatype::boxed, $data, $elems, @shape, :$shaped, :$raw) {
    if $raw {
        return %(
            :$elems, :@shape, :$data,
            datatype => Inline::J::Datatype::boxed
        )
    }
    fail("{Inline::J::Datatype::complex} values unsupported.");
}

multi getm-conv($type, |c) {
    my $datatype = Inline::J::Datatype($type);
    fail("$datatype values are currently unsupported for getm");
}

our sub gets-data($type, $tally, $dims, @data, $expr, :$shaped=True, :$raw) {
    my $datatype = Inline::J::Datatype(hex-unpack($type));
    my $elems = hex-unpack($tally);
    my @shape = @data.splice(0, hex-unpack($dims)).map(&hex-unpack);
    my $buf = Buf.new(@data.map(|*.comb(2).map(*.parse-base(16))));

    return %(:$elems, :@shape, :$buf, :$datatype) if $raw;

    given $datatype {
        when Inline::J::Datatype::boolean {
            return $buf.read-int8(0).Bool if !@shape;
            my $bools = (^$elems).map(-> $o { $buf.read-int8($o).Bool });
            return $shaped
              ?? shaped($bools, :@shape, :type(Bool))
              !! batched($bools, :@shape)
        }
        when Inline::J::Datatype::literal {
            my $str = $buf.decode;
            return $str if !@shape;
            return $shaped
              ?? shaped($str.comb.head($elems), :@shape, :type(Str))
              !! batched($str.comb.head($elems), :@shape)
        }
        when Inline::J::Datatype::integer {
            return $buf.read-int64(0) if !@shape;
            my $ints = (^$elems).map(-> $o { $buf.read-int64($o × 8) });
            return $shaped
              ?? shaped($ints, :@shape, :type(Int))
              !! batched($ints, :@shape)
        }
        when Inline::J::Datatype::floating {
            return $buf.read-num64(0) if !@shape;
            my $nums = (^$elems).map(-> $o { $buf.read-num64($o × 8) });
            return $shaped
              ?? shaped($nums, :@shape, :type(Num))
              !! batched($nums, :@shape)
        }
        when Inline::J::Datatype::unicode {
            my $str = $buf.decode('UTF-16');
            return $str if !@shape;
            return $shaped
              ?? shaped($str.comb.head($elems), :@shape, :type(Str))
              !! batched($str.comb.head($elems), :@shape)
        }
        when Inline::J::Datatype::unicode4 {
            my $str = utf32-to-utf8($buf);
            return $str if !@shape;
            return $shaped
              ?? shaped($str.comb.head($elems), :@shape, :type(Str))
              !! batched($str.comb.head($elems), :@shape)
        }
        default {
            fail("{$datatype} values are currently unsupported for gets");
        }
    }
}
