package TAPx::Parser::Grammar;

use strict;
use vars qw($VERSION);

use TAPx::Parser::Result;

=head1 NAME

TAPx::Parser::Grammar - A grammar for the original TAP version.

=head1 VERSION

Version 0.51

=cut

$VERSION = '0.51';

=head1 DESCRIPTION

C<TAPx::Parser::Gramamr> is actually just a means for identifying individual
chunks (usually lines) of TAP.

Do not attempt to use this class directly.  It won't make sense.  It's mainly
here to ensure that we will be able to have pluggable grammars when TAP is
expanded at some future date (plus, this stuff was really cluttering the
parser).

Note that currently all methods are class methods.  It's intended that this
will eventually support C<TAP 2.0> and beyond which will necessitate actual
instance data, but for now, we don't need this.  Hence, the curious decision
to use a class where one doesn't apparently need one.

=cut

##############################################################################

=head2 Class Methods


=head3 C<new>

  my $grammar = TAPx::Grammar->new;

Returns TAP grammar object.  Future versions may accept a version number.

=cut

sub new {
    my ($class) = @_;
    bless {}, $class;
}

# XXX the 'not' and 'ok' might be on separate lines in VMS ...
my $ok  = qr/(?:not )?ok\b/;
my $num = qr/\d+/;

# description is *any* which is not followed by an odd number of escapes
# following by '#':  \\\#   \#
my $description = qr/.*?(?!\\(?:\\\\)*)#?/;

# if we have an even number of escapes in front of the '#', assert that it
# does not have an escape in front of it (this gets around the 'no variable
# length lookbehind assertions')
my $directive = qr/
                     (?<!\\)(?:\\\\)*
                     (?i:
                       \#\s+
                       (TODO|SKIP)\b
                       (.*)
                     )?
                   /x;

my %token_for = (
    version => {
        syntax  => qr/^TAP\s+version\s+(\d+)\s*\z/i,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__version_token_handler';
            my $version = $1;
            return $self->_make_version_token(
                $line,
                $version,
            );
        }
    },
    plan => {
        syntax  => qr/^1\.\.(\d+)(?:\s*#\s*SKIP\b(.*))?\z/i,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__plan_token_handler';
            my $tests_planned = $1;
            my $explanation   = $2;
            my $skip =
              ( 0 == $tests_planned || defined $explanation )
              ? 'SKIP'
              : '';
            $explanation = '' unless defined $explanation;
            return $self->_make_plan_token(
                $line,
                $tests_planned,
                $skip,
                _trim($explanation),
            );
        },
    },
    test => {
        syntax => qr/^
            ($ok)
            \s*
            ($num)?
            \s*
            ($description)?
            $directive    # $4 = directive, $5 = explanation
        \z/x,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__test_token_handler';
            my ( $ok, $num, $desc, $dir, $explanation )
              = ( $1, $2, $3, $4, $5 );
            return $self->_make_test_token(
                $line,
                $ok,
                $num,
                $desc,
                uc $dir,
                $explanation
            );
        },
    },
    comment => {
        syntax  => qr/^#(.*)/,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__comment_token_handler';
            my $comment = $1;
            return $self->_make_comment_token( $line, $comment );
        },
    },
    bailout => {
        syntax  => qr/^Bail out!\s*(.*)/,
        handler => sub {
            my ( $self, $line ) = @_;
            local *__ANON__ = '__ANON__bailout_token_handler';
            my $explanation = $1;
            return $self->_make_bailout_token( $line, _trim($explanation) );
        },
    },
);

##############################################################################

=head3 C<tokenize>

  my $token = $grammar->tokenize($string);

Passed a line of TAP, this method will return a data structure representing a
'token' matching that line of TAP input.  Designed to be passed to
C<TAPx::Parser::Result> to create a result object.

This is really the only method you need to worry about for the grammar.  The
methods below are merely for convenience, if needed.

=cut

sub tokenize {
    my $self = shift;
    return unless @_ && defined $_[0];

    my $line = shift;
    my $token;

    foreach my $token_data ( values %token_for ) {
        if ( $line =~ $token_data->{syntax} ) {
            my $handler = $token_data->{handler};
            $token = $self->$handler($line);
            last;
        }
    }
    $token ||= $self->_make_unknown_token($line);
    return defined $token ? TAPx::Parser::Result->new($token) : ();
}

##############################################################################

=head2 Class methods

=head3 C<token_types>

  my @types = $grammar->token_types;

Returns the different types of tokens which this grammar can parse.

=cut

sub token_types { keys %token_for }

##############################################################################

=head3 C<syntax_for>

  my $syntax = $grammar->syntax_for($token_type);

