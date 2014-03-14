package Notification;

use strict;
use warnings;
use WWW::Mechanize;
use JSON;
use Data::Dumper;
use File::Temp;
use File::Slurp;
use HTTP::Date;

sub new{
  my($class, $configFile) = @_;
  my $self = bless {}, $class;
  $self->__setConfig($configFile);
  $self;
}

sub poll{
  my $self = shift;
  my $mech = $self->__mech();
  $mech->get($self->__notificationUrl(), 'If-Modified-Since' => $self->__lastRun());
  if($mech->status() == 200){ #some notifications
    my $json = JSON->new();
    my $notices = $json->decode($mech->content());
    my @queue;
    foreach my $notice (@{$notices}){
      if($notice->{'reason'} eq "author"){  #new pull request made
        push(@queue, {
          "title" => $notice->{'subject'}->{'title'},
          "url" => $notice->{'subject'}->{'url'}
        });
      }
    }
    $self->__updateLastRun();
    $self->__processQueue([pop(@queue)]);
  }
}

sub __config{
  shift->{'__config'}
}

sub __setConfig{
  my($self, $file) = @_;
  my $jsonConfig = read_file($file);
  my $json = JSON->new();
  $self->{'__config'} = $json->decode($jsonConfig);
}

sub __lastRun{
  my $lastRun = time - (60 * 60);  #use last hour on first run
  if(-e ".lastrun"){
    $lastRun = read_file(".lastrun");
  }
  time2str($lastRun);
}

sub __updateLastRun{
  write_file(".lastrun", time);
}

sub __mech{
  my $self = shift;
  my $mech = WWW::Mechanize->new();
  $mech->default_header('Authorization' => "token " . $self->__config()->{'authToken'});
  $mech;
}

sub __processQueue{
  my($self, $queue) = @_;
  print "PRs Found: " . scalar @$queue . "\n";
  foreach my $qItem (@{$queue}){
    $self->__processQueueItem($qItem);
  }
}

sub __processQueueItem{
  my($self, $item) = @_;
  print "=" x 20 . "\n";
  print "PR Title: " . $item->{'title'} . "\n";
  print "PR URL: " . $item->{'url'} . "\n";
  my $mech = $self->__mech();
  $mech->get($item->{'url'});
  my $json = JSON->new();
  my $info = $json->decode($mech->content());
  print "PR Branch: " . $info->{'head'}->{'ref'} . "\n";
  my $dir = File::Temp->newdir(UNLINK => 0, CLEANUP => 0);
  print "Using directory: " . $dir->dirname . "\n";
  chdir($dir->dirname);
  $self->__runCommand("git clone " . $self->__cloneUrl());
  chdir($self->__config()->{'repoName'});
  $self->__runCommand("git checkout " . $info->{'head'}->{'ref'});
  $self->__runCommand($self->__config()->{'buildCommand'});
}

sub __cloneUrl{
  my $config = shift->__config();
  'git@github.com:' . $config->{'ownerName'} . '/' . $config->{'repoName'} . '.git';
}

sub __notificationUrl{
  my $config = shift->__config();
  "https://api.github.com/repos/" . $config->{'ownerName'} . "/" . $config->{'repoName'} . "/notifications";
}

sub __runCommand{
  if(open(CLONE, pop . "|")){
    while(<CLONE>){
      print $_;
    }
  }
}

return 1;
