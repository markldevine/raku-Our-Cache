unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use  Base64::Native;
use  Compress::Bzip2;

sub cache (Str:D :$meta!, :$data) is export {

    my Str  $cdir   = $*HOME ~ '/.rakucache/' ~ $*PROGRAM.IO.basename;
    mkdir $cdir     unless "$cdir".IO.e;
    $cdir.IO.chmod(0o700);

    my Str  $path   = $cdir ~ '/' ~ base64-encode($meta, :str);

    if $data {
        spurt $path, compressToBlob(base64-encode($data));
        $path.IO.chmod(0o600);
    }
    else {
        return      unless "$path".IO.e;
        return base64-decode(decompressToBlob(slurp($path, :bin))).decode;
    }
}

=finish
