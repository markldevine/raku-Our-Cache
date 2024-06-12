#!/usr/bin/env raku

my $base-dir    = '/home/mdevine/.rakucache/cache-test.raku';
my $dir         = $base-dir ~ '/QUFBQUFBQUFBQUFBQUFBQUFB/aaaaaaaaaaa/bbbbbbbbbb';
while $dir ne $base-dir {
    put "unlink($dir)";
    $dir        = $dir.subst(/ '/' <-[/]>+ $ /);
}
