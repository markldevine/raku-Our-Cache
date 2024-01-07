unit module Our::Utilities:api<1>:auth<Mark Devine (mark@markdevine.com)>;

constant \KILOBYTE  = 1024;
constant \MEGABYTE  = KILOBYTE  * KILOBYTE;
constant \GIGABYTE  = MEGABYTE  * KILOBYTE;
constant \TERABYTE  = GIGABYTE  * KILOBYTE;
constant \PETABYTE  = TERABYTE  * KILOBYTE;
constant \KILO      = 1000;
constant \MEGA      = KILO      * KILO;
constant \GIGA      = MEGA      * KILO;
constant \TERA      = GIGA      * KILO;
constant \PETA      = TERA      * KILO;
constant \SECOND    = 1;
constant \MINUTE    = 60        * SECOND;
constant \HOUR      = 60        * MINUTE;
constant \DAY       = 24        * HOUR;

sub byte-unit-to-bytes (Str:D $num-unit) is export {
    if $num-unit ~~ / ^ (\d+ '.'* \d*) \s* (\w*) $ / {
        my $actual  = $0.Str.comb.grep(/ \d | '.' /).join;
        my $unit    = $1.Str with $1;
        given $unit {
            when 'P'    { return $actual * PETABYTE }
            when 'T'    { return $actual * TERABYTE }
            when 'G'    { return $actual * GIGABYTE }
            when 'M'    { return $actual * MEGABYTE }
            when 'K'    { return $actual * KILOBYTE }
            default     { return $actual;           }
        }
    }
    return $num-unit;
}

sub bytes-to-byte-unit (Int:D $bytes) is export {
    given $bytes {
        when $_ >= PETABYTE { return ($bytes / PETABYTE).fmt("%.1f P"); }
        when $_ >= TERABYTE { return ($bytes / TERABYTE).fmt("%.1f T"); }
        when $_ >= GIGABYTE { return ($bytes / GIGABYTE).fmt("%.1f G"); }
        when $_ >= MEGABYTE { return ($bytes / MEGABYTE).fmt("%.1f M"); }
        when $_ >= KILOBYTE { return ($bytes / KILOBYTE).fmt("%.1f K"); }
        default             { return $bytes.fmt("%s B");                }
    }
}

sub number-metric-unit-to-number (Str:D $num-unit) is export {
    if $num-unit ~~ / ^ (\d+ '.'* \d*) \s* (\w*) $ / {
        my $actual  = $0.Str.comb.grep(/ \d | '.' /).join;
        my $unit    = $1.Str with $1;
        given $unit {
            when 'P'    { return $actual * PETA }
            when 'T'    { return $actual * TERA }
            when 'G'    { return $actual * GIGA }
            when 'M'    { return $actual * MEGA }
            when 'K'    { return $actual * KILO }
            default     { return $actual;       }
        }
    }
    return $num-unit;
}

sub number-to-metric-unit (Numeric:D $num is copy) is export {
    my $neg = False;
    if $num < 0 {
        $neg = True;
        $num *= -1;
    }
    given $num {
        when $_ >= PETA { return $neg ?? (-1 * ($num / PETA)).fmt("%.1f P") !! ($num / PETA).fmt("%.1f P"); }
        when $_ >= TERA { return $neg ?? (-1 * ($num / TERA)).fmt("%.1f T") !! ($num / TERA).fmt("%.1f T"); }
        when $_ >= GIGA { return $neg ?? (-1 * ($num / GIGA)).fmt("%.1f G") !! ($num / GIGA).fmt("%.1f G"); }
        when $_ >= MEGA { return $neg ?? (-1 * ($num / MEGA)).fmt("%.1f M") !! ($num / MEGA).fmt("%.1f M"); }
        when $_ >= KILO { return $neg ?? (-1 * ($num / KILO)).fmt("%.1f K") !! ($num / KILO).fmt("%.1f K"); }
        default         { return $neg ?? (-1 * $num) !! $num                                                }
    }
}

