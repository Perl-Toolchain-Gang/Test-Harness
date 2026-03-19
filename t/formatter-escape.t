use strict;
use warnings;

BEGIN {
    unshift @INC, 't/lib';
}

use Test::More tests => 6;
use TAP::Formatter::Console;

# Regression test for https://github.com/Perl-Toolchain-Gang/Test-Harness/issues/144
# prove must not emit raw ANSI escape sequences embedded in filenames

my $formatter = TAP::Formatter::Console->new;
$formatter->_longest(20);

# Helper: capture _format_name output
sub format_name {
    my $name = shift;
    return $formatter->_format_name($name);
}

# ESC character (starts ANSI sequences)
my $esc = "\x1b";

# 1. A plain filename is returned unchanged
my $plain = format_name('t/foo.t');
like $plain, qr{t/foo\.t}, 'plain filename appears in formatted output';

# 2. A filename with an embedded ESC must NOT contain a raw ESC byte
my $ansi_name = "t/file${esc}[31mred${esc}[0m.t";
my $formatted = format_name($ansi_name);
unlike $formatted, qr/\x1b/, 'formatted name with ANSI filename has no raw ESC byte';

# 3. Control chars in general must be escaped
my $ctrl_name = "t/file\x01\x02.t";
my $formatted_ctrl = format_name($ctrl_name);
unlike $formatted_ctrl, qr/[\x00-\x1f]/, 'formatted name has no raw control characters';

# 4. _sanitize_name method exists and works directly
can_ok $formatter, '_sanitize_name';

my $sanitized = $formatter->_sanitize_name("t/file${esc}[H.t");
unlike $sanitized, qr/\x1b/, '_sanitize_name removes raw ESC byte';
like $sanitized, qr/\\x\{1b\}/, '_sanitize_name replaces ESC with visible \\x{1b}';
