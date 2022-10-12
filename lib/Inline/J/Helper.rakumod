
module Inline::J::Helper {

    our sub get-binpath {
        if %*ENV<JBINPATH> -> $bin {
            return $bin
        }

        my $test = rx{ :i ^ J90<[1..9]> $ };

        if $*DISTRO.is-win {
            for ($*HOME, 'C:/Program Files'.IO) -> $dir {
                if $dir.dir(:$test) -> @paths {
                    return @paths.reverse.first.child('bin')
                }
            }
        }
        else {
            for ($*HOME, '/opt'.IO) -> $dir {
                if $dir.dir(:$test) -> @paths {
                    return @paths.reverse.first.child('bin')
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
