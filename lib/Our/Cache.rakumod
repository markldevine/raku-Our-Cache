use OO::Monitors;

unit monitor Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

#%%%    Consider Command::Async::Multi sending in 5000 at once...  Perhaps Our::Cache::Multi...?

use Base64::Native;

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
constant        \DEFAULT-INITIAL-SUBDIR                 = '.rakucache';
constant        \TEMP-FILE-NAME-LENGTH                  = 16;

has Str         $!identifier                            is built is required;
has Str         $!identifier64;
has IO::Path    $!active-data-path;
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
has Str         @!id-segments;

submethod TWEAK {
#   establish the root directory for this cache
    if $!subdir.starts-with('/') {
        $!cache-dir                                     = $!cache-dir.add: $!subdir;
    }
    else {
        $!cache-dir                                     = $!cache-dir.add: DEFAULT-INITIAL-SUBDIR, $!subdir;
    }
    unless $!cache-dir.e {
        $!cache-dir.mkdir(:mode(CACHE-DIR-PERMISSIONS)) or die;
        $!cache-dir.chmod(CACHE-DIR-PERMISSIONS)        or die;
    }
    $!identifier64                                      = base64-encode($!identifier, :str);
    $!cache-entry-full-dir                              = $!cache-dir;

    @!id-segments                                       = $!identifier64.comb(ID-SEGMENT-SIZE);
    for @!id-segments -> $segment {
        $!cache-entry-full-dir                          = $!cache-entry-full-dir.add: $segment;
    }
    $!cache-data-path                                   = $!cache-entry-full-dir.add: DATA-FILE-NAME;
    $!cache-expire-instant-path                         = $!cache-entry-full-dir.add: EXPIRE-INSTANT-FILE-NAME;
    $!cache-collection-instant-path                     = $!cache-entry-full-dir.add: COLLECTION-INSTANT-FILE-NAME;
    if self!cache-path-exists($!cache-data-path) {
        if $!cache-expire-instant-path.e {
            $!expire-instant                            = Instant.from-posix(slurp($!cache-expire-instant-path).subst(/^Instant\:/).Real);
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
put '$!cache-hit = <' ~ $!cache-hit ~ '>';
}

method !create-cache-directory-segments () {
    my IO::Path $dir                                    = $!cache-dir;
    for @!id-segments -> $segment {
        $dir                                            = $dir.add: $segment;
        unless $dir.e {
            $dir.mkdir(:mode(CACHE-DIR-PERMISSIONS))    or die;
            $dir.chmod(CACHE-DIR-PERMISSIONS)           or die;
        }
    }
}

method !expire () {
    unlink $!active-data-path                           if $!active-data-path && $!active-data-path.e;
    unlink $!cache-expire-instant-path                  if $!cache-expire-instant-path && $!cache-expire-instant-path.e;
    unlink $!cache-collection-instant-path              if $!cache-collection-instant-path && $!cache-collection-instant-path.e;
    my $dir                                             = $!cache-entry-full-dir;
    while $dir ne $!cache-dir {
        last                                            unless $dir.IO.e;
        $dir.rmdir;
        $dir                                            = $dir.subst(/ '/' <-[/]>+ $ /);
    }
}

method !cache-path-exists (IO::Path:D $path) {
    die 'Path not in ' ~ $!cache-dir                    unless $path.Str.starts-with($!cache-dir.Str);
    if $path.e {
        $!active-data-path                              = $path;
        return True;
    }
    elsif "$path.bz2".IO.e {
        $!active-data-path                              = ($path.Str ~ '.bz2').IO.path;
        return True;
    }
    return False;
}

method !generate-temp-file-name {
#subset Cache-File-Name of Str where $_ ~~ / ^ <[a..zA..Z0..9]> ** {TEMP-FILE-NAME-LENGTH} $ /;
    my $file-name;
    loop (my $i = 0; $i < 10; $i++) {
        $file-name                                      = ("a".."z","A".."Z",0..9).flat.roll(TEMP-FILE-NAME-LENGTH).join;
        return $file-name                               if !"$!cache-dir/$file-name".IO.e && !"$!cache-dir/$file-name.bz2".IO.e;
    }
    die;
}

multi method fetch (:@identifier!, Instant :$expire-after) {
    return self.fetch(:identifier(@identifier.flat.join), :$expire-after);
}

multi method fetch (Str:D :$identifier!, Instant :$expire-after) {
    my $fh                                              = self.fetch-fh(:$identifier, :$expire-after);
    return Nil                                          unless $fh ~~ IO::Handle:D;
    return $fh.slurp(:close);
}

multi method fetch-fh (:@identifier!, Instant :$expire-after) {
    return self.fetch-fh(:identifier(@identifier.flat.join), :$expire-after);
}

multi method fetch-fh (Str:D :$identifier!, Instant :$expire-after) {

    if $!expire-instant && $!expire-instant < now {
        self!expire;
        return Nil;
    }

    if $expire-after && $!collection-instant < $expire-after {
        self!expire;
        return Nil;
    }

    return Nil                                          unless self!cache-path-exists($!cache-data-path);
    my IO::Handle $fh;
    if $!active-data-path.Str.ends-with('.bz2') {
        my $proc                                        = run '/usr/bin/bunzip2', '-c', $!active-data-path, :out;
        $fh                                             = $proc.out;
    }
    else {
        $fh                                             = open :r, $!active-data-path;
    }
    return $fh;
}

#   store from STR
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, Str:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, Str:D :$path!) {
    return self.store(:$identifier, :$collected-at, :$expire-after, :$purge-source, :path(IO::Path.new($path)));
}

#   store from IO::Path
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, IO::Path:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, IO::Path:D :$path!) {
    die                                                 unless $path.e;
    my $fh                                              = open :r, $path or die;
    return self.store(:$identifier, :$collected-at, :$expire-after, :$purge-source, :$fh)
}

