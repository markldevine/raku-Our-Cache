#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Cache/lib';
use Our::Cache;
#use Compress::Bzip2;
use Data::Dump::Tree;

my $cache;
my $data;
my $identifier;

Case1;
#Case2;
#Case3;
#Case4;
#Case5;

sub Case1 {
#   run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;
#   simple store(), simple fetch()
    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'A' x 68;
    $cache          = Our::Cache.new(:$identifier);
#   $cache.store(:$identifier, :data('DaTa' x 10), :expire-after(DateTime.new(now + 10))) or note;
    $cache.store(:data('DaTa' x 10), :expire-after(DateTime.new(now + 10))) or note;
#   run <cat /home/mdevine/.rakucache/cache-test.raku/QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFB/QUFBQUFBQUFBQUFBQUFBQUFBQUE=/collection-instant>;
    put " ";
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

#   simple fetch()
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
#   $data           = $cache.fetch(:$identifier) or note '1: simple fetch';
    $data           = $cache.fetch or note '1: simple fetch';
    put $data       if $data;

#   fetch() with an $expire-after of now()
#   run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
#   $data           = $cache.fetch(:$identifier, :expire-after(now.DateTime)) or note '1: fetch with immediate expire';
#   $data           = $cache.fetch(:expire-after(now.DateTime)) or note '1: fetch with immediate expire';
#   put $data       if $data;
#   run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    put '=' x 80; put "\n";
}

sub Case2 {
    run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;
#   store() with now() expiration, attempt fetch()
    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'B' x 24;
    $cache          = Our::Cache.new(:$identifier);
    $cache.store(:$identifier, :data<BBBBBBBBBBBB>, :expire-after(DateTime.new(now - 1))) or note;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    put '=' x 80; put "\n";
}

sub Case3 {
#   conditional store(), fetch() which could possibly be data from history
    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'C' x 6;
    $cache          = Our::Cache.new(:$identifier);
    unless $cache.cache-hit {
        $cache.store(:$identifier, :data('DaTa' x 1024)) or note;
    }

#   simple fetch()
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $data           = $cache.fetch(:$identifier) or note '3: simple fetch from existing cache';
    put $data       if $data;
    put '=' x 80; put "\n";
}

sub Case4 {
#   rename from local source

    run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;

    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'D' x 4;

    $cache          = Our::Cache.new(:$identifier);
    my $p           = $cache.temp-write-path;

    spurt($p, 'D' x 1024) or note;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

    $cache.store(:$identifier, :path($p), :purge-source);
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;

    put '=' x 80; put "\n";
}

sub Case5 {
#   copy from distant source (keep source)

    run <rm -rf /home/mdevine/.rakucache/cache-test.raku/> if "/home/mdevine/.rakucache/cache-test.raku".IO.d;

    put '=' x 80;
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    $identifier     = 'E' x 48;

    $cache          = Our::Cache.new(:$identifier);
    my $p           = '/tmp/cache-test.data';
    spurt($p, 'D' x 1024) or die;

    $cache.store(:$identifier, :path($p), :purge-source(False));
    run <find /home/mdevine/.rakucache/cache-test.raku/ -ls> if "/home/mdevine/.rakucache/cache-test.raku".IO.d; put '-' x 80;
    run <<ls -l $p>>;

    put '=' x 80; put "\n";
}

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
