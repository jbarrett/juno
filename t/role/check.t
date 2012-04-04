#!perl

use strict;
use warnings;

use Test::More tests => 25;
use Test::Fatal;

use Juno;
use AnyEvent;

my $count = 0;

# this will help us test the majority of things
{
    package Juno::Check::TestCheckZd7DD;
    use Any::Moose;
    with 'Juno::Role::Check';

    sub run {
        my $self = shift;
        Test::More::isa_ok( $self, 'Juno::Check::TestCheckZd7DD' );
        Test::More::ok( $self->does('Juno::Role::Check'), 'Does check role' );

        Test::More::ok( $self->has_on_success, 'Got on_success' );
        Test::More::ok( $self->has_on_fail,    'Got on_fail'    );
        Test::More::ok( $self->has_on_result,  'Got on_result'  );

        Test::More::is(
            $self->on_success->(),
            'success!',
            'Correct on_success',
        );

        Test::More::is(
            $self->on_fail->(),
            'fail!',
            'Correct on_fail',
        );

        Test::More::is(
            $self->on_result->(),
            'result!',
            'Correct on_result',
        );

        Test::More::is_deeply(
            $self->hosts,
            ['A', 'B'],
            'Hosts provided by Juno.pm',
        );

        Test::More::cmp_ok(
            $self->interval,
            '==',
            30,
            'Interval provided by Juno.pm',
        );
    }
}

# this helps us check that attributes were overwritten
{
    package Juno::Check::TestCheckF7A23;
    use Any::Moose;
    with 'Juno::Role::Check';

    sub run {
        my $self = shift;
        Test::More::isa_ok( $self, 'Juno::Check::TestCheckF7A23' );
        Test::More::ok( $self->does('Juno::Role::Check'), 'Does check role' );

        Test::More::is_deeply(
            $self->hosts,
            ['C', 'D'],
            'Hosts were overwritten',
        );

        Test::More::cmp_ok(
            $self->interval,
            '==',
            40,
            'Interval was overwritten',
        );
    }
}

# this helps us check that the check() method actually works
{
    package Juno::Check::TestCheckFzVS33;
    use Any::Moose;
    with 'Juno::Role::Check';

    sub check {
        my $self = shift;
        Test::More::isa_ok( $self, 'Juno::Check::TestCheckFzVS33' );
        Test::More::ok( $self->does('Juno::Role::Check'), 'Does check role' );

        $count++;

        $self->on_success->( $self, 'finished' );
    }
}

# uses the first check
{
    my $juno = Juno->new(
        hosts    => ['A', 'B'],
        interval => 30,
        checks   => {
            TestCheckZd7DD => {
                on_success => sub { 'success!' },
                on_fail    => sub { 'fail!'    },
                on_result  => sub { 'result!'  },
            },
        },
    );

    isa_ok( $juno, 'Juno' );

    $juno->run;
}

# uses the second check
{
    my $juno = Juno->new(
        hosts  => ['A', 'B'],
        checks => {
            TestCheckF7A23 => {
                hosts    => ['C', 'D'],
                interval => 40,
            },
        },
    );

    isa_ok( $juno, 'Juno' );

    $juno->run;
}

# uses the third check
{
    my $cv   = AnyEvent->condvar;
    my $juno = Juno->new(
        interval => 1,
        checks   => {
            TestCheckFzVS33 => {
                on_success => sub {
                    my $self = shift;
                    my $msg  = shift;

                    isa_ok( $self, 'Juno::Check::TestCheckFzVS33' );
                    is( $msg, 'finished', 'Got correct msg' );

                    $count == 2 and $cv->send;
                },
            },
        },
    );

    isa_ok( $juno, 'Juno' );

    $juno->run;

    $cv->recv;
}
