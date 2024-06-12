use OO::Monitors;

unit monitor Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#%%%    Consider Command::Async::Multi sending in 5000 at once...  Perhaps Our::Cache::Multi...?

use Base64::Native;
use Compress::Bzip2;

#   .../data                # .../data.bz2
#   .../collection-instant
#   .../expire-instant

use Data::Dump::Tree;

constant        \CACHE-DIR-PERMISSIONS                  = 0o2770;
constant        \COLLECTION-INSTANT-FILE-NAME           = 'collection-instant';
constant        \DATA-FILE-NAME                         = 'data';
constant        \DATA-FILE-PERMISSIONS                  = 0o660;
constant        \EXPIRE-INSTANT-FILE-NAME               = 'expire-instant';
constant        \MAX-UNCOMPRESSED-DATA-FILE-SIZE        = 10 * 1024;
constant        \ID-SEGMENT-SIZE                        = 64;

has Str         $!identifier                            is built is required;
has Str         $!identifier64;
has Str         $!active-data-path;
has IO::Path    $!cache-collection-instant-path;
has IO::Path    $!cache-expire-instant-path;
has IO::Path    $!cache-entry-full-dir;
has IO::Path    $!cache-data-path;
has IO::Path    $.cache-dir                             = $*HOME;
has Bool        $.cache-hit                             = False;
has Instant     $!collection-instant                    is built = now;
has Instant     $!expire-instant                        is built;
has Str:D       $.subdir                                = $*PROGRAM.IO.basename;
has IO::Path    $.temp-write-path                       is built(False);

submethod TWEAK {
#   establish the root directory for this cache
    if $!subdir.starts-with('/') {
        $!cache-dir                                     = $!cache-dir.add: $!subdir;
    }
    else {
        $!cache-dir                                     = $!cache-dir.add: '.rakucache', $!subdir;
    }
    unless $!cache-dir.e {
        $!cache-dir.mkdir(:mode(CACHE-DIR-PERMISSIONS)) or die;
        $!cache-dir.chmod(CACHE-DIR-PERMISSIONS)        or die;
    }
    $!identifier64                                      = base64-encode($!identifier, :str);
    $!cache-entry-full-dir                              = $!cache-dir;
    for $!identifier64.comb(ID-SEGMENT-SIZE) -> $segment {
        $!cache-entry-full-dir                          = $!cache-entry-full-dir.add: $segment;
        unless $!cache-entry-full-dir.e {
            $!cache-entry-full-dir.mkdir(:mode(CACHE-DIR-PERMISSIONS))  or die;
            $!cache-entry-full-dir.chmod(CACHE-DIR-PERMISSIONS)         or die;
        }
    }
    $!cache-data-path                                   = $!cache-entry-full-dir.add: DATA-FILE-NAME;
    $!cache-expire-instant-path                         = $!cache-entry-full-dir.add: EXPIRE-INSTANT-FILE-NAME;
    $!cache-collection-instant-path                     = $!cache-entry-full-dir.add: COLLECTION-INSTANT-FILE-NAME;
    if self!cache-path-exists($!cache-data-path) {
        if $!cache-expire-instant-path.e {
            $!expire-instant                            = Instant.from-posix(slurp($!cache-expire-instant-path, :close).subst(/^Instant:/));
            if $!expire-instant < now {
                self!expire;
                $!cache-hit                             = False;
            }
        }
        else {
            $!cache-hit                                 = True;
        }
    }
    unless $!active-data-path {
        $!temp-write-path                               = $!cache-dir.add: self!generate-temp-file-name;
    }
}

method !expire {
    unlink $!active-data-path;
    unlink $!cache-expire-instant-path;
    unlink $!cache-collection-instant-path;
    my $dir                                             = $!cache-entry-full-dir;
    while $dir ne $!cache-dir {
        put "unlink $dir";
        $dir                                            = $dir.subst(|/.+?$|);
    }
}

method !cache-path-exists (IO::Path:D $path) {
    die 'Path not in ' ~ $!cache-dir                    unless $path.Str.starts-with($!cache-dir.Str);
    if $path.e {
        $!active-data-path                              = $path.Str;
        return True;
    }
    elsif "$path.bz2".IO.e {
        $!active-data-path                              = $path.Str ~ '.bz2';
        return True;
    }
    return False;
}

