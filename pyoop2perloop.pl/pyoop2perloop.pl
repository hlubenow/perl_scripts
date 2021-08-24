#!/usr/bin/perl

use warnings;
use strict;

=begin comment

    pyoop2perloop.pl 1.1 - Converts a Python-script to a sketch in Perl,
                           that has to be reworked afterwards.

    Copyright (C) 2018, 2021 hlubenow

    This program is free software: you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

=end comment

=cut

my $ONEINDENTLEVEL = 4;

sub stripSpaces {
    my $a = shift;
    my $direction = shift;
    if ($direction eq "l") {
        $a =~ s/ *//;
    } elsif ($direction eq "r") {
        $a =~ s/ *$//;
    }   
    elsif ($direction eq "a" || $direction =~ m/^b/) {
        $a =~ s/ *//;
        $a =~ s/ *$//;
    }   
    return $a; 
}

sub startswith {
    my $a = shift;
    my $b = shift;
    if ($a =~ m/^\Q$b\E/) {
        return 1;
    } else {
        return 0;
    }
}

sub endswith {
    my $a = shift;
    my $b = shift;
    if ($a =~ m/\Q$b\E$/) {
        return 1;
    } else {
        return 0;
    }
}

sub getPythonScriptWithClosingBrackets {
    # This was a tough one. It took me several days to figure it out:
    my @script = @_;
    my $lenscript = @script;
    my ($i, $u, $line, $currentindent);
    my (@onestart, @oneend);
    my @keywords = ("class", "def", "if", "elif", "while", "for");
    my @starts = ();
    my @ends = ();
    my @scriptindents = ();
    for $i (0 .. ($lenscript - 1)) {
        $currentindent = getIndent($script[$i]);
        push(@scriptindents, $currentindent);
        $line = stripSpaces($script[$i], "both");
        for $u (@keywords) {
            if (startswith($line, "$u ")) {
                @onestart = ($currentindent, $i);
                # Can't push the reference to @onestart, must create a copy:
                push(@starts, [$onestart[0], $onestart[1]]); 
            }
        }
    }
    # Every block has one certain line, where it ends. Let's find it:
    for $i (@starts) {
        @oneend = (-1, -1);
        @onestart = @{$i};
        for $u (($onestart[1] + 1) .. ($lenscript - 1)) {
            $currentindent = $scriptindents[$u];
            $line = stripSpaces($script[$u], "both");
            if ($currentindent == 0 && $line eq "") {
                next;
            }
            if ($currentindent <= $onestart[0]) {
                # We want the line before the indentation rebounds:
                @oneend = ($onestart[0], $u - 1);
                last;
            }
        }
        if ($oneend[0] == -1 && $oneend[1] == -1) {
            @oneend = (0, $lenscript -1);
        }
        # Reducing the empty lines after some blocks:
        $line = stripSpaces($script[$oneend[1]], "both");
        while ($oneend[1] >= 0 && $line eq "") {
            $oneend[1]--;
            $line = stripSpaces($script[$oneend[1]], "both");
        }
        push(@ends, [$oneend[0], $oneend[1]]);
    }

    @ends = sort {$b->[0] <=> $a->[0]} @ends;

    my @mscript = ();
    for $i (0 .. $#script) {
        push(@mscript, $script[$i]);
        for $u (@ends) {
            @oneend = @{$u};
            if ($i == $oneend[1]) {
                push(@mscript, " " x $oneend[0] . "}");
            }
        }
    }
    return @mscript;
}

sub getIndent {
    my $a = shift;
    my $i = 0;
    while (substr($a, $i, 1) eq " ") {
        $i++;
    }
    return $i;
}

sub getCondition {
    my $line = shift;
    my $condition = shift;
    $condition .= " ";
    my @a = split(/\Q$condition\E/, $line);
    shift(@a);
    my $a = join($condition, @a);
    @a = split(/:/, $a);
    $a = join(":", @a);
    return $a;
}

sub getForLoop {
    my $line = shift;
    my $i;
    my $c = "for ";
    my @a = split(/$c/, $line);
    shift(@a);
    my $a = join($c, @a);
    @a = split(/:/, $a);
    $a = join(":", @a);
    @a = split(/ in /, $a);
    my %h = (variable => $a[0]);
    shift(@a);
    $a = join(" in ", @a);
    $h{inbrackets} = $a;
    return %h;
}

