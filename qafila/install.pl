#!/usr/bin/perl
package msys2;
use strict;
use warnings;
use YAML::Syck;

$YAML::Syck::ImplicitTyping = 1;

# Install packages, files and more; the 'recipe' is in the YAML file, cmp. Ansible.

my $file_name = $ARGV[0]; 

if($file_name eq "") {
    print "A path to a YAML file must be provided as the first argument!";
}
else {
    open my $fh, '<', $file_name or die "Can't open YAML file: $!";
    my $yaml = LoadFile($fh);
    my %yamlHash = %$yaml; #bless $yaml, "Hash"
    #print Dump($yamlHash);
    my $yamlVersion = $yamlHash{'version'};
    #print "Version: $yamlVersion\n";
    # The keys are pointers to a list of hashes
    for my $key ( keys %yamlHash ) {
        my $val = $yamlHash{"$key"};
        if($key eq 'files') {
            &files_ops($val);
        }
        elsif($key eq 'packages') {
            &packages_ops($val);
        }
        elsif($key eq 'scripts') {
            &scripts_ops($val);
        }
    }
    print "\n";
}

sub files_ops() {
    my $files_ops_list = $_[0]; 
    foreach my $file_ops_hash (@$files_ops_list) { 
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
                    $before_line = $file_ops_hash->{'after_line'};
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
                die "In YAML, either 'before_line' or 'after_line' may be specified, but not both!";
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
}
sub insert_lines() {
    my $file_path = $_[0];
    my $line_search = $_[1];
    my $after_or_before = $_[2];
    my @nls = @{$_[3]};
    print "Inserting lines into $file_path at line $line_search";
    open my $fh, '<', $file_path or die "Can't open file: $!";
    while ( my $line = <$fh> ) {
        if ( $line =~ m/^\Q$line_search\E/ ) {
            print "Found line!";

        }
    };
    foreach my $nline ( @nls ) {
        print "New line: $nline\n"
    }
}

sub append_lines() {
    my $file_path = $_[0];
    print "Appending lines into $file_path\n"
}

sub packages_ops() {
    print "Packages operations!\n";
}

sub scripts_ops() {

}