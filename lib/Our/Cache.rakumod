unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use  Base64::Native;
use  Compress::Bzip2;

sub cache (Str:D :$meta!, Str :$data, Str :$dir-prefix = $*PROGRAM.IO.basename, Instant :$expire-older-than) is export {

    my Str  $cache-dir  = $*HOME;
    given $dir-prefix {
        when .starts-with('.')  { $cache-dir ~ '/' ~ $dir-prefix;                   }
        default                 { $cache-dir ~ '/' ~ '.rakucache/' ~ $dir-prefix;   }
    }

    unless "$cache-dir".IO.e {
        mkdir $cache-dir;
        $cache-dir.IO.chmod(0o700);
    }

    my Str  $path       = $cache-dir ~ '/' ~ base64-encode($meta, :str);

    if $data {
        spurt $path, compressToBlob(base64-encode($data));
        $path.IO.chmod(0o600);
    }
    else {
        if "$path".IO.e {
            unlink $path    if $expire-older-than && "$path".IO.modified < $expire-older-than;
            return base64-decode(decompressToBlob(slurp($path, :bin))).decode if "$path".IO.e;
        }
        return;
    }
}

=finish
