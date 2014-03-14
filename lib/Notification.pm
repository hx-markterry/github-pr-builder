package Notification;

use strict;
use warnings;
use WWW::Mechanize;
use JSON;
use Data::Dumper;
use File::Temp;

sub new{
  bless {}, shift;
}

sub poll{
  my $self = shift;
  my $url = "https://api.github.com/repos/holidayextras/tripapp-cordova/notifications";
  my $mech = $self->__mech();
  $mech->get($url);
  if($mech->success()){
    my $json = JSON->new();
    my $notices = $json->decode($mech->content());
    my @queue;
    foreach my $notice (@{$notices}){
      if($notice->{'reason'} eq "author"){
        push(@queue, {
          "title" => $notice->{'subject'}->{'title'},
          "url" => $notice->{'subject'}->{'url'}
        });
      }
    }
    $self->__processQueue([pop(@queue)]);
  }
}

#TODO lazy load here
sub __mech{
  my $mech = WWW::Mechanize->new();
  $mech->default_header('Authorization' => "token 874f077979c8c1672e528079f0a3a047967d7010");
  $mech;
}

sub __processQueue{
  my($self, $queue) = @_;
  foreach my $qItem (@{$queue}){
    $self->__processQueueItem($qItem);
  }
}

sub __processQueueItem{
  my($self, $item) = @_;
  print "PR Title: " . $item->{'title'} . "\n";
  print "PR URL: " . $item->{'url'} . "\n";
  my $mech = $self->__mech();
  $mech->get($item->{'url'});
  if($mech->success()){
    my $json = JSON->new();
    my $info = $json->decode($mech->content());
    print "PR Branch: " . $info->{'head'}->{'ref'} . "\n";
    my $dir = File::Temp->newdir(UNLINK => 0, CLEANUP => 0);
    print "Made temp directory: " . $dir->dirname . "\n";
    chdir($dir->dirname);
    $self->__runCommand("git clone " . $self->__cloneUrl($item->{'url'}));
    chdir("tripapp-cordova"); #TODO make configurable
    $self->__runCommand("make install");
  }
}

#TODO error checking
sub __cloneUrl{
  my $branch = pop;
  if($branch =~ m|/repos/(.+)/pulls/\d+$|){
    'git@github.com:' . $1 . '.git';
  }
}

sub __runCommand{
  my $command = pop;
  if(open(CLONE, "$command|")){
    while(<CLONE>){
      print $_;
    }
  }
}

return 1;
