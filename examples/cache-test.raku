#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;

my $cache   = Our::Cache.new(:identifier<TESTID>);
$cache.store(:data<BBBBBBBBBBBBB>);
$cache.store(:data<AAAAAAAAAAAAA>);
put $cache.fetch;



run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;

=finish

put '-' x 80;
my %cache;

for 'A' .. 'B' -> $i {
    %cache{$i x 3} = Our::Cache.new(:identifier($i x 3))
}

for 'A' .. 'B' -> $i {
    my $cache-file-name = %cache{$i x 3}.generate-cache-file-name;
    %cache{$i x 3}.store(:data($i x ((1024 * 10) + 1)), :$cache-file-name);
}

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;

=finish
