package Notification;

use strict;
use warnings;
use WWW::Mechanize;
use JSON;
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
  my $runTime = $self->__lastRun();
  print "Last run: " . time2str($runTime) . "\n";
  $mech->get($self->__prUrl(), 'If-Modified-Since' => time2str($runTime));
  if($mech->status() == 200){ #some notifications
    my $prs = decode_json($mech->content());
    my @queue;
    foreach my $pr (@{$prs}){
      my $updatedTime = str2time($pr->{'created_at'});
      if($updatedTime > $runTime){  #PR has been updated since last run
        push(@queue, {
          "title" => $pr->{'title'},
          "url" => $pr->{'url'},
          "branch" => $pr->{'head'}->{'ref'},
          "number" => $pr->{'number'}
        });
      }
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
  $self->{'__config'} = decode_json($jsonConfig);
}

sub __lastRun{
  my $lastRun = time - (60 * 60);  #use last hour on first run
  if(-e ".lastrun"){
    $lastRun = read_file(".lastrun");
  }
  $lastRun;
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
  my $result = 1; #fail by default
  $result = system("git clone " . $self->__cloneUrl());
  unless($result){
    chdir($self->__config()->{'repoName'});
    $result = system("git checkout " . $item->{'branch'});
    unless($result){
      $result = system($self->__config()->{'buildCommand'});
    }
  }
  $self->__setPrStatus($item, !!$result);
}

sub __setPrStatus{
  my($self, $item, $result) = @_;
  my $content = {
    "body" => $result ? ":construction_worker: Build passed" : ":construction:  Build failed"
  };
  my $mech = $self->__mech();
  $mech->post($self->__prCommentUrl($item), {}, Content => encode_json($content));
}

sub __cloneUrl{
  my $config = shift->__config();
  'git@github.com:' . $config->{'ownerName'} . '/' . $config->{'repoName'} . '.git';
}

sub __prUrl{
  my $config = shift->__config();
  "https://api.github.com/repos/" . $config->{'ownerName'} . "/" . $config->{'repoName'} . "/pulls?state=open&sort=created&direction=asc";
}

sub __prCommentUrl{
  my($self, $item) = @_;
  my $config = $self->__config();
  "https://api.github.com/repos/" . $config->{'ownerName'} . "/" . $config->{'repoName'} . "/issues/" . $item->{'number'} . "/comments";
}

return 1;
