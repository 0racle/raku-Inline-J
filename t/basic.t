#!/usr/bin/env raku

use Test;
use Inline::J;

my \j  = Inline::J.new;

subtest 'eval' => {
    is j.eval('1 + 1'), '2', 'simple expresion';
    is j.eval('i. 10'), '0 1 2 3 4 5 6 7 8 9', 'primitives 1';
    is j.eval('*/~ >: i. 4'), qq:to<END>.chomp, 'primitives 2';
    1 2  3  4
    2 4  6  8
    3 6  9 12
    4 8 12 16
    END
}

# subtest 'j nouns' => { }
# subtest 'j verbs' => { }

subtest 'getm' => {
    is-deeply j.noun('0').getm, False, 'boolean 0';
    is-deeply j.noun('1').getm, True, 'boolean 1';
    is-deeply j.noun('2').getm, 2, 'integer';
    is-deeply j.noun('9 % 3').getm, 3e0, 'floating';
    is-deeply j.noun("'A'").getm, 'A', 'literal';

    is-deeply j.noun("7&u: 'Á'").getm,
              Array[Str].new('Á', :shape(1)),
              'unicode';
    is-deeply j.noun('0 = 2 | i. 4').getm,
              Array[Bool].new(:shape(4), [True, False, True, False]),
              'boolean array';
    is-deeply j.noun('i. 4').getm,
            Array[Int].new(:shape(4), ^4),
            'integer array';
    is-deeply j.noun('10 %~ 10 * i. 4').getm,
            Array[Num].new(:shape(4), [0e0, 1e0, 2e0, 3e0]),
            'floating array';
}

subtest 'readme' => {

    # SYNOPSIS

    my &doctest = { "doctest " ~ ++$ }

    is j.eval('i. 6'), '0 1 2 3 4 5', doctest();

    my $n = j.noun('>: 2 4 $ i. 8');
    is $n.gist, q:to<END>.chomp,
        1 2 3 4
        5 6 7 8
        END
        doctest();

    is j.eval("{(1,2) »×» 10} + $n"), q:to<END>.chomp,
        11 12 13 14
        25 26 27 28
        END
        doctest();

    my $a = $n.getm;
    is-deeply $a, Array[Int].new(:shape(2,4),[[1..4],[5..8]]), doctest();

    is-deeply $a.WHAT ~~ Array[Int], True, doctest();
    is-deeply $a.shape, [2,  4], doctest();

    is-deeply j.gets(‘2 5 $ 'HelloWorld'’),
        Array[Str].new(:shape(2,5),<H e l l o>,<W o r l d>),
        doctest();
}

done-testing;
