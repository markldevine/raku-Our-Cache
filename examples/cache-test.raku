#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
put '-' x 80;
my %cache;

for 'A' .. 'Z' -> $i {
    %cache{$i x 3} = Our::Cache.new(:identifier($i x 3)).store(:data($i x ((1024 * 10) + 1)));
}

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;

=finish