#   store from FH
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, IO::Handle:D :$fh!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$purge-source, :$fh);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, IO::Handle:D :$fh!) {

    $fh.close                                               if $fh.opened;
    my $keep                                                = '';
    $keep                                                   = '--keep ' unless $purge-source;

    $!active-data-path                                      = $!cache-data-path;
    self!create-cache-directory-segments;

    if $fh.path.Str ne $!cache-data-path.Str {

#   Case:   foreign source (not $!cache-data-path)

        if $fh.path.Str.starts-with($!cache-dir.Str) && $purge-source {
            rename($fh.path, $!cache-data-path)             or die;
        }
        elsif ($fh.path.s > MAX-UNCOMPRESSED-DATA-FILE-SIZE) {
            my $shell                                       = shell '/usr/bin/bzip2 ' ~ $keep ~ $fh.path.Str ~ ' > ' ~ $!cache-data-path;
            die                                             if $shell.exitcode;
            $!active-data-path                              = ($!cache-data-path.Str ~ '.bz2').IO.path;
            $!active-data-path.chmod(DATA-FILE-PERMISSIONS) or die;
        }
        else {
            if $purge-source {
                $fh.path.move($!cache-data-path)            or die;
            }
            else {
                $fh.path.copy($!cache-data-path)            or die;
            }
        }
    }
    else {

#   Case:   user obtained $!cache-data-path in advance and saved their file there

        if ($!cache-data-path.s > MAX-UNCOMPRESSED-DATA-FILE-SIZE) {
            my $proc                                        = run '/usr/bin/bzip2 ' ~ $keep ~ $!cache-data-path;
            die                                             if $proc.exitcode;
            $!active-data-path                              = ($!cache-data-path.Str ~ '.bz2').IO.path;
        }
        else {
            unlink("$!cache-data-path.bz2")                 if "$!cache-data-path.bz2".IO.e;
        }
    }
    $!active-data-path.chmod(DATA-FILE-PERMISSIONS)         or die;
    $!cache-collection-instant-path.spurt($collected-at)    or die;
    $!collection-instant                                    = $collected-at;
    if $expire-after {
        $!cache-expire-instant-path.spurt($expire-after)    or die;
    }
}

#   Store from memory
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-after, Str:D :$data!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-after, :$data);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-after, Bool :$purge-source, Str:D :$data!) {

    my $keep                                                = '';
    $keep                                                   = '--keep ' unless $purge-source;

    $!active-data-path                                      = $!cache-data-path;
    self!create-cache-directory-segments;

#   write the data to cache
    $!cache-data-path.spurt($data)                          or die;

#   compress the data as required
    if ($!cache-data-path.s > MAX-UNCOMPRESSED-DATA-FILE-SIZE) {
        my $proc                                            = run '/usr/bin/bzip2 ' ~ $keep ~ $!cache-data-path;
        die                                                 if $proc.exitcode;
        $!active-data-path                                  = ($!cache-data-path.Str ~ '.bz2').IO.path;
    }
    else {
        unlink("$!cache-data-path.bz2")                     if "$!cache-data-path.bz2".IO.e;
    }
    $!active-data-path.chmod(DATA-FILE-PERMISSIONS)         or die;
    $!cache-collection-instant-path.spurt($collected-at)    or die;
    if $expire-after {
        $!cache-expire-instant-path.spurt($expire-after)    or die;
    }
}

=finish
