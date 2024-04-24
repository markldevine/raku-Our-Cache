unit module Our::Cache:api<1>:auth<Mark Devine (mark@markdevine.com)>;


#   - BREAK
#   - sub cache-path --> $cache-path
#       - resolve the directory name and create if ! -d
#       - convert the :$meta to base64
#           - base64-encode($meta, :str)
#       - if .index ~~ :s
#           - read
#               given $path.IO.open {
#                   .lock: :shared;  # Acquire a shared lock
#                   my %data = from-json(.slurp);  # Read data
#                   .close;  # Close the file
#               }
#               if :$meta entry found
#                   - cache hit --> return the name..............
#       - else
#           - create/append
#               my $index-fh = $path.IO.open(:a);
#               $index-fh.lock;  # Acquire an exclusive lock
#                   - create a new, unique, empty 8-character temp file in the directory
#                       given $temp-path.IO.open(:w) {
#                           .lock;  # Acquire an exclusive lock
#                           .close;  # Close the file
#                       }
#               $index-fh.spurt: to-json(%data);  # Write data
#               $index-fh.close;  # Close the file

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




        multi this now, separating the use cases.....




sub our-cache (Str :$cache-dir = &our-cache-dir(), Str:D :$identifier!, Str :$data, Instant :$expire-older-than) is export {
#   die 'Get &our-cache-dir() first!' unless "$cache-dir".IO.d;
    my $meta-id             = base64-encode($identifier, :str)
    my $index-path          = $cache-dir ~ '/.index';
    my $return-data         = $data with $data;
    my %index;
    given $index-path.IO.open(:rw) {
        .lock;
#   existing index...
        if $index-path.IO.s {
            %index          = from-json(.slurp);
            if %index{$meta-id}:exists {
#   - using an existing cache entry...
                my $data-file-path  = $cache-dir ~ '/' ~ %index{$meta-id};
                if $data-file-path.IO.e || $data-file-path ~ '.bz2'.IO.e {
#   - using an existing file...
                    if $data {
#   - writing new data...
                        spurt($data-file-path, $data, :close);
                        $data-file-path.IO.chmod(0o600);
                        compress($data-file-path) if $data.chars > (10 * 1024);
                    }
                    else {
#   - retrieving old data...
                        decompress($data-file-path ~ '.bz2') if $data-file-path ~ '.bz2'.IO.e;
                        $return-data = slurp($data-file-path);
                    }
                }
                elsif $data {
#   - writing new data...
                    spurt($data-file-path, $data, :close);
                    compress($data-file-path) if $data.chars > (10 * 1024);
                }
                else {
                    note 'Cache read miss: no data file for meta-id <' ~ $meta-id ~ '>';
                }
            }
#   add new, unique key to the existing index
            elsif $data {
                my $data-file-name;
                repeat {
                    $data-file-name = ("a".."z","A".."Z",0..9).flat.roll(32).join;
                    $data-file-name = '' if $cache-dir ~ '/' ~ $data-file-name.IO.e || $cache-dir ~ '/' ~ $data-file-name ~ '.bz2'.IO.e;
                } until $data-file-name;
                %index{meta-id}     = $data-file-name;
                spurt($cache-dir ~ '/' ~ $data-file-name, 
# spurt...
            }
        }
        else {
#   new index
            my $data-file-name;
            repeat {
                $data-file-name = ("a".."z","A".."Z",0..9).flat.roll(32).join;
                $data-file-name = '' if $cache-dir ~ '/' ~ $data-file-name.IO.e || $cache-dir ~ '/' ~ $data-file-name ~ '.bz2'.IO.e;
            } until $data-file-name;
            if $data {
                spurt($cache-dir ~ '/' ~ $data-file-name, $data);
                $cache-dir ~ '/' ~ $data-file-name.IO.chmod(0o600);
                compress($cache-dir ~ '/' ~ $data-file-name) if $data.chars > (10 * 1024);
                %index{$meta-id} = $data-file-name;
                .seek(0, SeekFromBeginning);
                .spurt(to-json(%index));
            }
            else {
                note 'cache miss';
            }
        }
        .close;
    }
    return $return-data;

=finish

    if "$cache-file-name".IO.e {
        if $expire-older-than && "$cache-file-name".IO.modified < $expire-older-than {
            unlink $cache-file-name if $expire-older-than && "$cache-file-name".IO.modified < $expire-older-than;
        }
        else {
            return slurp $cache-file-name;
        }
    }
}
