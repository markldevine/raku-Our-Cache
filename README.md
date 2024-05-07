Raku Cache
==========
Module that exports a general purpose cache function.

SYNOPSIS
========

    use Our::Cache;


Cases
=====

    submethod TWEAK
        $!cache-dir
        $!index-path
        if $!index-path.e
            $!index-modtime = $!index-path.modified
            %!index = from-json($!index-path.slurp)
        else
            %!index = ();
            self!write-index
        validate all %!index.keys point to a valid data file
            if any changes occurred
                self!write-index
        remove any Cache-File-Name files in $!cache-dir not in the index

    method !read-index
        die unless $!index-path.e
        return if $!index-modtime == $!index-path.modified;
        %!index = from-json($!index-path.slurp)

    method !write-index
        $!index-path.spurt(to-json(%!index))    or die;
        $!index-path.chmod(0o600)               or die;
        $!index-modtime                         = $!index-path.modified

    method !cache-file-exists (Str:D :$cache-file)
        my IO::Path $path = $!cache-dir
        $path = IO::Path.new($cache-file) if $cache-file.starts-with('/')
        return False unless $path.Str.starts-with($!cache-dir.Str);
        return $path if $path.e;
        return $path ~ '.bz2' if "$path.bz2".e;

    multi method set-identifier (Positional:D :@identifier!, :$purge-older-than)
        return self.set-identifier(:@identifier.join, :$purge-older-than);
    multi method set-identifier (Str:D: :$identifier!, :$purge-older-than)
        $!identifier64 = base64-encode($!identifier, :str);
        self!read-index
        if %!index{$identifier64}:exists
            if self!cache-file-exists(:cache-file(%!index{$identifier64})
                $!cache-file-name = %!index{$identifier64}
            else
                %!index{$identifier64}:delete
                self!write-index
        unless %!index{$identifier64}:exists
            $!cache-file-name = generated $!cache-file-name
        $!cache-file-path = $!cache-dir.add: $!cache-file-name;
        $!cache-hit = False
        if %!index{$identifier64}:exists & $!cache-file-path.e
            if $purge-older-than
                unlink($!cache-file-path) or die
                %!index{$identifier64}:delete
                self!write-index
            else
                $!cache-hit = True
        return $!cache-hit

    multi method fetch (:identifier, :$purge-older-than)
        return slurp(self.fetch-fh(:$identifier, :$purge-older-than), :close);
    multi method fetch-fh (:identifier, :$purge-older-than)
        return Nil unless self.set-identifier(:$identifier, :$purge-older-than)
        return $fh

    multi method store (:identifier, Positional:D :data)
    multi method store (:identifier, Str:D :data)
        self.set-identifier(:$identifier)
        %!index{$identifier64} ne $!cache-file-name
            unlink "$cache-dir/%!index{$identifier64}" if "$cache-dir/%!index{$identifier64}".IO.e
        %!index{$identifier64} = $!cache-file-name;
        $!cache-file-path.spurt($data) or die;
        $!cache-file-path.chmod(0o600) or die;
        self!write-index

    multi method store (:identifier, Str:D :path)
        self.store(:identifier, :path(IO::Path.new(:$path)));
    multi method store (:identifier, IO::Path:D :path)
        die unless path.e
        my $fh = open :r, $path
        die unless $fh;
        self.store(:identifier, :$fh)

    multi method store (:identifier, IO::Handle:D :$fh)
        self.set-identifier(:$identifier)
        %!index{$identifier64} ne $!cache-file-name
            unlink "$cache-dir/%!index{$identifier64}" if "$cache-dir/%!index{$identifier64}".IO.e
        %!index{$identifier64} = $!cache-file-name;
        if $fh.path.Str ne $cache-file-path.Str
            while $fh.get -> $record
                $cache-file-path.put: $record;
        self!write-index

AUTHOR
======
Mark Devine <mark@markdevine.com>
