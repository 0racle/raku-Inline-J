use Exportable;

module Inline::J::Utils {

    #| accepts: list of values, optional shape
    #| returns: batched Seq
    our sub batched(@a is copy, :@shape) is exportable {
        for @shape.reverse -> $dim {
            @a .= batch($dim);
        }
        return |@a
    }

    #| accepts: list of values, a type, and optional shape
    #| returns: shaped Array of type
    our sub shaped(@a, :$type!, :@shape) is exportable {
        Array[$type].new(batched(@a, :@shape), :@shape)
    }

    our sub reshape($a) is exportable {
        Array.new(shape => infer-shape(|$a), |$a)
    }
    sub infer-shape($x) {
        $x ~~ List ?? ($x.elems, |infer-shape($x[0])) !! ()
    }

    our sub hex-unpack($hex) is exportable {
        $hex.comb(2).reverse.join.parse-base(16)
    }


}

