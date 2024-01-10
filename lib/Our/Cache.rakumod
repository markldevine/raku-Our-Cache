unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use  Base64::Native;

sub cache-file-name (Str:D :$meta!, Str :$dir-prefix = $*PROGRAM.IO.basename) is export {
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
    return $cache-dir ~ '/' ~ base64-encode($meta, :str);
}

sub cache (Str:D :$cache-file-name!, Mu :$data, Instant :$expire-older-than) is export {
    my $cache-dir = "$cache-file-name".IO.dirname;
    die 'Get cache-file-name() first' unless "$cache-dir".IO.d;
    if $data {
        spurt $cache-file-name, $data;
        return "$cache-file-name".IO.chmod(0o600);
    }
    if "$cache-file-name".IO.e {
        if $expire-older-than && "$cache-file-name".IO.modified < $expire-older-than {
            unlink $cache-file-name if $expire-older-than && "$cache-file-name".IO.modified < $expire-older-than;
        }
        else {
            return slurp $cache-file-name;
        }
    }
    return;
}

=finish
