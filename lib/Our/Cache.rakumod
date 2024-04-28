unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;

use Base64::Native;
use Compress::Bzip2;
use JSON::Fast;

sub our-cache-dir (Str :$subdir = $*PROGRAM.IO.basename) is export {
    my Str  $cache-dir  = $*HOME.Str;
    if $subdir.starts-with('/') {
        $cache-dir ~= '/' ~ $subdir;
    }
    else {
        $cache-dir ~= '/' ~ '.rakucache/' ~ $subdir;
    }
    unless "$cache-dir".IO.e {
        mkdir $cache-dir;
        $cache-dir.IO.chmod(0o700);
    }
    return $cache-dir;
}

#%%% consider Command::Async::Multi sending in 5000 at once...  Perhaps 'multi sub(:$data, :$identifier)' for standard updates & 'multi sub(:%id2data)' to address bulk updates...
#%%% 'multi sub(:@identifier)' for convenience of run() or Proc users who are working with Array
#%%% 'multi sub(:$identifier)' for string users

# read-only
multi sub our-cache (Str :$cache-dir = &our-cache-dir(), Str:D :$identifier!, Instant :$expire-older-than) is export {
    my $meta-id             = base64-encode($identifier, :str);
    my $index-path          = $cache-dir ~ '/.index';
    return Nil              unless $index-path.IO.s;
    my %index;
    Lock.new.protect: {
        %index              = from-json(slurp($index-path));
        if %index{$meta-id}:exists {
            my $data-file-path  = $cache-dir ~ '/' ~ %index{$meta-id};
            if $expire-older-than {
                if "$data-file-path.bz2".IO.e {
                    if "$data-file-path.bz2".IO.modified < $expire-older-than {
                        unlink "$data-file-path.bz2";
                        %index{$meta-id}:delete;
                    }
                }
                elsif "$data-file-path".IO.e {
                    if "$data-file-path".IO.modified < $expire-older-than {
                        unlink $data-file-path;
                        %index{$meta-id}:delete;
                    }
                }
                unless %index{$meta-id}:exists {
                    if %index.elems {
                        spurt($index-path, to-json(%index));
                        return Nil;
                    }
                    else {
                        unlink($index-path);
                        return Nil;
                    }
                }
            }
            if "$data-file-path.bz2".IO.e {
                decompress("$data-file-path.bz2");
                my $return-data = slurp($data-file-path);
                unlink($data-file-path);
                return $return-data;
            }
            return slurp($data-file-path);
        }
        return Nil;
    }
}

# write
multi sub our-cache (Str :$cache-dir = &our-cache-dir(), Str:D :$identifier!, Str:D :$data!) is export {
    return                  unless $data.chars;
    my $meta-id             = base64-encode($identifier, :str);
    my $index-path          = $cache-dir ~ '/.index';
    my %index;
    Lock.new.protect: {
        %index              = from-json(slurp($index-path)) if "$index-path".IO.e;
        if %index{$meta-id}:exists {
            my $data-file-path              = $cache-dir ~ '/' ~ %index{$meta-id};
            unlink "$data-file-path.bz2" if "$data-file-path.bz2".IO.e;
            spurt($data-file-path, $data);
            $data-file-path.IO.chmod(0o600);
            if $data.chars > (10 * 1024) {
                compress($data-file-path);
                unlink($data-file-path);
            }
        }
        else {
            my $data-file-name;
            repeat {
                $data-file-name             = ("a".."z","A".."Z",0..9).flat.roll(16).join;
                $data-file-name             = '' if "$cache-dir/$data-file-name".IO.e || "$cache-dir/$data-file-name.bz2".IO.e;
            } until $data-file-name;
            %index{$meta-id}                = $data-file-name;
            spurt("$cache-dir/$data-file-name", $data);
            spurt($index-path, to-json(%index));
            "$cache-dir/$data-file-name".IO.chmod(0o600);
            if $data.chars > (10 * 1024) {
                compress("$cache-dir/$data-file-name");
                unlink("$cache-dir/$data-file-name");
            }
        }
    }
}

=finish
