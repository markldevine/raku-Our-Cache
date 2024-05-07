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
            %!index = from-json($!index-path.slurp(:close))
        else
            %!index = ();
            self!write-index
        validate all %!index.keys point to a valid data file
            if any changes occurred
                self!write-index
        remove any orphan data files

    method !read-index
        die unless $!index-path.e
        return if $!index-modtime == $!index-path.modified;
        %!index = from-json($!index-path.slurp(:close))

    method !write-index
        $!index-path.spurt(to-json(%!index))    or die;
        $!index-path.chmod(0o600)               or die;
        $!index-modtime                         = $!index-path.modified

    multi method set-identifier (Positional:D :@identifier!, :$purge-older-than)
        return self.set-identifier(:@identifier.join, :$purge-older-than);
    multi method set-identifier (Str:D: :$identifier!, :$purge-older-than)

        $!identifier64 = base64-encode($!identifier, :str);

        self!read-index

        if $!index{$identifier64}:exists
            $!cache-file-name = $!index{$identifier64}
        else
            generate $!cache-file-name

        $!cache-file-path = $!cache-dir.add: $!cache-file-name;

        $!cache-hit = False
        if $!index{$identifier64}:exists & $!cache-file-path.e
            if $purge-older-than
                unlink($!cache-file-path) or die
                $!index{$identifier64}:delete
                self!write-index
            else
                $!cache-hit = True

    multi method fetch (:identifier, :$purge-older-than)
        return slurp(self.fetch-fh(:$identifier, :$purge-older-than), :close);
    multi method fetch-fh (:identifier, :$purge-older-than)
        self.set-identifier(:$identifier, :$purge-older-than)
        return Nil unless $!cache-hit
        return $fh

    multi method store (:identifier, Positional:D :data)
    multi method store (:identifier, Str:D :data)
    multi method store (:identifier, Str:D :path)
    multi method store (:identifier, IO::Path:D :path)
        die unless path.e
        if $path.basename ~~ Cache-File-Name
            +   unlink("$!cache-dir/%!index{$!identifier64}") if "$!cache-dir/%!index{$!identifier64}".IO.e
                %!index{$!identifier64} = $path.basename;
        if $path.dirname ne $cache-dir
            +   rename unless %!index{$!identifier64} = $path.basename
            -   while .get
                    put $!cache-dir/%!index{$!identifier64}


        if $path.basename ~~ Cache-File-Name
            + $path.basename is usable...
            - read from path & write to new "$!cache-dir/%!index{$!identifier64}"
        if $path.dirname eq $cache-dir
            if $path.basename !~~ Cache-File-Name
                + rename to a Cache-File-Name

    multi method store (:identifier, IO::Handle:D :fh)
        self.set-identifier(:$identifier)
        if %!index{$!identifier64}:!exists
            +   %!index{$!identifier64} = $!cache-file-name
                write $index-path
            -   %!index{$!identifier64} ne $!cache-file-name    # can happen if the consumer gets the name from
                if "$!cache-dir/$!cache-file-name".IO.e
                    +   unlink "$!cache-dir/%!index{$!identifier64}"
                        
            

AUTHOR
======
Mark Devine <mark@markdevine.com>
