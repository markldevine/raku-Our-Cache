use OO::Monitors;

unit monitor Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#%%% consider Command::Async::Multi sending in 5000 at once...  Perhaps 'multi sub(:%id2data)' to address bulk proportions...

use Base64::Native;
use Compress::Bzip2;
use JSON::Fast;

has Str         $.cache-dir             = $*HOME.Str;
has Instant     $.expire-older-than;
has Str         $.identifier;
has Str         $.identifier64;
has Str         $!index-path;
has             %.index;
has Str         $.subdir                = $*PROGRAM.IO.basename;

constant        \DATA-FILE-NAME-LENGTH  = 16;
constant        \MAX-DATA-FILE-SIZE     = 10 * 1024;

submethod TWEAK {
    if $!subdir.starts-with('/') {
        $!cache-dir ~= $!subdir;
    }
    else {
        $!cache-dir ~= '/' ~ '.rakucache/' ~ $!subdir;
    }
    unless "$!cache-dir".IO.e {
        mkdir "$!cache-dir";
        "$!cache-dir".IO.chmod(0o700);
    }
    $!identifier64          = base64-encode($!identifier, :str);
    $!index-path            = $!cache-dir ~ '/.index';
    %!index                 = from-json(slurp("$!index-path")) if "$!index-path".IO.e;
}

#%%%    multi method fetch-fh
multi method fetch {

    return Nil                                              unless "$!index-path".IO.e;
    %!index                                                 = ();
    %!index                                                 = from-json(slurp("$!index-path")) if "$!index-path".IO.e;

    my $data-file-path;
    if %!index{$!identifier64}:exists {
        $data-file-path                                     = $!cache-dir ~ '/' ~ %!index{$!identifier64};
        if $!expire-older-than {
            if "$data-file-path.bz2".IO.e {
                unlink "$data-file-path.bz2"                if "$data-file-path.bz2".IO.modified < $!expire-older-than;
            }
            if "$data-file-path".IO.e {
                unlink $data-file-path                      if "$data-file-path".IO.modified < $!expire-older-than;
            }
        }
    }

    unless "$data-file-path".IO.e || "$data-file-path.bz2".IO.e {
        %!index{$!identifier64}:delete;
        if %!index.elems {
            spurt($!index-path, to-json(%!index))           or die;
            "$!index-path".IO.chmod(0o600)                  or die;
        }
        else {
            unlink($!index-path);
        }
        return Nil;
    }

    if "$data-file-path.bz2".IO.e {
        decompress("$data-file-path.bz2");
        my $return-data                                     = slurp($data-file-path) or die;
        unlink($data-file-path)                             or die;
        return $return-data;
    }
    return slurp($data-file-path);
}

subset Cache-File-Name of Str where $_ ~~ / ^ <[a..zA..Z0..9]> ** {DATA-FILE-NAME-LENGTH} $ /;

#%%%    multi method store-fh (IO::Handle:D :$fh!)
multi method store (Str:D :$data!, :$cache-file-name) {
    if $cache-file-name {
        die 'Illegal $cache-file-name name!  <' ~ $cache-file-name ~ '>' unless $cache-file-name ~~ Cache-File-Name;
    }
    %!index                                                 = ();
    %!index                                                 = from-json(slurp("$!index-path")) if "$!index-path".IO.e;
    if %!index{$!identifier64}:exists {
        if $cache-file-name {
            if %!index{$!identifier64} ne $cache-file-name {
                my $data-file-path                          = $!cache-dir ~ '/' ~ %!index{$!identifier64};
put 'unlink("' ~ $data-file-path ~ '")';
                unlink("$data-file-path")                   if "$data-file-path".IO.e;
                unlink("$data-file-path.bz2")               if "$data-file-path.bz2".IO.e;
                %!index{$!identifier64}                     = $cache-file-name;
                $data-file-path                             = $!cache-dir ~ '/' ~ %!index{$!identifier64};
                spurt($!index-path, to-json(%!index))       or die;
                "$!index-path".IO.chmod(0o600)              or die;
                spurt("$data-file-path", $data)             or die;
                "$data-file-path".IO.chmod(0o600)           or die;
                if $data.chars > MAX-DATA-FILE-SIZE {
                    compress("$data-file-path");
                    "$data-file-path.bz2".IO.chmod(0o600)   or die;
                    unlink("$data-file-path")               or die;
                }
            }
        }
        else {
            my $data-file-path                              = $!cache-dir ~ '/' ~ %!index{$!identifier64};
            unlink "$data-file-path.bz2"                    if "$data-file-path.bz2".IO.e;
            spurt("$data-file-path", $data)                 or die;
            "$data-file-path".IO.chmod(0o600)               or die;
            if $data.chars > MAX-DATA-FILE-SIZE {
                compress("$data-file-path");
                "$data-file-path.bz2".IO.chmod(0o600)       or die;
                unlink("$data-file-path")                   or die;
            }
        }
    }
    else {
        my $data-file-name;
        with $cache-file-name {
            $data-file-name                                 = $cache-file-name;
        }
        else {
            $data-file-name                                 = self.generate-cache-file-name;
        }
        %!index{$!identifier64}                             = $data-file-name;
        spurt($!index-path, to-json(%!index))               or die;
        "$!index-path".IO.chmod(0o600)                      or die;
        my $data-file-path                                  = $!cache-dir ~ '/' ~ %!index{$!identifier64};
        spurt("$data-file-path", $data)                     or die;
        "$data-file-path".IO.chmod(0o600)                   or die;
        if $data.chars > MAX-DATA-FILE-SIZE {
            compress("$data-file-path");
            "$data-file-path.bz2".IO.chmod(0o600)           or die;
            unlink("$data-file-path")                       or die;
        }
    }
}

method generate-cache-file-name {
    loop (my $i = 0; $i < 10; $i++) {
        my $data-file-name      = ("a".."z","A".."Z",0..9).flat.roll(DATA-FILE-NAME-LENGTH).join;
        return $data-file-name  if !"$!cache-dir/$data-file-name".IO.e && !"$!cache-dir/$data-file-name.bz2".IO.e;
    }
    die;
}

=finish
