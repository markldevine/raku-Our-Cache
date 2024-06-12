#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;
#use Compress::Bzip2;
use Data::Dump::Tree;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

my $identifier  = 'A' x 12;
my $cache       = Our::Cache.new(:$identifier);
$cache.store(:$identifier, :data<AAAAAAAAAAAA>);

ddt $cache;

run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

=finish

#run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
my $identifier = 'A' x 1;
#$cache.store(:$identifier, :data<AAAAAAAAAAAAA>); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;
my $data = $cache.fetch(:$identifier) or note;
put $data if $data;

$cache.store(:data<BBBBBBBBBBBBB>, :identifier(<B>)); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;
put $cache.fetch(:identifier(<B>));

#$cache.store(:data('b' x 10240), :identifier(<B>)); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;

=finish

my IO::Handle $fh = open :r, '/home/mdevine/bf';
$cache.store(:identifier(<B>), :$fh); run <find /home/mdevine/.rakucache/cache-test.raku/ -ls>; put '-' x 80;

#put $cache.fetch(:identifier<A>);
my $bv = $cache.fetch(:identifier<B>);
put $bv.chars;

=finish
