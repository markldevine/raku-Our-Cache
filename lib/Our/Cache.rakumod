unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use  Base64::Native;
use  Compress::Bzip2;

sub cache (Str:D :$meta!, Str :$data, Str :$dir-prefix = $*PROGRAM.IO.basename, Instant :$expire-older-than = 0) is export {

    my Str  $cache-dir  = $*HOME ~ '/.rakucache/' ~ $dir-prefix;
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
        unlink $path    if $expire-older-than && "$path".IO.modified < $expire-older-than;
        return          unless "$path".IO.e;
        return base64-decode(decompressToBlob(slurp($path, :bin))).decode;
    }
}

=finish
