#!/usr/bin/perl
package msys2;
use strict;
use warnings;
use YAML::Syck;
use File::Copy qw(move);
use Class::Struct;

$YAML::Syck::ImplicitTyping = 1;

# Install packages, files and more; the 'recipe' is in the YAML file, cmp. Ansible.

struct ( TODO => 
    {
        'files' => '@',
        'packages' => '@',
        'commands' => '@'
    }
);

my @todos = ();

my $pacmanInstall = "pacman -S #pkg --noconfirm";

my $file_name = $ARGV[0];

if($file_name eq "") {
    print "A path to a YAML file must be provided as the first argument!";
}
else {
    open my $fh, '<', $file_name or die "Can't open YAML file: $!";
    my $yaml = LoadFile($fh);
    my %yamlHash = %$yaml; #bless $yaml, "Hash"
    #print Dump(%yamlHash);
    my $yamlVersion = $yamlHash{'version'};
    #print "Version: $yamlVersion\n";

    # Read the YAML 
    # The keys are pointers to a list of hashes
    for my $key ( keys %yamlHash ) {
        my $val = $yamlHash{"$key"}; 
        if ( $key eq 'steps') {
            foreach my $step_hash ( @{ $val } ) { # 'val' must be an array, 'step' is a hash
                foreach my $step_key (keys %{ $step_hash } ) {
                    my $todo = TODO->new;
                    my $step_detail_hash = %$step_hash{"$step_key"};
                    foreach my $step_detail (keys %{ $step_detail_hash }) {
                        if ( $step_detail eq "name") {
                            my $step_name = %$step_detail_hash{"name"};
                            print "Step name: $step_detail\n";
                        }
                        elsif ( $step_detail eq "files") {
                            my $file_ops = %$step_detail_hash{"files"};
                            foreach my $file_name_ops_hash ( @{ $file_ops } ) {
                                #push @{ $TODOS{'files'} }, $file_name_ops_hash;
                                #foreach my $file_name (keys %{ $file_name_ops_hash } ) {
                                #    print "Found file: $file_name\n";
                                #}
                                
                            }
                            $todo->files($file_ops);
                        }
                        elsif (  $step_detail eq "packages" ) {
                            my $package_ops = %$step_detail_hash{"packages"};
                            #foreach my $package ( @{ $package_ops } ) {
                                #push @{ $TODOS{'packages'} }, $package;
                                #print "Package: $package\n";
                            #}
                            $todo->packages($package_ops);
                        }
                        elsif (  $step_detail eq "commands" ) {
                            #print "Found commands ops!\n";
                            my $command_ops = %$step_detail_hash{"commands"};
                            #foreach my $command ( @{ $command_ops }){
                                # push @{ $TODOS{'commands'} }, $command;
                            #    print "Command: $command\n";
                            #}
                            $todo->commands($command_ops);
                        }
                        else {
                            print "Unknown step detail encountered: $step_detail\n"
                        }
                    }  
                    push @todos, $todo;  
                }
            }
        }
    }
}

# 'Dry-run' ..
sub print_todos() {
    my $nr_todos = scalar @todos;
    print "No. of TODOs: $nr_todos\n";
    foreach my $todo ( @todos ) {
        print "STEP\n";
        my $files_list = $todo->files;
        foreach my $file_op ( @{ $files_list }) {
            print "\tFile-OP: $file_op\n";
        }
        my $commands_list = $todo->commands;
        foreach my $command_op ( @{ $commands_list }) {
            print "\tCommand-OP: $command_op\n";
        }
        my $packages_list = $todo->packages;
        foreach my $pkg_op ( @{ $packages_list }) {
            print "\tPackage-OP: $pkg_op\n";
        } 
    }
}

&print_todos();

