#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw/$Bin/;
use local::lib "$Bin/../local";
use lib "lib";
use Notification;

my $notification = Notification->new("root/config.json");
$notification->poll();
exit(0);
