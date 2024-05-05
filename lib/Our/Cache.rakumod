use OO::Monitors;

unit monitor Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#%%%    Consider Command::Async::Multi sending in 5000 at once...  Perhaps Our::Cache::Multi...?


use Base64::Native;
use Compress::Bzip2;
use JSON::Fast;

use Data::Dump::Tree;

constant        \DATA-FILE-NAME-LENGTH      = 16;
constant        \MAX-CACHE-DATA-FILE-SIZE   = 10 * 1024;

subset Cache-File-Name of Str where $_ ~~ / ^ <[a..zA..Z0..9]> ** {DATA-FILE-NAME-LENGTH} $ /;

has IO::Path        $.cache-dir             = $*HOME;
has Cache-File-Name $.cache-file-name;
has IO::Path        $.cache-file-path       is built;
has Instant         $.purge-older-than;
has Str             $.identifier            is built;
has Str             $!identifier64;
has IO::Path        $!index-path;
has                 %!index;
has Str             $!subdir                = $*PROGRAM.IO.basename;

submethod TWEAK {
    if $!subdir.starts-with('/') {
        $!cache-dir = $!cache-dir.add: $!subdir;
    }
    else {
        $!cache-dir = $!cache-dir.add: '.rakucache', $!subdir;
    }
    unless $!cache-dir.e {
        $!cache-dir.mkdir(:mode(0o700));
        $!cache-dir.chmod(0o700);
    }
    $!index-path                            = $!cache-dir.add: '.index';
    %!index                                 = ();
    %!index                                 = from-json($!index-path.slurp(:close)) if $!index-path.e;
    my Bool $changed;
    for %!index.keys -> $id64 {
        if %!index{$id64} !~~ Cache-File-Name {
            %!index{$id64}:delete;
            $changed                        = True;
            next;
        }
        my IO::Path $cache-path = $!cache-dir.add: %!index{$id64};
        unless $cache-path.e || "$cache-path.bz2".IO.e {
            %!index{$id64}:delete;
            $changed                        = True;
        }
    }
    if $changed {
        $!index-path.spurt(to-json(%!index))    or die;
        $!index-path.chmod(0o600)               or die;
    }
    my %v;
    for %!index.values -> $v {
        %v{$v} = 0;
    }
    my $cwd                     = $*CWD;
    chdir $!cache-dir;
    for dir(test => { $_ ~~ Cache-File-Name }) -> $cache-file {
        unlink $cache-file unless %v{$cache-file}:exists;
    }
    chdir $cwd;
}

multi method identifier (@identifier) {
    return self.idenitfier(@identifier.join);
}

multi method identifier ($identifier?) {
    with $identifier {
        my $id;
        if $identifier ~~ Positional {
            $id                         = $identifier.list.join;
        }
        else {
            $id                         = $identifier;
        }
        if !$!identifier64 || $id ne $!identifier {
            $!identifier                = $id;
            $!identifier64              = base64-encode($!identifier, :str);
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
            $!cache-file-path           = $!cache-dir.add: $!cache-file-name;
        }
#put '$!identifier       = ' ~ $!identifier;
#put '$!identifier64     = ' ~ $!identifier64;
#put '$!cache-file-name  = ' ~ $!cache-file-name;
#put '$!cache-file-path  = ' ~ $!cache-file-path;
    }
    return $!identifier;
}

method cache-will-hit (Str:D :$identifier!, Instant :$purge-older-than = $!purge-older-than) {
    return False                                     unless "$!index-path".IO.e;
    self.identifier($identifier)                    with $identifier;
    if $purge-older-than {
        if "$!cache-file-path.bz2".IO.e {
            unlink "$!cache-file-path.bz2"          if "$!cache-file-path.bz2".IO.modified < $purge-older-than;
        }
        if $!cache-file-path.e {
            unlink $!cache-file-path                if $!cache-file-path.modified < $purge-older-than;
        }
    }
    unless $!cache-file-path.e || "$!cache-file-path.bz2".IO.e {
        %!index{$!identifier64}:delete;
        if %!index.elems {
            $!index-path.spurt(to-json(%!index))    or die;
            $!index-path.chmod(0o600)               or die;
        }
        else {
            unlink $!index-path;
        }
    }
    return False                                    unless %!index{$!identifier64}:exists;
    return True;
}

method fetch-fh (Str:D :$identifier!, Instant :$purge-older-than = $!purge-older-than) {
    return                                          unless self.cache-will-hit(:$identifier, :$purge-older-than);
    my IO::Handle $fh;
    if "$!cache-file-path.bz2".IO.e {
        my $proc                                    = run '/usr/bin/bunzip2', '-c', $!cache-file-path.Str ~ '.bz2', :out;
        $fh                                         = $proc.out;
    }
    else {
        $fh                                         = open :r, $!cache-file-path;
    }
    return $fh;
}

method fetch (Str:D :$identifier, Instant :$purge-older-than = $!purge-older-than) {
    return slurp(self.fetch-fh(:$identifier, :$purge-older-than), :close);
}

multi method store (Str:D :$identifier!, IO::Handle:D :$fh!) {
    self.identifier($identifier)                    with $identifier;
    if %!index{$!identifier64}:!exists || %!index{$!identifier64} ne $!cache-file-name {
        %!index{$!identifier64}                     = $!cache-file-name;
        $!index-path.spurt(to-json(%!index))        or die;
        $!index-path.chmod(0o600)                   or die;
    }
    my $cache-file                                  = open :w, $!cache-file-path;
    while $fh.get -> $record {
        $cache-file.put($record);
    }
    $cache-file.close;
    $fh.close;
    $!cache-file-path.chmod(0o600)                  or die;
    if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(0o600)     or die;
        unlink($!cache-file-path)                   or die;
    }
    else {
        unlink("$!cache-file-path.bz2")             if "$!cache-file-path.bz2".IO.e;
    }
}

multi method store (Str:D :$identifier!, Str:D :$data!) {
    self.identifier($identifier)                    with $identifier;
    if %!index{$!identifier64}:!exists || %!index{$!identifier64} ne $!cache-file-name {
        %!index{$!identifier64}                     = $!cache-file-name;
        $!index-path.spurt(to-json(%!index))        or die;
        $!index-path.chmod(0o600)                   or die;
    }
    $!cache-file-path.spurt($data)                  or die;
    $!cache-file-path.chmod(0o600)                  or die;
    if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(0o600)     or die;
        unlink($!cache-file-path)                   or die;
    }
    else {
        unlink("$!cache-file-path.bz2")             if "$!cache-file-path.bz2".IO.e;
    }
}

=finish
