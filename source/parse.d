module parse;

import nodes;

import pegged.grammar;

import std.stdio;
import std.format;
import std.algorithm;
import std.array;

unittest {
    string code = "
        fun main (args []String)() {
            ;my-var = Int|Float do-stuff[
                a, 1, 2 + (2 * 4)
                some-value
                who-needs-separators
            ]
        }
        ;foobar = lol
    ";
    ParseTree gram = parse(code);
    assert(gram.successful, format!"%s\n\n%s"(code, gram));
    
    auto mod = Module(gram.children[0]);
}


Module cement_tree();


ParseTree parse(string code) {
    ParseTree gram = (Gram(code));
    return gram;
}

ParseTree prune_tree(ParseTree node) @safe {
    enum name_prefix = "Gram.";

    node.children = node.children.map!((child) {
        if (child.name.startsWith(name_prefix ~ "_")) {
            // writeln(child.name[name_prefix.length .. $]); 
            child.name = "_";
        }
            return child;}).map!prune_tree.array;
            return node;
        }
        // * Because of how things work, everywhere a non semantic line-break is 
        // * allowed, you need to explicitly declare it with `br`. Just roll with it.

        mixin(grammar(`
Gram:
    File < :(eol*) Statement_list{prune_tree} :(eol*) eoi

    Statement_list < Statement (Separator Statement)*

    # space that can go between statements
    br <- :(eol?)

    Separator <- :(',' / eol+)

    Spacing <- :(' ')*

    
    #Next_statement < eol "Statement"
    #Nl <- '/n' / '/r/n' / '/r'
    
    Statement < 
        / Statement_block 
        / Define_variable 
        / Define_function 
        / Assign 
        / If_statement
        / Loop_statement
        / Expression 

    Assign < Expression br :'=' br Expression


## Control flow

    If_expression < 
        'if' br Expression br Expression_scope br 'else' br Expression_scope

    If_statement < 
        'if' Expression Statement_block (br 'else' br Statement_block)?

    Loop_statement < 
        'loop' br Statement_block

    Each_expression < 
        'each' br (Prototype_argument_list br)?
            Expression br (Expression_scope / Statement_block)


## Declarations
    Define_variable < :';' br name_value br :'=' br Expression
    Define_function <
        / :'fun' 
            br name_value 
            br Prototype_argument_list 
            br Prototype_argument_list 
            br Statement_block
        / :'fun' 
            br name_value 
            br Prototype_argument_list 
            br Expression_scope
    
    Prototype_argument_list <
        / :'(' "" br :')'
        / :'(' br Declare_parameter (Separator Declare_parameter)* br :')'

    Declare_parameter < name_value (br Type_expression / :'=' br Expression)?

    Statement_block < :'{' br (Statement_list br)? :'}'
    Expression_scope < :'{' br (Expression br)? :'}'

## Value expressions
    Expression < _Ex80
    _Ex80 < Type_annotation(_Ex60)    / _Ex60
    _Ex60 < 
        / Logical_and(_Ex20) 
        / Logical_or(_Ex20) 
        / Logical_xor(_Ex20) 
        / Compare_left(_Ex20)
        / Compare_right(_Ex20)
        / Sum_op(_Ex20)
        / Product_op(_Ex20)
            / _Ex20

    _Ex20 < Prefix_op(_Ex10)          / _Ex10
    _Ex10 < 
        / Grouping_expression
        / lit_number 
        / If_expression
        / Function_call
        / name_value

    Type_annotation(Ex) < Type_expression br Ex
    Logical_and(Ex)     < Ex (br '&' br Ex)+
    Logical_or(Ex)      < Ex (br '|' br Ex)+
    Logical_xor(Ex)     < Ex (br '!|' br Ex)+
    Compare_left(Ex)    < Ex (br ('>' / '>=' / '=' / '!=') br Ex)+
    Compare_right(Ex)   < Ex (br ('<' / '<=' / '=' / '!=') br Ex)+
    Sum_op(Ex)          < Ex (br '+' br Ex)+
    Product_op(Ex)      < Ex (br '*' br Ex)+
    Prefix_op(Ex)       < ('-' / '/' / '!') br Ex
    Function_call < (name_value / Grouping_expression) br Call_arg_list
    
    Grouping_expression < :'(' br Expression br :')'

    Call_arg_list < 
        :'[' br (
            Expression (Separator Expression)* br / ""
        ) :']'


## Type expressions
    Type_expression < _Tex50
    _Tex50 < Type_or(_Tex20) / Type_and(_Tex20) / _Tex20
    _Tex20 < Prefixed_type(_Tex10)    / _Tex10
    _Tex10 <
        / Type_grouping
        / name_type

    Type_grouping < :'(' br Type_expression br :')'
    Prefixed_type(Tex) < Type_prefix br Tex
    Type_or(Tex)  < Tex (br :'|' br Tex)+
    Type_and(Tex) < Tex (br :'&' br Tex)+

    Type_prefix <
        / 'imut' / 'mut'
        / '&' / '?' / '!'
        / '[' br ']'
        / '[' br '$' br Expression br ']'

## Lexing
    name_value <~ [a-z] alphanumeric* ('-' alphanumeric+)*
    name_type  <~ [A-Z] alphanumeric* ('-' alphanumeric+)*
    lit_number <~ number_dec / number_hex / number_bin

    alphanumeric <- [a-z0-9]

    number_dec <~ [0-9]+
    number_hex <~ '0x' [0-9A-F_]+
    number_bin <~ '0b' [0-1_]+
`));
        // todo Implement what I have as a C transpiler

        ParseTree child(ParseTree node_) @safe {
            ParseTree node = Gram.decimateTree(node_);
            switch (node.children.length) {
                case 1:
                    return node.children[0];
                default:
                    writeln(node.name);
                    return node;
            }
        }
