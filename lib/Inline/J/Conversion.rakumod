unit module Inline::J::Conversion;

use NativeCall;
use NativeHelpers::Blob;

use Inline::J::Utils < batched shaped reshape hex-unpack >;
use Inline::J::Datatype;

our sub setm-values($a) {

    # XXX unshaped/untyped Arrays currently unsupported
    # but potentially we can infer the shape / type
    # requires further testing / development

    # # Assume unshaped Arrays have homogenous shape
    # if $a.shape.head ~~ Whatever {
    #     return setm-values(reshape(|$a))
    # }

    # # Assume untyped Arrays have homogeneous type
    # if $a.of.^name eq 'Mu' {
    #     return setm-values(shaped($a, shape => $a.shape, type => $a.head.WHAT));
    # }

    my int64 $rank  = $a.shape.elems;
    my int64 $shape = nativecast(Pointer[int64], CArray[int64].new($a.shape));

    my int64 ($type, $data) = do given $a.of {
        when Bool {
            Inline::J::Datatype::boolean,
            nativecast(Pointer[int8], CArray[int8].new($a.List)).Int;
        }
        when Str {
            my @ords = $a.map(&ord);
            if @ords.first(* > 255) {  # UTF-16
                Inline::J::Datatype::unicode,
                nativecast(Pointer[int16], CArray[int16].new(@ords)).Int;
            }
            else {
                Inline::J::Datatype::literal,
                nativecast(Pointer[int8], CArray[int8].new(@ords)).Int;
            }
        }
        when Int {
            Inline::J::Datatype::integer,
            nativecast(Pointer[uint64], CArray[uint64].new($a.List)).Int;
        }
        when Num {
            Inline::J::Datatype::floating,
            nativecast(Pointer[num64], CArray[num64].new($a.List)).Int;
        }
        default {
            fail("{Inline::J::Datatype($type)} values are currently unsupported for setm");
        }
    }

    return ($type, $rank, $shape, $data);
}

our sub getm-data($type, $rank, $shape, $data, :$raw) {
    my $shape-buf = blob-from-pointer(Pointer.new($shape), elems => $rank × 8);
    my @shape = (0 ..^ $rank).map(-> $o { $shape-buf.read-int64($o × 8) });
    my $elems = [×] @shape;
    return getm-conv(Inline::J::Datatype($type), $data, $elems, @shape, :$raw);

}

proto sub getm-conv(|) { * }

multi getm-conv(Inline::J::Datatype::boolean, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), :$elems);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::boolean)
    }
    if !@shape {
        return $buf.read-int8(0).Bool
    }
    return shaped((0 ..^ $elems).map(-> $o { Bool($buf.read-int8($o)) }), :@shape, :type(Bool));
}

multi getm-conv(Inline::J::Datatype::literal, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), :$elems);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::literal)
    }
    my $str = $buf.decode('UTF8');
    if !@shape {
        return $str
    }
    return shaped($str.comb, :@shape, :type(Str));
}

multi getm-conv(Inline::J::Datatype::integer, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 8);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::Datatype::integer)
    }
    if !@shape {
        return $buf.read-int64(0).Int
    }
    return shaped((0 ..^ $elems).map(-> $o { $buf.read-int64($o × 8) }), :@shape, :type(Int));
}

multi getm-conv(Inline::J::Datatype::floating, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 8);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::floating)
    }
    if !@shape {
        return $buf.read-num64(0).Num
    }
    return shaped((0 ..^ $elems).map(-> $o { $buf.read-num64($o × 8) }), :@shape, :type(Num));
}

multi getm-conv(Inline::J::Datatype::complex, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 16);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::complex)
    }
    fail("{Inline::J::Datatype::complex} values unsupported. Use :raw");
}

# TODO Figure out extended data representation
# multi getm-conv(Inline::J::Datatype::extended, $data, $elems, @shape, :$raw) { !!! }

# TODO Figure out rational data representation
# multi getm-conv(Inline::J::Datatype::rational, $data, $elems, @shape, :$raw) { !!! }

multi getm-conv(Inline::J::Datatype::unicode, $data, $elems, @shape, :$raw) {
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 2);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::unicode)
    }
    my $str = $buf.decode('UTF-16');
    if !@shape {
        return $str
    }
    return shaped($str.comb, :@shape, :type(Str));
}

multi getm-conv(Inline::J::Datatype::unicode4, $data, $elems, @shape, :$raw) {
    # XXX Rakudo currently does not have a UTF-32 decoder
    my $buf = blob-from-pointer(Pointer.new($data), elems => $elems × 4);
    if $raw {
        return %(:$elems, :@shape, :$buf, datatype => Inline::J::Datatype::unicode4)
    }
    fail("{Inline::J::Datatype::unicode4} values unsupported. Use :raw");
}

multi getm-conv(Inline::J::Datatype::boxed, $data, $elems, @shape, :$raw) {
    if $raw {
        return %(:$elems, :@shape, :$data, datatype => Inline::J::Datatype::boxed)
    }
}

multi getm-conv($type, |c) {
    fail("{Inline::J::Datatype($type)} values are currently unsupported for getm");
}

our sub gets-data($type, $tally, $dims, @data, :$raw, :$list) {
    my $datatype = Inline::J::Datatype(hex-unpack($type));
    my $elems = hex-unpack($tally);
    my @shape = @data.splice(0, hex-unpack($dims)).map(&hex-unpack);
    my $buf = Buf.new(@data.map(|*.comb(2).map(*.parse-base(16))));

    return %(:$elems, :@shape, :$buf, :$datatype) if $raw;

    given $datatype {
        when boolean {
            return $buf.read-int8(0).Bool if !@shape;
            my $bools = (^$elems).map(-> $o { $buf.read-int8($o).Bool });
            return $list
              ?? batched($bools, :@shape)
              !! shaped($bools, :@shape, :type(Bool))
        }
        when literal {
            my $str = $buf.decode;
            return $str if !@shape;
            return $list
              ?? batched($str.comb.head($elems), :@shape)
              !! shaped($str.comb.head($elems), :@shape, :type(Str))
        }
        when integer {
            return $buf.read-int64(0) if !@shape;
            my $ints = (^$elems).map(-> $o { $buf.read-int64($o × 8) });
            return $list
              ?? batched($ints, :@shape)
              !! shaped($ints, :@shape, :type(Int))
        }
        when floating {
            return $buf.read-num64(0) if !@shape;
            my $nums = (^$elems).map(-> $o { $buf.read-num64($o × 8) });
            return $list
              ?? batched($nums, :@shape)
              !! shaped($nums, :@shape, :type(Num))
        }
        when unicode {
            my $str = $buf.decode('UTF-16');
            return $str if !@shape;
            return $list
              ?? batched($str.comb.head($elems), :@shape)
              !! shaped($str.comb.head($elems), :@shape)
        }
        default {
            fail("{$datatype} values are currently unsupported for gets");
        }
    }
}
