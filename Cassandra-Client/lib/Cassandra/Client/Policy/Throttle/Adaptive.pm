package Cassandra::Client::Policy::Throttle::Adaptive;

use parent 'Cassandra::Client::Policy::Throttle::Default';
use 5.010;
use strict;
use warnings;
use Time::HiRes qw/CLOCK_MONOTONIC/;
use Ref::Util qw/is_blessed_ref/;
use Cassandra::Client::Error::ClientThrottlingError;

sub new {
    my ($class, %args)= @_;
    return bless {
        ratio => $args{ratio} || 2,
        time => $args{time} || 120,

        window => [],
        window_success => 0,
        window_total => 0,
    }, $class;
}

sub _process_window {
    my ($self)= @_;
    my $now= Time::HiRes::clock_gettime(CLOCK_MONOTONIC);
    while (@{$self->{window}} && $self->{window}[0][0] < $now) {
        my $entry= shift @{$self->{window}};
        $self->{window_total}--;
        $self->{window_success}-- if $entry->[1];
    }
    return;
}

sub should_fail {
    my ($self)= @_;
    $self->_process_window;

    my $fail= ( rand() < (($self->{window_total} - ($self->{ratio} * $self->{window_success})) / ($self->{window_total} + 1)) );
    return unless $fail;

    $self->count(undef, 1);
    return Cassandra::Client::Error::ClientThrottlingError->new;
}

sub count {
    my ($self, $error, $force_error)= @_;

    return if is_blessed_ref($error) && $error->isa('Cassandra::Client::Error::ClientThrottlingError');

    $self->{window_total}++;
    my $success= !(is_blessed_ref($error) && $error->is_timeout) && !$force_error;
    push @{$self->{window}}, [ Time::HiRes::clock_gettime(CLOCK_MONOTONIC)+$self->{time}, $success ];
    $self->{window_success}++ if $success;
    return;
}

1;
