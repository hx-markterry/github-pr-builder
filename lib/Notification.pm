package Notification;

use strict;
use warnings;
use WWW::Mechanize;
use JSON;
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
  print "Last run: " . $self->__lastRun() . "\n";
  $mech->get($self->__prUrl(), 'If-Modified-Since' => $self->__lastRun());
  if($mech->status() == 200){ #some notifications
    my $json = JSON->new();
    my $prs = $json->decode($mech->content());
    my @queue;
    foreach my $pr (@{$prs}){
      push(@queue, {
        "title" => $pr->{'title'},
        "url" => $pr->{'url'},
        "branch" => $pr->{'head'}->{'ref'}
      });
    }
    $self->__updateLastRun();
    $self->__processQueue(\@queue);
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
  my $mech = WWW::Mechanize->new();
  $mech->default_header('Authorization' => "token " . shift->__config()->{'authToken'});
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
  print "PR Branch: " . $item->{'branch'} . "\n\n";
  my $dir = File::Temp->newdir(UNLINK => 0, CLEANUP => 0, DIR => $self->__config()->{'buildDir'});
  print "Using directory: " . $dir->dirname . "\n";
  chdir($dir->dirname);
  $self->__runCommand("git clone " . $self->__cloneUrl());
  chdir($self->__config()->{'repoName'});
  $self->__runCommand("git checkout " . $item->{'branch'});
  $self->__runCommand($self->__config()->{'buildCommand'});
}

sub __cloneUrl{
  my $config = shift->__config();
  'git@github.com:' . $config->{'ownerName'} . '/' . $config->{'repoName'} . '.git';
}

sub __prUrl{
  my $config = shift->__config();
  "https://api.github.com/repos/" . $config->{'ownerName'} . "/" . $config->{'repoName'} . "/pulls?state=open&sort=created&direction=asc";
}

sub __runCommand{
  if(open(CLONE, pop . "|")){
    while(<CLONE>){
      print $_;
    }
    close(CLONE);
  }
}

return 1;
