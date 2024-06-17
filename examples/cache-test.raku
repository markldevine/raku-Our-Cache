#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;
#use Compress::Bzip2;
use Data::Dump::Tree;

my $cache;
my $data;
my $identifier;

run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;

sub Case1 {
#   simple store(), simple fetch()
    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'A' x 68;
    $cache          = Our::Cache.new(:$identifier);
    $cache.store(:$identifier, :data('DaTa' x 10));
#   run <cat /home/mdevine/.rakucache/cache-test.raku/QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFB/QUFBQUFBQUFBQUFBQUFBQUFBQUE=/collection-instant>;
    put " ";
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

#   simple fetch()
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $data           = $cache.fetch(:$identifier) or note '1: simple fetch';
    put $data       if $data;

#   fetch() with an $expire-after of now()
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $data           = $cache.fetch(:$identifier, :expire-after(now.DateTime)) or note '1: fetch with immediate expire';
    put $data       if $data;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    put '=' x 80; put "\n";
}

sub Case2 {
#   store() with now() expiration, attempt fetch()
    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'B' x 24;
    $cache          = Our::Cache.new(:$identifier);
    $cache.store(:$identifier, :data<BBBBBBBBBBBB>, :expire-after(DateTime.new(now - 1)));
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $data           = $cache.fetch(:$identifier) or note;
    put $data       if $data;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    put '=' x 80; put "\n";

#   fetch(), expecting immediate expiration
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $data = $cache.fetch(:$identifier) or note;
    put $data       if $data;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    put '=' x 80; put "\n";
}

Case1;
#Case2;

=finish

$cache.store(:$identifier, :data<AAAAAAAAAAAA>, :expire-after(now.DateTime));

#my $data = $cache.fetch(:$identifier, :expire-after(now.DateTime)) or note;

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