Returns a pre-compiled regular expression which will match a chunk of TAP
corresponding to the token type.  For example (not that you should really pay
attention to this, C<< $grammar->syntax_for('comment') >> will return
C<< qr/^#(.*)/ >>.

=cut

sub syntax_for {
    my ( $proto, $type ) = @_;
    return $token_for{$type}{syntax};
}

##############################################################################

=head3 C<handler_for>

  my $handler = $grammar->handler_for($token_type);

Returns a code reference which, when passed an appropriate line of TAP,
returns the lexed token corresponding to that line.  As a result, the basic
TAP parsing loop looks similar to the following:

 my @tokens;
 my $grammar = TAPx::Grammar->new;
 LINE: while ( defined( my $line = $parser->_next_chunk_of_tap ) ) {
     foreach my $type ( $grammar->token_types ) {
         my $syntax  = $grammar->syntax_for($type);
         if ( $line =~ $syntax ) {
             my $handler = $grammar->handler_for($type);
             push @tokens => $grammar->$handler($line);
             next LINE;
         }
     }
     push @tokens => $grammar->_make_unknown_token($line);
 }

=cut

sub handler_for {
    my ( $proto, $type ) = @_;
    return $token_for{$type}{handler};
}

sub _make_version_token {
    my ( $self, $line, $version ) = @_;
    return {
        type          => 'version',
        raw           => $line,
        version       => $version,
    };
}

sub _make_plan_token {
    my ( $self, $line, $tests_planned, $skip, $explanation ) = @_;
    if ( 0 == $tests_planned ) {
        $skip ||= 'SKIP';
    }
    if ( $skip && 0 != $tests_planned ) {
        warn
          "Specified SKIP directive in plan but more than 0 tests ($line)\n";
    }
    return {
        type          => 'plan',
        raw           => $line,
        tests_planned => $tests_planned,
        directive     => $skip,
        explanation   => $explanation,
    };
}

sub _make_test_token {
    my ( $self, $line, $ok, $num, $desc, $dir, $explanation ) = @_;
    my %test = (
        ok          => $ok,
        test_num    => $num,
        description => _trim($desc),
        directive   => uc($dir),
        explanation => _trim($explanation),
        raw         => $line,
        type        => 'test',
    );
    return \%test;
}

sub _make_unknown_token {
    my ( $self, $line ) = @_;
    return {
        raw  => $line,
        type => 'unknown',
    };
}

sub _make_comment_token {
    my ( $self, $line, $comment ) = @_;
    return {
        type    => 'comment',
        raw     => $line,
        comment => _trim($1)
    };
}

sub _make_bailout_token {
    my ( $self, $line, $explanation ) = @_;
    return {
        type    => 'bailout',
        raw     => $line,
        bailout => _trim($1)
    };
}

sub _trim {
    my $data = shift || '';
    $data =~ s/^\s+//;
    $data =~ s/\s+$//;
    return $data;
}

=head1 TAP GRAMMAR

B<NOTE:>  This grammar is slightly out of date.  There's still some discussion
about it and a new one will be provided when we have things better defined.

The C<TAPx::Parser> does not use a formal grammar because TAP is essentially a
stream-based protocol.  In fact, it's quite legal to have an infinite stream.
For the same reason that we don't apply regexes to streams, we're not using a
formal grammar here.  Instead, we parse the TAP in lines.

For purposes for forward compatability, any result which does not match the
following grammar is currently referred to as
L<TAPx::Parser::Result::Unknown>.  It is I<not> a parse error.

A formal grammar would look similar to the following:

 (* 
     For the time being, I'm cheating on the EBNF by allowing 
     certain terms to be defined by POSIX character classes by
     using the following syntax:
 
       digit ::= [:digit:]
 
     As far as I am aware, that's not valid EBNF.  Sue me.  I
     didn't know how to write "char" otherwise (Unicode issues).  
     Suggestions welcome.
 *)
 
 tap            ::= version? { comment | unknown } leading_plan lines 
                    | 
                    lines trailing_plan {comment}
 
 version        ::= 'TAP version ' positiveInteger {positiveInteger} "\n"

 leading_plan   ::= plan skip_directive? "\n"

 trailing_plan  ::= plan "\n"

 plan           ::= '1..' nonNegativeInteger
 
 lines          ::= line {line}

 line           ::= (comment | test | unknown | bailout ) "\n"
 
 test           ::= status positiveInteger? description? directive?
 
 status         ::= 'not '? 'ok '
 
 description    ::= (character - (digit | '#')) {character - '#'}
 
 directive      ::= todo_directive | skip_directive

 todo_directive ::= hash_mark 'TODO' ' ' {character}

 skip_directive ::= hash_mark 'SKIP' ' ' {character}

 comment        ::= hash_mark {character}

 hash_mark      ::= '#' {' '}

 bailout        ::= 'Bail out!' {character}

 unknown        ::= { (character - "\n") }

 (* POSIX character classes and other terminals *)
 
 digit              ::= [:digit:]
 character          ::= ([:print:] - "\n")
 positiveInteger    ::= ( digit - '0' ) {digit}
 nonNegativeInteger ::= digit {digit}
 

=cut

1;
