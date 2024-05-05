#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

my $cache   = Our::Cache.new;

$cache.store(:identifier<A>, :data<AAAAAAAAAAAAA>); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;
$cache.store(:data<BBBBBBBBBBBBB>, :identifier(<B>)); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;
$cache.store(:data('b' x 10240), :identifier(<B>)); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;
my IO::Handle $fh = open :r, '/home/mdevine/bf';
$cache.store(:identifier(<B>), :$fh); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;

#put $cache.fetch(:identifier<A>);
$ = $cache.fetch(:identifier<B>);

=finish