method !generate-temp-file-name {
#subset Cache-File-Name of Str where $_ ~~ / ^ <[a..zA..Z0..9]> ** {DATA-FILE-NAME-LENGTH} $ /;
    loop (my $i = 0; $i < 10; $i++) {
        $!cache-file-name                               = ("a".."z","A".."Z",0..9).flat.roll(DATA-FILE-NAME-LENGTH).join;
        last                                            if !"$!cache-dir/$!cache-file-name".IO.e && !"$!cache-dir/$!cache-file-name.bz2".IO.e;
        $!cache-file-name                               = '';
    }
    die                                                 unless $!cache-file-name;
}

multi method fetch (:@identifier!, Instant :$expire-after) {
    return self.fetch(:identifier(@identifier.flat.join), :$expire-after);
}

multi method fetch (Str:D :$identifier!, Instant :$expire-after) {
    my $fh                                              = self.fetch-fh(:$identifier, :$expire-after);
    return $fh                                          unless $fh ~~ IO::Handle:D;
    return $fh.slurp(:close);
}

multi method fetch-fh (:@identifier!, Instant :$purge-after) {
    return self.fetch-fh(:identifier(@identifier.flat.join), :$expire-after);
}

multi method fetch-fh (Str:D :$identifier!, Instant :$expire-after) {
    return Nil                                          unless self.set-identifier(:$identifier, :$expire-after);
    my $path                                            = self!cache-file-exists(:cache-file($!cache-file-path.Str));
    my IO::Handle $fh;
    if $path.ends-with('.bz2') {
        my $proc                                        = run '/usr/bin/bunzip2', '-c', $path, :out;
        $fh                                             = $proc.out;
    }
    else {
        $fh                                             = open :r, $path;
    }
    return $fh;
}

#   store from STR
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, Str:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, Str:D :$path!) {
    return self.store(:$identifier, :$collected-at, :$expire-after, :$purge-source, :path(IO::Path.new($path)));
}

#   store from IO::Path
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, IO::Path:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, IO::Path:D :$path!) {
    die                                                 unless $path.e;
    my $fh                                              = open :r, $path or die;
    return self.store(:$identifier, :$collected-at, :$expire-after, :$purge-source, :$fh)
}

#   store from open FH
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, IO::Handle:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, :$purge-source, IO::Handle:D :$fh!) {

#   $!cache-data-path
#   $!cache-expire-instant-path
#   $!cache-collection-instant-path

    if $fh.path.Str ne $!cache-data-path.Str {

#   Case:   foreign source; read from the consumer's filehandle and put that data into our $!cache-data-path

        if $fh.path.s > MAX-UNCOMPRESSED-DATA-FILE-SIZE {
            if $purge-source {
                bunzip source > $!cache-file-path...
            }
            else {
                bunzip --keep source > $!cache-file-path...
            }
        }
        else {
            my $source-path                                 = $fh.path;
            my $cache-fh                                    = open :w, $!cache-file-path;
            while !$fh.eof {
                $cache-fh.put($fh.get);
            }
            $cache-fh.close;
            $fh.close;
            $source-path.unlink                             if $purge-source;
        }
    }
    else {

#   Case:   user obtained $!cache-data-path in advance and saved their file there

        if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
            compress("$!cache-file-path");
            die 'during compress ' ~ $!cache-file-path  unless "$!cache-file-path.bz2".IO.e;
            "$!cache-file-path.bz2".IO.chmod(CACHE-FILE-PERMISSIONS) or die;
            unlink($!cache-file-path)                       or die;
        }
        else {
            unlink("$!cache-file-path.bz2")                 if "$!cache-file-path.bz2".IO.e;
        }
    }
    $!cache-file-path.chmod(CACHE-FILE-PERMISSIONS)     or die;
}

#   Store from memory
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, Str:D :$data!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$data);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, Str:D :$data!) {
    self.set-identifier(:$identifier);

#   assign the identifier to a cache data file name
    %!index{$!identifier64}<Cache-File-Name>            = $!cache-file-name;

#   assign an Instant when collected to the identifier
    %!index{$!identifier64}<Collected-At>               = $colleted-at;

#   assign an Instant when to expire to the identifier, as required
    %!index{$!identifier64}<Expire-After>               = $expire-after if $expire-after;

#   write the data to cache
    $!cache-file-path.spurt($data)                      or die;
    $!cache-file-path.chmod(CACHE-FILE-PERMISSIONS)     or die;

#   compress the data as required
    if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die 'during compress ' ~ $!cache-file-path  unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(CACHE-FILE-PERMISSIONS) or die;
        unlink($!cache-file-path)                       or die;
    }
    else {
        unlink("$!cache-file-path.bz2")                 if "$!cache-file-path.bz2".IO.e;
    }

    self!write-index;
}

=finish
