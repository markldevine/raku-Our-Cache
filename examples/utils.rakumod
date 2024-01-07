#!/usr/bin/env raku

use lib '/home/mdevine/github.com/raku-Our-Utilities/lib';
use Our::Utilities;

put 'byte-unit-to-bytes("1 M")                  = ' ~ byte-unit-to-bytes('1 M');
put 'bytes-to-byte-unit(211231231231)           = ' ~ bytes-to-byte-unit(211231231231);
put "number-metric-unit-to-number('211.2 G')    = " ~ number-metric-unit-to-number('211.2 G');
put 'rat-to-metric-unit(211231231231)           = ' ~ rat-to-metric-unit(211231231231);
my $seconds = (now - DateTime.new(:1965year, :3month, :20day, :0hour, :37minute, :0second)).Int;
put "seconds-to-y-d-hh-mm-ss($seconds)        = " ~ seconds-to-y-d-hh-mm-ss($seconds);
put 'integer-to-subscript(1234567890)           = ' ~ integer-to-subscript(1234567890);
put 'integer-to-superscript(1234567890)         = ' ~ integer-to-superscript(1234567890);
put 'add-commas-to-integer(1234567890)          = ' ~ add-commas-to-integer(1234567890);
put 'add-commas-to-integer(-1234567890)         = ' ~ add-commas-to-integer(-1234567890);
put "string-to-date-time('3/5/2023 9:35:01')    = " ~ string-to-date-time('3/5/2023 9:35:01');
put "string-to-date-time('3-5-2023 9:35:02')    = " ~ string-to-date-time('3-5-2023 9:35:02');
put "string-to-date-time('3/05/2023 9:35:03')   = " ~ string-to-date-time('3/05/2023 9:35:03');
put "string-to-date-time('3-05-2023 9:35:04')   = " ~ string-to-date-time('3-05-2023 9:35:04');
put "string-to-date-time('03/5/2023 9:35:05')   = " ~ string-to-date-time('03/5/2023 9:35:05');
put "string-to-date-time('03-5-2023 9:35:06')   = " ~ string-to-date-time('03-5-2023 9:35:06');
put "string-to-date-time('03/05/2023 9:35:07')  = " ~ string-to-date-time('03/05/2023 9:35:07');
put "string-to-date-time('03-05-2023 9:35:08')  = " ~ string-to-date-time('03-05-2023 9:35:08');
put "string-to-date-time('2023/3/5 9:35:09')    = " ~ string-to-date-time('2023/3/5 9:35:09');
put "string-to-date-time('2023-3-5 9:35:10')    = " ~ string-to-date-time('2023-3-5 9:35:10');
put "string-to-date-time('2023/3/05 9:35:11')   = " ~ string-to-date-time('2023/3/05 9:35:11');
put "string-to-date-time('2023-3-05 9:35:12')   = " ~ string-to-date-time('2023-3-05 9:35:12');
put "string-to-date-time('2023/03/5 9:35:13')   = " ~ string-to-date-time('2023/03/5 9:35:13');
put "string-to-date-time('2023-03-5 9:35:14')   = " ~ string-to-date-time('2023-03-5 9:35:14');
put "string-to-date-time('2023/03/05 9:35:15')  = " ~ string-to-date-time('2023/03/05 9:35:15');
put "string-to-date-time('2023-03-05 9:35:16')  = " ~ string-to-date-time('2023-03-05 9:35:16');

=finish
