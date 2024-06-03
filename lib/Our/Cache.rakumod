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
#has Instant         $.expire-at;
#has Instant         $.collected-at;
has Str             $.identifier            is built;
has Str             $!identifier64;
has IO::Path        $!index-path;
has Instant         $!index-modtime;
has                 %!index                 = ();
has Str:D           $.subdir                = $*PROGRAM.IO.basename;
has Bool            $.cache-hit             = False;

submethod TWEAK {

#   establish the root directory for this cache
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

#   establish the index store and keep track of modifications
    $!index-path                            = $!cache-dir.add: '.index';
    if $!index-path.e {
        $!index-modtime                     = $!index-path.modified;
        %!index                             = from-json($!index-path.slurp);
    }
    else {
        self!write-index;
    }

#   validate that all index entries have valid format & point to valid cache data files
    my Bool $index-changed                  = False;
    my %idx                                 = %!index;
    for %idx.keys -> $id64 {
        if %idx{$id64} !~~ Cache-File-Name {
            %!index{$id64}:delete;
            $index-changed                  = True;
            next;
        }
        my IO::Path $cache-path = $!cache-dir.add: %idx{$id64};
        unless self!cache-file-exists(:cache-file($cache-path.Str)) {
            %!index{$id64}:delete;
            $index-changed                  = True;
        }
    }
    self!write-index                        if $index-changed;

#   remove any orphaned Cache-File-Name files in $!cache-dir not in the index
    my %v;
    for %!index.values -> $v {
        %v{$v} = 0;
    }
    my $cwd                                 = $*CWD;
    chdir $!cache-dir;
    for dir(test => { $_ ~~ Cache-File-Name }) -> $cache-file {
        unlink $cache-file                  unless %v{$cache-file}:exists;
    }
    chdir $cwd;
}

method !read-index () {
    die                                     unless $!index-path.e;
    return                                  if $!index-modtime == $!index-path.modified;
    %!index                                 = from-json($!index-path.slurp);
}

method !write-index () {
    $!index-path.spurt(to-json(%!index))    or die;
    $!index-path.chmod(0o600)               or die;
    $!index-modtime                         = $!index-path.modified;
}

method !cache-file-exists (Str:D :$cache-file) {
    my IO::Path $path                       = $!cache-dir;
    $path                                   = IO::Path.new($cache-file) if $cache-file.starts-with('/');
    return False                            unless $path.Str.starts-with($!cache-dir.Str);
    return $path                            if $path.e;
    return $path ~ '.bz2'                   if "$path.bz2".IO.e;
    return False;
}

method !generate-cache-file-data-name {
    loop (my $i = 0; $i < 10; $i++) {
        $!cache-file-name                   = ("a".."z","A".."Z",0..9).flat.roll(DATA-FILE-NAME-LENGTH).join;
        last                                if !"$!cache-dir/$!cache-file-name".IO.e && !"$!cache-dir/$!cache-file-name.bz2".IO.e;
        $!cache-file-name                   = '';
    }
    die                                     unless $!cache-file-name;
    $!cache-file-path                       = $!cache-dir.add: $!cache-file-name;
}

multi method set-identifier (:@identifier, Instant :$purge-older-than = $!purge-older-than) {
    return self.set-identifier(:identifier(@identifier.join), :$purge-older-than);
}

multi method set-identifier (Str:D :$identifier, Instant :$purge-older-than = $!purge-older-than) {

    $!identifier                            = $identifier;

#   establish the new identifier key
    $!identifier64                          = base64-encode($identifier, :str);

#   refresh the $!index, if necessary
    self!read-index;

#   attempt to recycle any existing index entry for identifier; clean up any nonsense
    if %!index{$!identifier64}:exists {
        if self!cache-file-exists(:cache-file(%!index{$!identifier64})) {
            $!cache-file-name               = %!index{$!identifier64};
        }
        else {
            %!index{$!identifier64}:delete;
            self!write-index;
        }
    }

#   if no $!cache-file-name exists for the instance at this point, generate a new one for potential future use
    self!generate-cache-file-data-name      unless $!cache-file-name;

#   canonicalize the $!cache-file-path
    $!cache-file-path                       = $!cache-dir.add: $!cache-file-name;

#   attempt to hit the cache for this identifier, after purging expired entries
    $!cache-hit                             = False;
    my $path                                = self!cache-file-exists(:cache-file($!cache-file-path.Str));
    if %!index{$!identifier64}:exists & $path {
        if $purge-older-than && "$path".IO.modified < $purge-older-than {
            unlink($!cache-file-path)       or die;
            %!index{$!identifier64}:delete;
            self!write-index;
        }
        else {
            $!cache-hit                     = True;
        }
    }
    return $!cache-hit;
}

