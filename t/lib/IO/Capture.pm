package IO::Capture;

use IO::Handle;

=head1 Name

t/lib/IO::Capture - a wafer-thin test support package

=head1 Why!?

Compatibility with 5.5.3 and no external dependencies.

=head1 Usage

Works with a global filehandle:

    # set a spool to write to
    tie local *STDOUT, 'IO::Capture';
    ...
    # clear and retrieve buffer list
    my @spooled = tied(*STDOUT)->dump();

Or, a lexical (and autocreated) filehandle:

    my $capture = IO::Capture->new_handle;
    ...
    my @output = tied($$capture)->dump;

Note the '$$' dereference.

=cut

# XXX actually returns an IO::Handle :-/
sub new_handle {
    my $class  = shift;
    my $handle = IO::Handle->new;
    tie $$handle, $class;
    return ($handle);
}

sub TIEHANDLE {
    return bless [], __PACKAGE__;
}

sub PRINT {
    my $self = shift;

    push @$self, @_;
}

sub PRINTF {
    my $self = shift;
    push @$self, sprintf(@_);
}

sub dump {
    my $self = shift;
    my @got  = @$self;
    @$self = ();
    return @got;
}

1;

# vim:ts=4:sw=4:et:sta