sub seconds-to-y-d-hh-mm-ss (Int:D $total-seconds) is export {
    my $years       = 0;
    my $days        = 0;
    my $hours       = 0;
    my $minutes     = 0;
    my $seconds     = $total-seconds;
    my $result;
    if $seconds >= 31557556 {
        $years      = ($seconds / 31557556).Int;
        $result     = $years ~ 'y ';
        $seconds   -= $years * 31557556;
    }
    if $seconds >= DAY {
        $days       = ($seconds / DAY).Int;
        $result    ~= $days ~ 'd ';
        $seconds   -= $days * DAY;
    }
    if $seconds >= HOUR {
        $hours      = ($seconds / HOUR).Int;
        $result    ~= $hours.fmt("%02d");
        $seconds   -= $hours * HOUR;
    }
    else {
        $result    ~= '00';
    }
    if $seconds >= MINUTE {
        $minutes    = ($seconds / MINUTE).Int;
        $result    ~= ':' ~ $minutes.fmt("%02d") ~ ':';
        $seconds   -= $minutes * MINUTE;
    }
    else {
        $result    ~= ':00:';
    }
    $seconds        = 0 if $seconds < 0;
    $result        ~= $seconds.fmt("%02d");
    return $result;
}

my @SUB-DIGITS;
@SUB-DIGITS[0]    = "\x[2080]";
@SUB-DIGITS[1]    = "\x[2081]";
@SUB-DIGITS[2]    = "\x[2082]";
@SUB-DIGITS[3]    = "\x[2083]";
@SUB-DIGITS[4]    = "\x[2084]";
@SUB-DIGITS[5]    = "\x[2085]";
@SUB-DIGITS[6]    = "\x[2086]";
@SUB-DIGITS[7]    = "\x[2087]";
@SUB-DIGITS[8]    = "\x[2088]";
@SUB-DIGITS[9]    = "\x[2089]";

sub integer-to-subscript (Int:D $i) is export {
    my $accumulator = '';
    for $i.Int.comb -> $c {
        $accumulator ~= @SUB-DIGITS[$c.Int];
    }
    return $accumulator;
}

my @SUPER-DIGITS;
@SUPER-DIGITS[0]    = "\x[2070]";
@SUPER-DIGITS[1]    = "\x[00B9]";
@SUPER-DIGITS[2]    = "\x[00B2]";
@SUPER-DIGITS[3]    = "\x[00B3]";
@SUPER-DIGITS[4]    = "\x[2074]";
@SUPER-DIGITS[5]    = "\x[2075]";
@SUPER-DIGITS[6]    = "\x[2076]";
@SUPER-DIGITS[7]    = "\x[2077]";
@SUPER-DIGITS[8]    = "\x[2078]";
@SUPER-DIGITS[9]    = "\x[2079]";

sub integer-to-superscript (Int:D $i) is export {
    my $accumulator = '';
    for $i.Int.comb -> $c {
        $accumulator ~= @SUPER-DIGITS[$c.Int];
    }
    return $accumulator;
}

sub add-commas-to-integer (Int:D $i is copy) is export {
    return $i.Str.flip.comb(3).join(',').flip if $i >= 0;
    $i *= -1;
    return '-' ~ $i.Str.flip.comb(3).join(',').flip;
}

my grammar String-to-Date-Time {
    token TOP               { <date> <dt-separator> <time>                              }
    token dt-separator      { . || \s+                                                  }
    token date              { <yyyymd> || <mdyyyy>                                      }
    token yyyymd            { <year> <month-separator> <month> <month-separator> <day>  }
    token mdyyyy            { <month> <month-separator> <day> <month-separator> <year>  }
    token month-separator   { '/' || '-'                                                }
    token year              { \d ** 4                                                   }
    token month             { \d ** 1..2                                                }
    token day               { \d ** 1..2                                                }
    token time              { <hour> ':' <minute> ':' <second>                          }
    token hour              { \d ** 1..2                                                }
    token minute            { \d ** 1..2                                                }
    token second            { \d ** 1..2                                                }
}

sub string-to-date-time (Str:D $date-time) is export {
    my $parse;
    my $year;
    my $month;
    my $day;
    my $hour;
    my $minute;
    my $second;
    if $parse = String-to-Date-Time.parse($date-time) {
        if $parse<date><yyyymd><year>:exists {
            $year   = $parse<date><yyyymd><year>.Str;
            $month  = $parse<date><yyyymd><month>.Str;
            $day    = $parse<date><yyyymd><day>.Str;
        }
        elsif $parse<date><mdyyyy><year>:exists {
            $year   = $parse<date><mdyyyy><year>.Str;
            $month  = $parse<date><mdyyyy><month>.Str;
            $day    = $parse<date><mdyyyy><day>.Str;
        }
        else {
            die 'Unable to determine <year> (should be impossible)';
        }
        $hour       = $parse<time><hour>.Str;
        $minute     = $parse<time><minute>.Str;
        $second     = $parse<time><second>.Str;
        return(DateTime.new(:$year, :$month, :$day, :$hour, :$minute, :$second));
    }
    return Nil;
}

=finish
