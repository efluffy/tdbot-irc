#!/usr/local/bin/perl

use warnings;
use strict;
use POE;
use POE::Component::IRC;

########
# Vars #
########

sub CHANNEL () { "#channel" }
our $botname = "TnDBot";
our $botuser = "TnDBot";
our $server = "abc.com";
our $port = "6667";

############
# End Vars #
############

our @people;
our @outpeople;

my ($irc) = POE::Component::IRC->spawn();

POE::Session->create(
       inline_states => {
               _start           => \&bot_start,
               irc_001          => \&on_connect,
               irc_public       => \&on_public,
               irc_join         => \&on_join,
               irc_part         => \&on_part,
               irc_quit         => \&on_part,
               irc_353          => \&on_names,
               irc_366          => \&end_names,
               irc_nick         => \&on_nick,
               irc_disconnected => \&on_disconnect,
       },
);

sub bot_start {
       $irc->yield(register => "all");
       $irc->yield(
               connect => {
                       Nick     => $botname,
                       Username => $botuser,
                       Ircname  => 'Foxbot 1.5 by xcXEON',
                       Server   => $server,
                       Port     => $port,
               }
       );
}

sub on_connect {
       $irc->yield(join => CHANNEL);
       $irc->yield(privmsg => CHANNEL, "$botname 1.5 Online, building user list.");
}

sub on_public {
       my ($who, $where, $msg) = @_[ARG0, ARG1, ARG2];
       my $nick    = (split /!/, $who)[0];
       if($msg =~ m/^\!spin/i) {
               my $numpeople = @people;
               if($numpeople <= 2) {
                       $irc->yield(privmsg => CHANNEL, "More people needed to play! Invite your friends!");
                       return 0;
               }
               ROLL:
               my $winner = int(rand($numpeople));
               if($people[$winner] eq $nick) {
                       goto ROLL;
               }
               elsif($people[$winner] eq $botname) {
                       goto ROLL;
               }
               elsif(grep { $_ eq $nick } @outpeople) {
                       $irc->yield(privmsg => CHANNEL, "You are currently inactive, $nick. Type \"!active $nick\" to enter the game.");
               }
               else {
                       $irc->yield(privmsg => CHANNEL, "$nick is spinning the bottle...");
                       $irc->yield(privmsg => CHANNEL, "The bottle stops and points to $people[$winner]!");
                       $irc->yield(privmsg => CHANNEL, "$nick says: Truth or Dare, $people[$winner]?");
               }

       }
       if($msg =~ m/^\!help/i) {
               $irc->yield(privmsg => CHANNEL, "Foxbot 1.2 Commands: \"!spin\" - Spins the bottle for active users. \"!inactive nickname\" - Sets a player to inactive. \"!active nickname\" - Sets a player active again. \"!users\" - Rebuilds the active user list.");
       }
       if($msg =~ m/^\!users/i) {
               undef @people;
               $irc->yield(names => CHANNEL);
               $irc->yield(privmsg => CHANNEL, "Rebuilding active user list, please wait...");
       }
       if($msg =~ m/^\!inactive/i) {
               my $nickin = (split / /, $msg)[1];
               if(!$nickin) {
                       $irc->yield(privmsg => CHANNEL, "You must specify someone to make inactive!");
                       return 0;
               }
               else {
                       foreach my $person (@people) {
                               if($person eq $nickin) {
                                       my ($index) = grep { $people[$_] eq $nickin } 0..$#people;
                                       splice(@people, $index, 1);
                                       push(@outpeople, $nickin);
                                       $irc->yield(privmsg => CHANNEL, "$nickin removed from the game! Type \"!active $nickin\" to re-add them.");
                                       return 0;
                               }
                       }
               }
               $irc->yield(privmsg => CHANNEL, "$nickin is already inactive, or doesn't exist.");
       }
       if($msg =~ m/^\!active/i) {
               my $nicka = (split / /, $msg)[1];
               if(!$nicka) {
                       $irc->yield(privmsg => CHANNEL, "You must specify someone to make active!");
                       return 0;
               }
               else {
                       foreach my $outperson (@outpeople) {
                               if($outperson eq $nicka) {
                                       my ($index) = grep { $outpeople[$_] eq $nicka } 0..$#outpeople;
                                       splice(@outpeople, $index, 1);
                                       push(@people, $nicka);
                                       $irc->yield(privmsg => CHANNEL, "$nicka added to the game! Type \"!inactive $nicka\" to remove them.");
                                       return 0;
                               }
                       }
               }
               $irc->yield(privmsg => CHANNEL, "$nicka is already active, or doesn't exist.");
       }

}

sub on_join {
       my ($who, $chan) = @_[ARG0, ARG1];
       my $nick = (split /!/, $who)[0];
       if($nick =~ m/$botname/) {
               return 0;
       }
       else {
               $irc->yield(privmsg => CHANNEL, "Welcome to $chan, $nick. :3");
               $irc->yield(privmsg => CHANNEL, "Type \"!help\" to find out how to use me!");
               push (@people, $nick);
       }
}

sub on_part {
       my ($who, $chan) = @_[ARG0, ARG1];
       my $nick = (split /!/, $who)[0];
       if(grep { $_ eq $nick } @people) {
               my ($index) = grep { $people[$_] eq $nick } 0..$#people;
               splice(@people, $index, 1);
       }
       else {
               my ($outindex) = grep { $outpeople[$_] eq $nick } 0..$#outpeople;
               splice(@outpeople, $outindex, 1);
       }
}

sub on_names {
       my ($where, $namesreply) = @_[ARG0, ARG1];
       my @names = (split / /, (split /:/, $namesreply)[1]);
       foreach my $name (@names) {
               if($name ne $botname) {
                       $name =~ s/^[\+\@\~\&\%]//;
                       if(!grep { m|$name?$| } @outpeople) {
                               push (@people, $name);
                       }
               }
       }
}

sub end_names {
       $irc->yield(privmsg => CHANNEL, "User list built!");
       $irc->yield(privmsg => CHANNEL, "Active people: @people");
       my $outpeoplenum = @outpeople;
       if($outpeoplenum > 0) {
               $irc->yield(privmsg => CHANNEL, "Inactive people: @outpeople");
       }
       else {
               $irc->yield(privmsg => CHANNEL, "Inactive people: None.");
       }
       $irc->yield(privmsg => CHANNEL, "Type \"!spin\" to play!");
}

sub on_nick {
       my ($who, $newnick) = @_[ARG0, ARG1];
       my $nick = (split /!/, $who)[0];
       if(grep { m|$nick?$| } @people) {
               my ($index) = grep { $people[$_] eq $nick } 0..$#people;
               splice(@people, $index, 1);
               push(@people, $newnick);
       }
       else {
               my ($index) = grep { $outpeople[$_] eq $nick } 0..$#outpeople;
               splice(@outpeople, $index, 1);
               push(@outpeople, $newnick);
       }
}

sub on_disconnect {
       undef(@people);
       undef(@outpeople);
}

$poe_kernel->run();

exit 0;
