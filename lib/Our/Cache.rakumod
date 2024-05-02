use OO::Monitors;

unit monitor Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#%%%    Consider Command::Async::Multi sending in 5000 at once...  Perhaps Our::Cache::Multi...?

use Base64::Native;
use Compress::Bzip2;
use JSON::Fast;

constant        \DATA-FILE-NAME-LENGTH      = 16;
constant        \MAX-CACHE-DATA-FILE-SIZE   = 10 * 1024;

subset Cache-File-Name of Str where $_ ~~ / ^ <[a..zA..Z0..9]> ** {DATA-FILE-NAME-LENGTH} $ /;

has Str             $.cache-dir             = $*HOME.Str;
has Cache-File-Name $.cache-file-name;
has Str             $.cache-file-path;                                  # %%% is built...
has Instant         $.expire-older-than;
has Str             $.identifier            is required;
has Str             $.identifier64;
has Str             $!index-path;
has                 %.index;
has Str             $.subdir                = $*PROGRAM.IO.basename;

submethod TWEAK {
    if $!subdir.starts-with('/') {
        $!cache-dir            ~= $!subdir;
    }
    else {
        $!cache-dir            ~= '/' ~ '.rakucache/' ~ $!subdir;
    }
    unless "$!cache-dir".IO.e {
        mkdir "$!cache-dir";
        "$!cache-dir".IO.chmod(0o700);
    }
    self!init;
    my Bool $changed;
    for %!index.keys -> $id {
        unless "$!cache-dir/$id".IO.e || "$!cache-dir/$id.bz2".IO.e {
            %!index{$id}:delete;
            $changed = True;
        }
    }
    if $changed {
        spurt($!index-path, to-json(%!index))   or die;
        "$!index-path".IO.chmod(0o600)          or die;
    }
    my %v;
    for %!index.values -> $v {
        %v{$v} = 0;
    }
    my $cwd                     = $*CWD;
    chdir "$!cache-dir";
    for dir(test => { $_ ~~ Cache-File-Name }) -> $cache-file {
        unlink $cache-file unless %v{$cache-file}:exists;
    }
    chdir "$cwd";
}

method identifier ($identifier?) {
    with $identifier {
        my $id;
        if $identifier ~~ Positional {
            $id                 = $identifier.list.join;
        }
        else {
            $id                 = $identifier;
        }
        if $id ne $!identifier {
            $!identifier        = $id;
            self!init;
        }
    }
    return $!identifier;
}

method !init {
    $!identifier64              = base64-encode($!identifier, :str);
    $!index-path                = $!cache-dir ~ '/.index';
    return Nil                  unless "$!index-path".IO.e;
    %!index                     = from-json(slurp("$!index-path")) if "$!index-path".IO.e;
    if %!index{$!identifier64}:exists {
        $!cache-file-name       = %!index{$!identifier64};
    }
    else {
        loop (my $i = 0; $i < 10; $i++) {
            $!cache-file-name   = ("a".."z","A".."Z",0..9).flat.roll(DATA-FILE-NAME-LENGTH).join;
            last                if !"$!cache-dir/$!cache-file-name".IO.e && !"$!cache-dir/$!cache-file-name.bz2".IO.e;
            $!cache-file-name   = '';
        }
        die                     unless $!cache-file-name;
    }
    $!cache-file-path           = $!cache-dir ~ '/' ~ $!cache-file-name;
}

#%%%    multi method fetch-fh
multi method fetch (Str :$identifier) {
    return Nil                                      unless "$!index-path".IO.e;
    self.identifier($identifier)                    with $identifier;
    %!index                                         = ();
    %!index                                         = from-json(slurp("$!index-path")) if "$!index-path".IO.e;
    return Nil                                      unless %!index{$!identifier64}:exists;
    $!cache-file-name                               = %!index{$!identifier64};
    $!cache-file-path                               = $!cache-dir ~ '/' ~ $!cache-file-name;
    if $!expire-older-than {
        if "$!cache-file-path.bz2".IO.e {
            unlink "$!cache-file-path.bz2"          if "$!cache-file-path.bz2".IO.modified < $!expire-older-than;
        }
        if "$!cache-file-path".IO.e {
            unlink $!cache-file-path                if "$!cache-file-path".IO.modified < $!expire-older-than;
        }
    }
    unless "$!cache-file-path".IO.e || "$!cache-file-path.bz2".IO.e {
        %!index{$!identifier64}:delete;
        if %!index.elems {
            spurt($!index-path, to-json(%!index))   or die;
            "$!index-path".IO.chmod(0o600)          or die;
        }
        else {
            unlink($!index-path);
        }
        return Nil;
    }
    if "$!cache-file-path.bz2".IO.e {
        decompress("$!cache-file-path.bz2");
        my $return-data                             = slurp($!cache-file-path) or die;
        unlink($!cache-file-path)                   or die;
        return $return-data;
    }
    return slurp($!cache-file-path);
}

#%%%    multi method store-fh (IO::Handle:D :$fh!)
multi method store (Str:D :$data!, Str :$identifier) {
    self.identifier($identifier)                    with $identifier;
    %!index                                         = ();
    %!index                                         = from-json(slurp("$!index-path")) if "$!index-path".IO.e;
    if %!index{$!identifier64}:!exists || %!index{$!identifier64} ne $!cache-file-name {
        %!index{$!identifier64}                     = $!cache-file-name;
        spurt($!index-path, to-json(%!index))       or die;
        "$!index-path".IO.chmod(0o600)              or die;
    }
    spurt("$!cache-file-path", $data)               or die;
    "$!cache-file-path".IO.chmod(0o600)             or die;
    if "$!cache-file-path".IO.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(0o600)     or die;
        unlink("$!cache-file-path")                 or die;
    }
}


=finish
