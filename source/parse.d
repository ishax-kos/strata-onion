module parse;


import pegged.grammar;

import std.stdio;
import std.format;
import std.algorithm;
import std.array;

// unittest {
//     import nodes;
//     string code = "
//         fun main (args []String)() {
//             ;my-var = Int|Float do-stuff[
//                 a, 1, 2 + (2 * 4)
//                 some-value
//                 who-needs-separators
//             ]
//         }
//         ;foobar = lol
//     ";
//     ParseTree gram = parse(code);
//     assert(gram.successful, format!"%s\n\n%s"(code, gram));
    
//     auto mod = Module(gram.children[0]);
// }


// Module cement_tree();


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
        / Value_expr 

    Assign < Value_expr br :'=' br Value_expr


## Control flow

    If_expression < 
        'if' br Value_expr br Value_scope br 'else' br Value_scope

    If_statement < 
        'if' Value_expr Statement_block (br 'else' br Statement_block)?

    Loop_statement < 
        'loop' br Statement_block

    Each_expression < 
        'each' br (Prototype_argument_list br)?
            Value_expr br (Value_scope / Statement_block)


## Declarations
    Define_variable < :';' br value_name br :'=' br Value_expr
    Define_function <
        / :'fun' 
            br value_name 
            br Prototype_argument_list 
            (br Prototype_argument_list)?
            br :'{' br (Statement_list br)? :'}'
    
    Prototype_argument_list <
        / :'(' "" br :')'
        / :'(' br Function_parameter (Separator Function_parameter)* br :')'

    Function_parameter < Declare_value | Declare_type

    Declare_value < value_name (br Type_expr / :'=' br Value_expr)?
    Declare_type < type_name (br Type_expr / :'=' br Value_expr)?

    Statement_block < :'{' br (Statement_list br)? :'}'
    Value_scope < :'{' br (Value_expr br)? :'}'

## Value expressions
    Value_expr < _Ex80
    _Ex80 < Type_annotation(_Ex60) / _Ex60
    _Ex60 < 
        / Logical_and(_Ex20) 
        / Logical_or(_Ex20) 
        / Logical_xor(_Ex20) 
        / Compare_left(_Ex20)
        / Compare_right(_Ex20)
        / Sum_op(_Ex20)
        / Product_op(_Ex20)
            / _Ex20

    _Ex20 < Prefix_op(_Ex10) / _Ex10
    _Ex10 < 
        / Grouping_expression
        / lit_number 
        / If_expression
        / Function_call
        / Indexing
        / value_name

    Type_annotation(Ex) < Type_expr br Ex
    Logical_and(Ex)     < Ex (br '&' br Ex)+
    Logical_xor(Ex)     < Ex (br '|+' br Ex)+
    Logical_or(Ex)      < Ex (br '|' br Ex)+
    Compare_left(Ex)    < Ex (br ('>' / '>=' / '=' / '!=') br Ex)+
    Compare_right(Ex)   < Ex (br ('<' / '<=' / '=' / '!=') br Ex)+
    Sum_op(Ex)          < Ex (br '+' br Ex)+
    Product_op(Ex)      < Ex (br '*' br Ex)+
    Prefix_op(Ex)       < ('-' / '/' / '!') br Ex
    Function_call < (value_name / Grouping_expression) Call_arg_list
    Indexing < Value_expr '[' br Value_or_type br ']'

    Value_or_type < Value_expr | Type_expr
    
    Grouping_expression < :'(' br Value_expr br :')'

    Call_arg_list < 
        :'(' br (
            Value_expr (Separator Value_or_type)* br / ""
        ) :')'


## Type expressions
    Type_expr < _Tex20
    _Tex20 < 
        / Mutable(_Tex10) / Immutable(_Tex10)
        / Optional(_Tex10) / Pointer(_Tex10) 
        / Slice_type(_Tex10) / Small_array(_Tex10) / Homo_tuple(_Tex10)
        / _Tex10
    _Tex10 <
        / Type_grouping
        / Unit_literal
        / type_name

    Unit_literal < "Void"

    Type_grouping < :'(' br Type_expr br :')'

    Declare_field < Type_expr
    Union_dumb < Declare_field (br :'|' br Declare_field)+
    Union      < Declare_field (br :'+' br Declare_field)+
    Struct     < Declare_field (br :'*' br Declare_field)+


    Mutable(Tex)    < 'mut' br Tex
    Immutable(Tex)  < 'imut' br Tex
    Optional(Tex)   < '?' br Tex
    Pointer(Tex)    < '&' br Tex
    Slice_type(Tex)     < '[' br ']' br Tex
    Small_array(Tex)    < '[' br '$' br Value_expr br ']' br Tex
    Homo_tuple(Tex)     < Tex br '^' br Value_expr
    Error_capture(Tex)  < '!' br Tex
    

## Lexing
    value_name <~ [a-z] alphanumeric* ('-' alphanumeric+)*
    type_name  <~ [A-Z] alphanumeric* ('-' alphanumeric+)*
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