method expire-now (Str:D :$identifier!) {
    self.set-identifier(:$identifier, :purge-older-than(now));
}

multi method fetch (:@identifier!, Instant :$purge-older-than = $!purge-older-than) {
    return self.fetch(:identifier(@identifier.flat.join), :$purge-older-than);
}

multi method fetch (Str:D :$identifier!, Instant :$purge-older-than = $!purge-older-than) {
    my $fh                                  = self.fetch-fh(:$identifier, :$purge-older-than);
    return $fh                              unless $fh ~~ IO::Handle:D;
    return $fh.slurp(:close);
}

multi method fetch-fh (:@identifier!, Instant :$purge-older-than = $!purge-older-than) {
    return self.fetch-fh(:identifier(@identifier.flat.join), :$purge-older-than);
}

multi method fetch-fh (Str:D :$identifier!, Instant :$purge-older-than = $!purge-older-than) {
    return Nil                                      unless self.set-identifier(:$identifier, :$purge-older-than);
    my $path                                        = self!cache-file-exists(:cache-file($!cache-file-path.Str));
    my IO::Handle $fh;
    if $path.ends-with('.bz2') {
        my $proc                                    = run '/usr/bin/bunzip2', '-c', $path, :out;
        $fh                                         = $proc.out;
    }
    else {
        $fh                                         = open :r, $path;
    }
    return $fh;
}

#   store from STR
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-at, Str:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-at, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-at, Str:D :$path!) {
    return self.store(:$identifier, :$collected-at, :$expire-at, :path(IO::Path.new($path)));
}

#   store from IO::Path
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-at, IO::Path:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-at, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-at, IO::Path:D :$path!) {
    die                                             unless $path.e;
    my $fh                                          = open :r, $path or die;
    return self.store(:$identifier, :$collected-at, :$expire-at, :$fh)
}

#   store from open FH
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-at, IO::Handle:D :$path!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-at, :$path);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-at, IO::Handle:D :$fh!) {
    self.set-identifier(:$identifier);

#   if replacing an existing entry
    if %!index{$!identifier64} && %!index{$!identifier64} ne $!cache-file-name {
        my $existing-path                           = self!cache-file-exists(:cache-file("$!cache-dir/%!index{$!identifier64}"));
        unlink("existing-path")                     if $existing-path;
    }

#   assign the identifier to a cache data file name
    %!index{$!identifier64} = $!cache-file-name;

#   if the filehandle is not our anticipated $!cache-file-path, it must be a foreign source;
#   read from the consumer's filehandle and put that data into our $!cache-file-path
    if $fh.path.Str ne $!cache-file-path.Str {
        my $cache-fh                                = open :w, $!cache-file-path;
        while !$fh.eof {
            $cache-fh.put($fh.get);
        }
        $cache-fh.close;
        $fh.close;
    }
    $!cache-file-path.chmod(0o600)                  or die;

#   compress the data as required
    if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die 'during compress ' ~ $!cache-file-path  unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(0o600)     or die;
        unlink($!cache-file-path)                   or die;
    }
    else {
        unlink("$!cache-file-path.bz2")             if "$!cache-file-path.bz2".IO.e;
    }

#   One way or another, our $!cache-file-path exists now, ending with the $!cache-file-name.  Record it.
    self!write-index;
}

#   Store from memory
multi method store (:@identifier!, Instant :$collected-at = now, Instant :$expire-at, Str:D :$data!) {
    return self.store(:identifier(@identifier.flat.join), :$collected-at, :$expire-at, :$data);
}

multi method store (Str:D :$identifier!, Instant :$collected-at = now, Instant :$expire-at, Str:D :$data!) {
    self.set-identifier(:$identifier);

#   assign the identifier to a cache data file name
    %!index{$!identifier64}                          = $!cache-file-name;
    self!write-index;

#   write the data to cache
    $!cache-file-path.spurt($data)                  or die;
    $!cache-file-path.chmod(0o600)                  or die;

#   compress the data as required
    if $!cache-file-path.s > MAX-CACHE-DATA-FILE-SIZE {
        compress("$!cache-file-path");
        die 'during compress ' ~ $!cache-file-path  unless "$!cache-file-path.bz2".IO.e;
        "$!cache-file-path.bz2".IO.chmod(0o600)     or die;
        unlink($!cache-file-path)                   or die;
    }
    else {
        unlink("$!cache-file-path.bz2")             if "$!cache-file-path.bz2".IO.e;
    }
}

=finish
