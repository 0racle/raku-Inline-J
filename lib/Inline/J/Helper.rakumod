module Inline::J::Helper {

    our sub get-binpath {
        if %*ENV<JBINPATH> -> $bin {
            return $bin
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
                    if @paths.reverse.first.child('bin') -> $bin {
                        return $bin
                    }
                }
            }
        }
        else {
            for ($*HOME, '/usr/local'.IO, '/opt'.IO).grep({ .e && .d }) -> $dir {
                if $dir.dir(:$test).sort(*.basename.subst('j90', 'j9.')) -> @paths {
                    if @paths.reverse.first.child('bin') -> $bin {
                        return $bin
                    }
                }
            }
        }

        die q:to<END>;
        Could not find binpath.
        Ensure you have J installed, and export the binpath to JBINPATH.
        END
    }

    our sub get-library($bin) {
        if %*ENV<JLIBRARY> -> $lib {
            return $lib
        }

        if $*DISTRO.is-win {
            return "$bin/j.dll"
        }
        else {
            return "$bin/libj.so"
        }

    }

    our sub get-profile($bin) {
        if %*ENV<JPROFILE> -> $pro {
            return $pro
        }
        return "$bin/profile.ijs"
    }

}