sub getParameters {
    my $line = shift;
    my $i;
    my @a = split(/def /, $line);
    shift(@a);
    $a = join("def ", @a);
    @a = split(/\(/, $a);
    my $funcname = $a[0];
    shift(@a);
    $a = join("(", @a);
    @a = split(/\)/, $a);
    pop(@a);
    $a = join(")", @a);
    @a = split(/\,/, $a);
    for $i (0 .. $#a) {
        $a[$i] = stripSpaces($a[$i], "b");
    }
    my %h = (funcname =>  $funcname,
             self     =>  0);
    my @b = ();
    $h{parameters} = \@b;
    for $i (@a) {
        if ($i eq "self") {
            $h{self} = 1;
        } else {
            push(@b, $i);
        }
    }
    $h{parameters} = \@b;
    return %h;
}

sub getFirstSelfContent {
    my $line = shift;
    my ($i, $c);
    my $s = "self.";
    my %h = (isFunction => 0);
    my @a = split(/\Q$s\E/, $line);
    shift(@a);
    my $a = join($s, @a);
    my $chars = " ,=):";
    for my $i (0 .. length($chars) - 1) {
        $c = substr($chars, $i, 1); 
        @a = split(/\Q$c\E/, $a);
        $a = $a[0];
    }
    if ($a =~ m/\(/) {
        $h{isFunction} = 1;
    }
    $h{string} = $a;
    return %h;
}

sub replaceSelfs {
    my $a = shift;
    my ($i, $from_, $to_);
    while ($a =~ m/self\./) {
        my %h = getFirstSelfContent($a);
        $from_ = "self." . $h{string};
        $to_   = "\$self->" . $h{string};
        if ($h{isFunction} == 0) {
            $to_   = "\$self->{" . $h{string} . "}";
        }
        $a =~ s/\Q$from_\E/$to_/;
    }
    return $a;
}

sub replaceTripleQuotationMarks {
    my @p = @_;
    my $s = join("\n", @p);
    my $x =  0;

    while ($s =~ /"""/) {
        if ($x % 2) {
            $s =~ s/"""/)/;
        } else {
            $s =~ s/"""/my \$message = qq(/;
        }
        $x++;
    }

    @p = split(/\n/, $s);
    if ($p[$#p] ne "\n") {
        push(@p, "\n");
    }
    return @p;
}

sub createPerlSketchFromPythonScript {
    my @script = @_;
    my ($i, $u, $a, $line, $indent, $condition, $parline);

    # "$linedone == 0" means, the original line of the Python script gets added to
    # the result, keeping the original indentation (= $indent).
    # "$linedone == 1" means, we have completely changed the original Python line, so
    # we don't need it any more in the result.

    my $linedone;

    my $lookForClosingBracketOfInit = 0;
    my (@a, @content, @parameters);
    my %h;
    my @somekeywords = qw(if elif while);
    my $codingfound = 0;

    # @p is the array of the resulting code text:
    my @p = ("#!/usr/bin/perl",
             "",
             "use warnings;",
             "use strict;");

    # It may seem strange, but first we need to get a version of the
    # Python-script, with closing brackets inserted after the code-blocks.
    @script = getPythonScriptWithClosingBrackets(@script);

    for $i (0 .. $#script) {
        $line = stripSpaces($script[$i], "r");
        $indent = getIndent($line);
        $line = stripSpaces($script[$i], "l");
        chomp($line);
        $linedone = 0;

        if ($line =~ m/^\#\!/ || $line =~ m/^import /) {
            $linedone = 1;
        }

        if ($codingfound == 0 && $line =~ m/^\#/ && $line =~ m/coding\:/) {
            $codingfound = 1;
            $linedone = 1;
        }

        if ($lookForClosingBracketOfInit && $line eq "}") {
            push(@p, " " x ($indent + $ONEINDENTLEVEL) . "return bless(\$self, \$classname);");
            $linedone = 0;
            $lookForClosingBracketOfInit = 0;
        }

        $line = replaceSelfs($line);

        if (startswith($line, "class ")) {
            $line =~ s/class/package/;
            $line =~ s/:/ \{/;
            push(@p, $line);
            $linedone = 1;
        }

        if (startswith($line, "def ")) {
            %h = getParameters($line);
            if ($h{funcname} eq "__init__") {
                # The "__init__"-function of a class:
                $h{funcname} = "new";
                @content = (["sub $h{funcname} {", 0],
                            ["my \$classname = shift;", $ONEINDENTLEVEL],
                            ["my \$self = {};", $ONEINDENTLEVEL]);
                @parameters = @{ $h{parameters} };
                for $u (@parameters) {
                    push(@content, ["\$self->{$u} = shift;", $ONEINDENTLEVEL]);
                }
                for $u (@content) {
                    my @u_arr = @{ $u };
                    push(@p, " " x ($indent + $u_arr[1]) . $u_arr[0]);
                }

                # We use "$lookForClosingBracketOfInit" (see above) to add the line
                # "return bless($self, $classname);" and the closing "}" at the end
                # of the "new()"-function:
                $lookForClosingBracketOfInit = 1;

            } else {
                push(@p, " " x $indent . "sub $h{funcname} {");
                @parameters = @{ $h{parameters} };

                if ( $h{self} && $#parameters == -1) {
                    # An ordinary function inside a class with "self" as the only parameter:
                    push(@p, " " x ($indent + $ONEINDENTLEVEL) . "my \$self = shift;");

                } elsif ( $h{self} && $#parameters >= 0) {
                    # A function in a class with several parameters:
                    $parline = " " x ($indent + $ONEINDENTLEVEL);
                    $parline .= "my (\$self, ";
                    for $u (0 .. $#parameters) {
                        $parline .= "\$";
                        $parline .= $parameters[$u];
                        if ($u < $#parameters) {
                            $parline .= ", ";
                        }
                    }
                    $parline .= ") = \@_;";
                    push(@p, $parline);

                } else {
                    # A function outside of a class:
                    for $u (@parameters) {
                        push(@p, " " x ($indent + $ONEINDENTLEVEL) . "my \$$u = shift;");
                    }
                    # Let's have a "my $i;" in there, just in case:
                    push(@p, " " x ($indent + $ONEINDENTLEVEL) . "my \$i;");
                }
            }
            $linedone = 1;
        }

        # if, elif, while:
        for $u (@somekeywords) {
            if (startswith($line, $u)) {
                $condition = getCondition($line, $u);
                if ($u eq "elif") {
                    $u = "elsif";
                }
                push(@p, " " x $indent . "$u ($condition) {");
                $linedone = 1;
            }
        }

        if (startswith($line, "for ")) {
            %h = getForLoop($line);
            my $s = " " x $indent . "for ";
            $s .= "\$" . $h{variable} . " ";
            my $rl = "range(len(";
            if ($h{inbrackets} =~ m/\Q$rl\E/) {
                @a = split(/\Q$rl\E/, $h{inbrackets});
                $a = $a[1];
                @a = split(/\)/, $a);
                $a = $a[0];
                $s .= "(0 .. \$#$a) {";
            } else {
                $s .= "(@" . $h{inbrackets} . ") {";
            }
            push(@p, $s);
            $linedone = 1;
        }

        if (stripSpaces($line, "both") eq "else:") {
            push(@p, " " x $indent . "\} else \{");
            $linedone = 1;
        }

        if ($line ne "" && startswith($line, "#") == 0 &&
            endswith($line, ",") == 0 && endswith($line, "}") == 0 ) {
            $line .= ";";
        }

        if ($linedone == 0) {
            push(@p, " " x $indent . $line);
        }
    }

    @p = replaceTripleQuotationMarks(@p);

    for $i (@p) {
        print "$i\n";
    }
}

# Main:

if ($#ARGV < 0) {
    print "\nUsage: pyoop2perloop.pl [pythonscript.py]\n\n";
    exit 1;
} 

my $fname = $ARGV[0];
chomp($fname);

if ($fname !~ /\.py/) {
    print "\nError: The filename of a Python-script should end with \".py\", shouldn't it?\n";
    print "Nothing done.\n\n";
    exit 2;
}

my $fh;
open($fh, "<", $fname) or die $!; 
my @pythonscript = <$fh>;
close($fh);
chomp(@pythonscript);

createPerlSketchFromPythonScript(@pythonscript);
