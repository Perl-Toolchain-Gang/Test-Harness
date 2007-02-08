#!/usr/bin/perl -wT

use strict;

use lib 'lib';
use TAPx::Base;

use Test::More tests => 30;

{
    # No callbacks allowed
    can_ok 'TAPx::Base', 'new';
    ok my $base = TAPx::Base->new(), 'object creation succeeds';
    isa_ok $base, 'TAPx::Base', 'object of correct type';
    foreach my $method (qw(callback _croak _callback_for _initialize)) {
        can_ok $base, $method;
    }

    eval {
        $base->callback( some_event => sub {
            # do nothing
        } );
    };
    like($@, qr/No callbacks/, 'no callbacks allowed croaks OK');
    my $cb = $base->_callback_for( 'some_event' );
    ok(!$cb, 'no callback installed');
}

{
    # No callbacks allowed, constructor should croak
    eval {
        my $base = TAPx::Base->new( {
            callbacks => {
                some_event => sub {
                    # do nothing
                }
            }
        } );
    };
    like($@, qr/No callbacks/, 'no callbacks in constructor croaks OK');
}

package CallbackOK;
use lib 'lib';
use TAPx::Base;
use vars qw(@ISA);
@ISA = 'TAPx::Base';

sub _initialize {
    my $self = shift;
    my $args = shift;
    $self->SUPER::_initialize( $args, [ qw( nice_event other_event ) ] );
    return $self;
}

package main;
{
    ok my $base = CallbackOK->new(), 'object creation succeeds';
    isa_ok $base, 'TAPx::Base';

    eval {
        $base->callback( some_event => sub {
            # do nothing
        } );
    };
    like($@, qr/Callback some_event/, 'illegal callback croaks OK');

    my ($nice, $other) = (0, 0);

    eval {
        $base->callback( other_event => sub { $other-- } );
        $base->callback( nice_event  => sub { $nice++; return shift() . 'OK' } );
    };

    ok(!$@, 'callbacks installed OK');

    my $nice_cb = $base->_callback_for( 'nice_event' );
    ok(ref $nice_cb eq 'CODE', 'callback for nice_event returned');
    my $got = $nice_cb->('Is ');
    is($got, 'Is OK', 'args passed to callback');
    cmp_ok($nice, '==', 1, 'callback calls the right sub');

    my $other_cb = $base->_callback_for( 'other_event' );
    ok(ref $other_cb eq 'CODE', 'callback for other_event returned');
    $other_cb->();
    cmp_ok($other, '==', -1, 'callback calls the right sub');
    
    $got = $base->_make_callback( 'nice_event', 'I am ' );
    is($got, 'I am OK', 'callback via _make_callback works');
}

{
    my ($nice, $other) = (0, 0);

    ok my $base = CallbackOK->new( {
        callbacks => {
            nice_event => sub { $nice++ }
        }
    } ), 'object creation with callback succeeds';

    isa_ok $base, 'TAPx::Base';

    eval {
        $base->callback( some_event => sub {
            # do nothing
        } );
    };
    like($@, qr/Callback some_event/, 'illegal callback croaks OK');

    eval {
        $base->callback( other_event => sub { $other-- } );
    };

    ok(!$@, 'callback installed OK');

    my $nice_cb = $base->_callback_for( 'nice_event' );
    ok(ref $nice_cb eq 'CODE', 'callback for nice_event returned');
    $nice_cb->();
    cmp_ok($nice, '==', 1, 'callback calls the right sub');

    my $other_cb = $base->_callback_for( 'other_event' );
    ok(ref $other_cb eq 'CODE', 'callback for other_event returned');
    $other_cb->();
    cmp_ok($other, '==', -1, 'callback calls the right sub');
    
    my $status = undef;
    # Replace callback
    $base->callback( other_event => sub { $status = 'OK' } );
    my $new_cb = $base->_callback_for( 'other_event' );
    ok(ref $new_cb eq 'CODE', 'new callback for other_event returned');
    $new_cb->();
    is($status, 'OK', 'new callback called OK');
}