sub execute_all() {
    foreach my $todo (@todos) {
        my $files_list = $todo->files;
        foreach my $file_ops_hash ( @{ $files_list }) {
            print "Changing file: "; #TODO
            &file_op($file_ops_hash);
        }
        my $commands_list = $todo->commands;
        foreach my $command_string ( @{ $commands_list }) {
            print "Executing command: $command_string\n";
            my $result = &command_op($command_string);
            print "Result: $result\n";
        }
        my $packages_list = $todo->packages;
        foreach my $pkg_op ( @{ $packages_list }) {
            print "Installing package: $pkg_op\n";
            my $result = &package_op($pkg_op);
            print "Result: $result\n";
        } 
    }
}

&execute_all();

sub file_op() {
    my $file_ops_hash = $_[0]; 
    for my $file_name (keys %$file_ops_hash) { # array of a hash with a single entry (file name)..
        #print "File: $file_name\n"; 
        my $before_line = "";
        my $after_line = "";
        my @new_lines = (); # order is important!
        my $file_ops_hash = $file_ops_hash->{$file_name}; # ..that in turn contain the operations on the files
        for my $file_op_key (%{ $file_ops_hash }) {
            #print "$file_op_key\n";
            if($file_op_key eq 'before_line') {
                $before_line = $file_ops_hash->{'before_line'};
            }
            elsif($file_op_key eq 'after_line') {
                $after_line = $file_ops_hash->{'after_line'};
            }
            elsif($file_op_key eq 'new_lines') {
                my $new_lines = $file_ops_hash->{'new_lines'};
                foreach my $new_line (@$new_lines) { # order!
                    #print "Pushing new line: $new_line\n";
                    push @new_lines, $new_line;
                }
            }
        }
        if($before_line ne "" && $after_line ne "") {
            die "In YAML file operations, either 'before_line' or 'after_line' may be specified, but not both!";
        }
        elsif($before_line ne "") {
            insert_lines($file_name, $before_line, 0, \@new_lines);
        }
        elsif($after_line ne "") {
            insert_lines($file_name, $after_line, 1, \@new_lines);
        }
        else { # append
            &append_lines($file_name, \@new_lines);
        }
    }
}

sub insert_lines() {
    my $file_path = $_[0];
    my $line_search = $_[1];
    my $after_or_before = $_[2];
    my @nls = @{$_[3]};

    # now, if this script runs more than once, it will produce duplicate output..
    # Therefore decision here is to look for a .bak file..
    my $bak_file_path = "$file_path.bak";
    if ( -e $bak_file_path) {
        print "A backup file for $file_path ($file_path.bak) already exists - will omit operations!\n";
        return;
    }

    print "Inserting lines into $file_path at line $line_search";
    open my $fh, '<', $file_path or die "Can't open file: $!";
    my @new_file_lines = ();
    while ( my $cur_line = <$fh> ) {
        my $deferred = 0;
        if ( $cur_line =~ m/^\Q$line_search\E/ ) {
            if ( $after_or_before eq 0 ) { # before
                foreach my $new_line ( @nls ) {
                    push @new_file_lines, "$new_line\n";
                }
            }
            else {
                $deferred = 1
            }
        }
        push @new_file_lines, $cur_line; # always push old line
        if($deferred eq 1) {
            foreach my $new_line ( @nls ) {
                push @new_file_lines, "$new_line\n";
            }
        }
    };

    # TODO: has anything been changed??
    move $file_path, "$file_path.bak"; # rename old file
    close($fh);
    open my $newfh, '>', $file_path or die "Can't open file: $!"; # create new file with same name
    foreach (@new_file_lines) {
        print $newfh $_;
    }
    close ($newfh);
}

sub append_lines() {
    my $file_path = $_[0];
    print "Appending lines into $file_path\n"
}

sub package_op() {
    #print "Packages operations!\n";
    my $package = $_[0]; 
    $pacmanInstall =~ s/#pkg/$package/g;
    my $output = `$pacmanInstall 2>&1`;
    return $output;
}

sub command_op() {
    #print "Command operations!\n";
    my $command_string = $_[0]; 
    #exec $command_string;
    my $output = `$command_string 2>&1`;
    return $output;
}