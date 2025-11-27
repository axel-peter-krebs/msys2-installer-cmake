#!/usr/bin/perl
package msys2;
use strict;
use warnings;
use YAML::Syck;
use File::Copy;
use Class::Struct;
#use Cwd qw();
use File::Basename;

$YAML::Syck::ImplicitTyping = 1;

# The script must be run in the MSYS2 environment. It uses the GNU commands provided therein, 
# that is 'sh', 'perl', 'awk', 'sed' a.s.o. For a sample invocation s. msys2-installer.ps1 
# (Function 'Run_Install_Script').
# Install packages, files and execute commands; the 'recipe' is in the YAML file, cmp. Ansible.

# TODO: The successive steps contain file, command and package operations, which are executed in this order;
# however, sometimes you want a package OP to be executed first!
# Work-around: If package OP must be executed BEFORE file changes or commands, define a separate step.

my $version = "1.0";
my $arch = "mingw64";
my $msys2_version = "3";

struct ( TODO => 
    {
        'name' => '$',
        'description' => '$',
        'files' => '@',
        'packages' => '@',
        'commands' => '@'
    }
);

my @steps = ();

my $yaml_file_path = $ARGV[0];
my $msys2_install_root = $ARGV[1];

#my $path = Cwd::abs_path();
my $recipes_path = dirname($yaml_file_path);
my $path_separator = '\\'; 

if($yaml_file_path eq "") {
    print "A path to a YAML file must be provided as the first argument!";
}
else {
    print "->Will open YAML file: $yaml_file_path (source file path: $recipes_path)!";
    print "->Note: Eventual file changes will be made relative to the MSYS2 root in $msys2_install_root!\n";
    chdir($recipes_path) or die "$!"; # we need to access files provided with the recipe
    open my $fh, '<', $yaml_file_path or die "Can't open YAML file: $yaml_file_path!";
    my $yaml = LoadFile($fh);
    my %yamlHash = %$yaml; #bless $yaml, "Hash"
    #print Dump(%yamlHash);
    my $yamlVersion = $yamlHash{'version'};
    #print "Version: $yamlVersion\n";

    # Read the YAML 
    # The keys are pointers to a list of hashes
    for my $key ( keys %yamlHash ) {
        my $val = $yamlHash{"$key"};
        if( $key eq 'version' ) {
            $version = $key;
        }
        elsif ( $key eq 'msys2-version') {
            $msys2_version = $key;
        }
        elsif ( $key eq 'platform' ) {
            $arch = $key;
        }
        elsif ( $key eq 'steps') {
            foreach my $step_hash ( @{ $val } ) { # 'val' must be an array, 'step' is a hash
                #print "-> Adding step hash!\n";
                my $todo = TODO->new;
                foreach my $step_detail (keys %{ $step_hash } ) {
                    #print "-> Step detail: $step_detail\n";
                    if ( $step_detail eq "name") {
                        my $step_name = %$step_hash{'name'};
                        $todo->name($step_name);
                    }
                    elsif ( $step_detail eq "description") {
                        my $step_desc = %$step_hash{'description'};
                        $todo->description($step_desc);
                    }
                    elsif ( $step_detail eq "files") {
                        my $file_ops = %$step_hash{"files"};
                        $todo->files($file_ops);
                    }
                    elsif ( $step_detail eq "packages" ) {
                        my $package_ops = %$step_hash{"packages"};
                         $todo->packages($package_ops);
                    }
                    elsif (  $step_detail eq "commands" ) {
                        #print "Found commands ops!\n";
                        my $command_ops = %$step_hash{"commands"};
                        #foreach my $command ( @{ $command_ops }){
                            # push @{ $steps{'commands'} }, $command;
                        #    print "Command: $command\n";
                        #}
                        $todo->commands($command_ops);
                    }
                    else {
                        print "Unknown step detail encountered: $step_detail\n"
                    } 
                }
                push @steps, $todo;
            }
        }
    }
}

