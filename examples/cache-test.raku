#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
put '-' x 80;

my $cache   = Our::Cache.new;

$cache.store(:identifier<A>, :data<AAAAAAAAAAAAA>);
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
put '-' x 80;

$cache.store(:data<BBBBBBBBBBBBB>, :identifier(<B>));
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
put '-' x 80;

=finish

$cache.store(:data<bbbbbbbbbbbbb>, :identifier(<B>));
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
put '-' x 80;

=finish
