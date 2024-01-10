unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use  Base64::Native;

sub cache (Str:D :$meta!, Mu :$data, Str :$dir-prefix = $*PROGRAM.IO.basename, Instant :$expire-older-than) is export {

    my Str  $cache-dir  = $*HOME.Str;
    if $dir-prefix.starts-with('.') {
        $cache-dir ~= '/' ~ $dir-prefix;
    }
    else {
        $cache-dir ~= '/' ~ '.rakucache/' ~ $dir-prefix;
    }

    unless "$cache-dir".IO.e {
        mkdir $cache-dir;
        $cache-dir.IO.chmod(0o700);
    }

    my Str  $path       = $cache-dir ~ '/' ~ base64-encode($meta, :str);

    if $data {
        spurt $path, $data;
        $path.IO.chmod(0o600);
    }
    else {
        if "$path".IO.e {
            if $expire-older-than && "$path".IO.modified < $expire-older-than {
                unlink $path    if $expire-older-than && "$path".IO.modified < $expire-older-than;
            }
            else {
                return slurp $path;
            }
        }
    }
    return;
}

=finish
