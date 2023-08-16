module Inline::J::Helper {

    our sub get-binpath {
        if %*ENV<JBINPATH> -> $bin {
            return $bin.IO
        }

        my $test = rx{ :i ^ J9 [ '0' <[1..3]> || '.' <[4..5]> ] $ };

        if $*DISTRO.is-win {
            my @paths = (
                $*HOME,
                %*ENV<USERPROFILE>.?IO,
                %*ENV<LOCALAPPDATA>.?IO.child('Programs'),
                %*ENV<HOMEDRIVE>.?IO.child('Program Files'),
            );
            for @paths.unique.grep({ .e && .d }) -> $dir {
                if $dir.dir(:$test).sort(*.basename.subst('j90', 'j9.')) -> @paths {
                    return @paths.reverse.first.child('bin');
                }
            }
        }
        else {
            for ($*HOME, '/usr/local'.IO, '/opt'.IO).grep({ .e && .d }) -> $dir {
                if $dir.dir(:$test).sort(*.basename.subst('j90', 'j9.')) -> @paths {
                    return @paths.reverse.first.child('bin');
                }
            }
        }

        die q:to<END>;
        Could not find binpath.
        Ensure you have J installed, and export the binpath to JBINPATH.
        END
    }

    our sub get-library(IO() $bin) {
        if %*ENV<JLIBRARY> -> $lib {
            return $lib.IO
        }

        if $*DISTRO.is-win {
            return $bin.child('j.dll')
        }
        else {
            return $bin.child('libj.so')
        }

    }

    our sub get-profile(IO() $bin) {
        if %*ENV<JPROFILE> -> $pro {
            return $pro.IO
        }
        return $bin.child('profile.ijs')
    }

}
