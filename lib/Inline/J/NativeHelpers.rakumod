
use nqp;
use NativeCall;
use Exportable;

module Inline::J::NativeHelpers {

    # Copied from NativeHelpers::Blob:ver<0.1.12>:auth<github:salortiz>

    constant stdlib = Rakudo::Internals.IS-WIN ?? 'msvcrt' !! Str;

    sub blob-allocate(Blob:U \blob, $elems) is exportable {
        my \b = blob.new;
        nqp::setelems(b, nqp::unbox_i($elems.Int));
        b;
    }

    our sub blob-from-pointer(Pointer:D \ptr, Int :$elems!, Blob:U :$type = Buf) is exportable {
        my sub memcpy(Blob:D $dest, Pointer $src, size_t $size)
            returns Pointer is native(stdlib) { * };
        my \t = ptr.of ~~ void ?? $type.of !! ptr.of;
        if  nativesizeof(t) != nativesizeof($type.of) {
            fail "Pointer type don't match Blob type";
        }
        my $b = $type;
        with ptr {
            if $b.can('allocate') {
                $b .= allocate($elems);
            }
            else {
                $b = blob-allocate($b, $elems);
            }
            memcpy($b, ptr, $elems * nativesizeof(t));
        }
        $b;
    }

}