# 'Dry-run' ..
sub print_steps() {
    my $nr_steps = scalar @steps;
    print "\nIn directory: $recipes_path";
    print "\nUsing MSYS2 version: $msys2_version";
    print "\nUsing MSYS2 architecture: $arch";
    print "\n### steps [$nr_steps] ###";
    foreach my $todo ( @steps ) {
        my $todo_name = $todo->name();
        my $todo_desc = $todo->description();
        print "\n# STEP: $todo_name";
        print "\n\tDescription: $todo_desc";
        my $files_list = $todo->files();
        foreach my $file_op ( @{ $files_list }) {
            foreach my $file_name (keys %{ $file_op } ) {
                print "\n\tFile-OP: $file_name";
            }
        }
        my $commands_list = $todo->commands();
        foreach my $command_op ( @{ $commands_list }) {
            print "\n\tCommand-OP: $command_op";
        }
        my $packages_list = $todo->packages();
        foreach my $pkg_string ( @{ $packages_list }) {
            print "\n\tPackage-OP: $pkg_string";
        } 
    }
}

&print_steps();

sub execute_all() {
    foreach my $todo (@steps) {
        my $files_list = $todo->files;
        foreach my $file_ops_hash ( @{ $files_list }) {
            my $result = &file_op($file_ops_hash);
            print "\n=>OP-result: $result\n";
        }
        my $commands_list = $todo->commands;
        foreach my $command_string ( @{ $commands_list }) {
            my $result = &command_op($command_string);
            print "\n=>OP-result: $result\n";
        }
        my $packages_list = $todo->packages;
        foreach my $pkg_op ( @{ $packages_list }) {
            my $result = &package_op($pkg_op);
            print "\n=>OP-result: $result\n";
        } 
    }
}

&execute_all();

sub file_op() {
    my $file_hash = $_[0]; 
    for my $file_name (keys %$file_hash) { # array of a hash with a single entry (file name)..
        print "Changing file: $file_name\n"; 
        my $before_line = ""; # search line before for inserting 
        my $after_line = ""; # search line after for inserting 
        my @new_lines = (); # order is important!
        my $file_ops_hash = $file_hash->{$file_name}; # ..that in turn contain the operations on the files
        for my $file_op_key (%{ $file_ops_hash }) {
            print "OP-Key: $file_op_key\n";
            if($file_op_key eq 'target_dir') {
                my $target_dir = $file_ops_hash->{'target_dir'};
                print "Copying $file_name to $target_dir\n";
                my $source_file_path = $recipes_path . $path_separator . $file_name;
                system("cp", "-a", $source_file_path, "-t", $target_dir);
                return "File $source_file_path copied to $target_dir.";
            }
            elsif($file_op_key eq 'move') { #rename
                my $new_file_name = $file_ops_hash->{'move'};
                print "Moving $file_name to $new_file_name\n";
                system("mv", "-n", $file_name, $new_file_name);
                return "File $file_name changed to $new_file_name.";
            }
            elsif($file_op_key eq 'before_line') {
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

        # file manipulation
        if ($before_line ne "" && $after_line ne "") { # semantic error: for search, both markers may not be qualified at the same time!
            die "In YAML file operations, either 'before_line' or 'after_line' may be specified, but not both!";
        }
        elsif($before_line eq "" && $after_line eq "") { # The other way around: no search markers defined, this append!
            &append_lines($file_name, \@new_lines);
        }
        elsif($before_line ne "") { # insert before line
            insert_lines($file_name, $before_line, 0, \@new_lines);
        }
        elsif($after_line ne "") { # insert after line
            insert_lines($file_name, $after_line, 1, \@new_lines);
        }
        else {
            print("File operation not acknowledged!");
        }
    }
}

sub insert_lines() {
    my $file_path = $_[0];
    my $line_search = $_[1];
    my $after_or_before = $_[2];
    my @nls = @{$_[3]};

    # now, if this script runs more than once, it will produce duplicate output..
    # Therefore, decision here is to look for a .bak file..
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
    my $pacmanInstall = "pacman -S --needed --noconfirm $package";
    print "->Package operation: $pacmanInstall";
    my $output = `$pacmanInstall 2>&1`;
    return $output;
}

sub command_op() {
    #print "Command operations!\n";
    my $command_string = $_[0]; 
    #exec $command_string;
    print "->Command: $command_string";
    my $output = `$command_string 2>&1`;
    return $output;
}