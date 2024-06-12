#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;
#use Compress::Bzip2;
use Data::Dump::Tree;

run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;

#   Case: simple store(), simple fetch()
put '=' x 80;
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
my $identifier  = 'A' x 18;
my $cache       = Our::Cache.new(:$identifier);
$cache.store(:$identifier, :data<AAAAAAAAAAAA>);
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
my $data = $cache.fetch(:$identifier) or note;
put $data if $data;
put '=' x 80; put "\n";

#   Case: simple fetch()
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
$data = $cache.fetch(:$identifier) or note;
put $data if $data;
put '=' x 80; put "\n";

#   Case: fetch() with an $expire-after of now()
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
$data = $cache.fetch(:$identifier, :expire-after(now)) or note;
put $data if $data;
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
put '=' x 80; put "\n";

#   Case: store() with now() expiration, attempt fetch()
put '=' x 80;
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
$identifier     = 'B' x 24;
$cache          = Our::Cache.new(:$identifier);
$cache.store(:$identifier, :data<BBBBBBBBBBBB>, :expire-after(now - 1));
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
$data           = $cache.fetch(:$identifier) or note;
put $data if $data;
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
put '=' x 80; put "\n";

#   Case: fetch(), expecting immediate expiration
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
$data = $cache.fetch(:$identifier) or note;
put $data if $data;
run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
put '=' x 80; put "\n";

=finish

$cache.store(:$identifier, :data<AAAAAAAAAAAA>, :expire-after(now));

#my $data = $cache.fetch(:$identifier, :expire-after(now)) or note;

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
