use NativeCall;

use Inline::J::Datatype;
use Inline::J::Helper;
use Inline::J::Conversion;

our constant BIN = Inline::J::Helper::get-binpath();
our constant LIB = Inline::J::Helper::get-library(BIN);
our constant PRO = Inline::J::Helper::get-profile(BIN);

sub JInit() returns Pointer is native(LIB) { * }
sub JDo(Pointer, Str) returns int64 is native(LIB) { * }
sub JGetR(Pointer) returns Str is native(LIB) { * }
sub JGetA(Pointer, int64, Str) returns int64 is native(LIB) { * }
sub JFree(Pointer) returns int64 is native(LIB) { * }
sub JGetLocale(Pointer) returns Str is native(LIB) { * }
sub JGetM(Pointer, Str, int64 is rw, int64 is rw, int64 is rw, int64 is rw) returns int64 is native(LIB) { * } 
sub JSetM(Pointer, Str, int64 is rw, int64 is rw, int64 is rw, int64 is rw) returns int64 is native(LIB) { * } 
sub JErrorTextM(Pointer, int64, Pointer[Str] is rw) returns int64 is native(LIB) { * }

class Inline::J::Noun { ... }
class Inline::J::Verb { ... }

class Inline::J:ver<0.1.1>:auth<zef:elcaro> {
    has $!jt;
    has Bool $!profile-loaded;
    
    submethod BUILD($!jt=JInit(), :$load-profile) {
        # Increase output rows (for 3!:3)
        self.eval('(9!:37) 0 2256 0 2222');
        if $load-profile {
            self.load-profile;
        }
    }

    method load-profile(:$binpath=BIN, :$profile=PRO) {
        if not $!profile-loaded {
            self.do("0!:0<'$profile'[BINPATH_z_=:'$binpath'[ARGV_z_=:''");
            $!profile-loaded = True;
        }
        return self
    }

    method datatypes {
        Inline::J::Datatype.enums
    }

    method do(Str() $expr) {
        my $ec = JDo($!jt, $expr);
        if $ec ≠ 0 {
            my $err-text = self.error-text($ec);
            fail(qq:to<END>);
            |$err-text
            |   $expr
            END
        }
        return self
    }

    method getr() {
        return JGetR($!jt).chomp
    }

    method get-locale() {
        return JGetLocale($!jt)
    }

    method eval(|c) {
        return self.do(|c).getr
    }

    method error-text($err) {
        JErrorTextM($!jt, $err, my $p = Pointer[Str].new);
        return $p.deref;
    }

    multi method noun($init, :$name) {
        return Inline::J::Noun.new(:$init, :$name, ij => self);
    }
    multi method noun(:$name) {
        return Inline::J::Noun.new(:$name, ij => self);
    }

    method verb($init, :$name) {
        return Inline::J::Verb.new(:$init, :$name, ij => self);
    }

    method setm(Str $name, Array $a) {
        my int64 ($type, $rank, $shape, $data) = Inline::J::Conversion::setm-values($a);
        my $error = JSetM($!jt, $name, $type, $rank, $shape, $data);
        if $error ≠ 0 {
            fail(self.error-text($error));
        }
        return Inline::J::Noun.new(:$name, ij => self);
    }

    method getm($n, :$raw) {
        my $error = JGetM($!jt, $n, |my int64 ($type, $rank, $shape, $data));
        if $error ≠ 0 {
            fail("{ self.error-text($error) }: Name does not exist");
        }
        return Inline::J::Conversion::getm-data($type, $rank, $shape, $data, :$raw);
    }

    #| Parse the data representation given from `(3!:3), rather than use `JGetM`
    #| This allows the ability to return Raku data structures from J expressions
    #| without first having to define a noun on the J side
    #| NB. libj also offers the `JGetA` routine to return a byte representation
    #| but it also requires that the noun already exists in J.
    method gets($expr, |c) {
        my ($, $type, $tally, $dims, *@data) = self.eval("(3!:3) $expr").lines;
        return Inline::J::Conversion::gets-data($type, $tally, $dims, @data, |c);
    }

    method free() {
        JFree($!jt)
    }

    submethod DESTROY() {
        self.free
    }

}

my sub random-hex(\n) {
    (0..255).roll(n).map(*.fmt('%02x')).join;
}

class Inline::J::Noun {
    has $.name;
    has $!init;
    has Inline::J $!ij;

    submethod BUILD(:$!name, :$!init, :$!ij) {
        $!name ||= 'ijn_' ~ random-hex(4);
        if $!init {
            $!ij.do("$!name =. $!init");
        }
    }

    multi method gist(::?CLASS:D:) {
        $!ij.do($!name).getr;
    }

    method Str {
        $!name
    }

    method !monadic($f) {
        $!ij.eval("$f $!name");
    }

    method datatype {
        Inline::J::Datatype(self!monadic('(3!:0)'))
    }

    method shape() {
        self!monadic('$').words.map(*.Int)
    }

    method tally() {
        self!monadic('#').Int
    }

    method rank() {
        self!monadic('#@$').Int
    }

    method elems() {
        self!monadic('*/@$').Int
    }

    method AT-POS(*@n) {
        self!monadic("(<@n[]) \{")
    }

    method getm(|c) {
        $!ij.getm($!name, |c);
    }
    method gets(|c) {
        $!ij.gets($!name, |c);
    }

    method setm(|c) {
        $!ij.setm($!name, |c);
    }

    #| Erases name in J
    submethod DESTROY {
        $!ij.do("(4!:55) <'$!name'")
    }

}

class Inline::J::Verb does Callable {
    has $.name;
    has $!init;
    has Inline::J $!ij;

    submethod BUILD(:$!name, :$!init, :$!ij) {
        $!name ||= 'ijv_' ~ random-hex(4);
        $!ij.do("$!name =: $!init");
        if $!ij.eval("(4!:0) < '$!name'") ≠ 3 {
            die('Not a verb')
        }
    }

    method Str {
        $!name
    }

    multi submethod CALL-ME() {
        $!ij.noun("($!name) ''")
    }
    multi submethod CALL-ME(Inline::J::Noun $y) {
        $!ij.noun("($!name) $y")
    }
    multi submethod CALL-ME(Inline::J::Noun $x, Inline::J::Noun $y) {
        $!ij.noun("$x ($!name) $y")
    }
    multi submethod CALL-ME(Real $y) {
        $!ij.noun("($!name) $y")
    }
    multi submethod CALL-ME(Real $x, Real $y) {
        $!ij.noun("$x ($!name) $y")
    }
    multi submethod CALL-ME(Array[Int] $y where *.shape.elems == 1) {
        $!ij.noun("($!name) ($y)")
    }

    method rank {
        $!ij.eval("$!name b. 0")
    }

    method atop(Inline::J::Verb $f) {
        self.new(init => $!name ~ '@:' ~ $f.name, :$!ij)
    }

    #| minimum args
    method arity { 1 }

    #| maximum args
    method count { 2 }

}

multi infix:<∘>(Inline::J::Verb $f, Inline::J::Verb $g) is export {
    return $f.atop($g)
}
