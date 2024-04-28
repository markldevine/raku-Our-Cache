#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;

#our-cache(:identifier('AAA'), :data('A' x 26));
#run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>;
#put our-cache(:identifier('AAA'));
#our-cache(:identifier('AAA'), :data('B' x 26));
#put our-cache(:identifier('AAA'));
#my $data = our-cache(:identifier('AAA'), :expire-older-than(now));
#put $data ?? $data !! '$data is empty';

for 'A' .. 'Z' -> $i {
#   our-cache(:identifier($i x 3), :data($i x (1024 * 11)));
    put our-cache(:identifier($i x 3));
}

=finish
