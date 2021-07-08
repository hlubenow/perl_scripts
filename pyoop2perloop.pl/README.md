### pyoop2perloop.py

Perl 5's built-in OOP can be used similar to Python's OOP. Basically, you just have to write more sigils, brackets and so on.

I wrote a [tutorial on how to write that kind of object oriented Perl code](https://hlubenow.lima-city.de/perl2_oop.html). 

When translating Python scripts to Perl in this style, I found, that changes of many code parts could be automated.
So I wrote a (Perl-)script, that reads in a Python-script and changes for example every `self.attribute =` to `$self->{varibable} =` and so on.

Of course, this doesn't lead to a working Perl-script. A lot of things still have to be changed manually afterwards. In detail, the script makes these changes:

- The indentations of the Python-script are kept.
- `class MyObject:` is changed to `package MyObject {`.
- `def __init__(self, a):` is changed to:
```
        sub new {
            my $classname = shift;
            my $self = {}
            $self->{a} = shift;
            return bless($self, $classname);
        }
```
- `def myfunc(self, a):` (a method) is changed to:
```
    sub myfunc {
        my $self = shift;
        my $a = shift;
        $self->{a} = shift;
```
    It's not sure, whether "$a" should be a variable inside the function or an attribute of the class, so both lines are added. One has to be deleted manually lateron.

- `self.myattribute` is changed to `self->{myattribute}`.
- `def myfunc(a, b):` (a stand-alone function) is changed to:
```
    sub myfunc {
        my $a = shift;
        my $b = shift;
```
- `for i in a:` is changed to `for $i (@a) {`.
- `for i in range(len(a)):` is changed to `for $i (0 .. $#a) {`.
- `while x < 5:` is changed to `while (x < 5) {`: Notice, that the `x` is not changed to `$x`.
- `if x == 5:` is changed to `if (x == 5) {`.
- `elif x == 5:` is changed to `elsif (x == 5) {`.
- `else:` is changed to `} else {`.
- Longer strings, written in Python between `"""` are changed to Perl's `my $message = qq( ... );`.
- A semicolon is added to lines that aren't empty, aren't comments and don't end with a comma or a curly bracket.
- The closing curly brackets of blocks (function-, loop-, condition-blocks) are added (that was the trickiest part to write). 

The script reads in code from a given filenmae and prints the result. Usage is:
```
pyoop2perloop.py [pythonscript.py]
```
Output can be piped to an output file using bash's `>` operator.

License: GNU GPL 3 (or above)
