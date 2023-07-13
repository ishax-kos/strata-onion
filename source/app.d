import pegged.grammar;

import std.stdio;

void main() {
    ParseTree gram = Gram("
        fun main (args []String)() {
            ;my-var = Int|Float do-stuff;(
                a, 1, 2 + (2 * 4)
                some-value
                no-commas-at-eol
            )
        }
    ");
    // auto gram = Gram("
    //     2 + (2 * 4)
    // ");
    writeln(gram);
}

// * Because of how things work, you need to explicitly declare everywhere a 
// * non semantic line-break is allowed. Just roll with it.
mixin(grammar(`
Gram:
    File < :(eol*) Statement_list :(eol*) eoi

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
    Expression < Ex80{child}
    Ex80 < Type_annotation(Ex60)    / Ex60{child}
    Ex60 < 
        / Logical_and(Ex20) 
        / Logical_or(Ex20) 
        / Logical_xor(Ex20) 
        / Compare_left(Ex20)
        / Compare_right(Ex20)
        / Sum_op(Ex20)
        / Product_op(Ex20)
            / Ex20{child}

    Ex20 < Prefix_op(Ex10)          / Ex10{child}
    Ex10 < 
        / Grouping_expression
        / lit_number 
        / If_expression
        / Function_call
        / Variable

    Type_annotation(Ex) < Type_expression br Ex{child}
    Logical_and(Ex)     < Ex{child} (br '&' br Ex{child})+
    Logical_or(Ex)      < Ex{child} (br '|' br Ex{child})+
    Logical_xor(Ex)     < Ex{child} (br '!|' br Ex{child})+
    Compare_left(Ex)    < Ex{child} (br ('>' / '>=' / '=' / '!=') br Ex{child})+
    Compare_right(Ex)   < Ex{child} (br ('<' / '<=' / '=' / '!=') br Ex{child})+
    Sum_op(Ex)          < Ex{child} (br '+' br Ex{child})+
    Product_op(Ex)      < Ex{child} (br '*' br Ex{child})+
    Prefix_op(Ex)       < ('-' / '/' / '!') br Ex{child}
    Function_call < (name_value / Grouping_expression) br :';' br Call_arg_list
    
    Grouping_expression < :'(' br Expression br :')'

    Call_arg_list < 
        :'(' br (
            Expression (Separator Expression)* br / ""
        ) :')'


## Type expressions
    Type_expression < Tex50{child}
    Tex50 < Type_or(Tex20) / Type_and(Tex20) / Tex20{child}
    Tex20 < Prefixed_type(Tex10)    / Tex10{child}
    Tex10 <
        / Type_grouping
        / name_type

    Type_grouping < :'(' br Type_expression br :')'
    Prefixed_type(Tex) < Type_prefix br Tex{child}
    Type_or(Tex)  < Tex{child} (br :'|' br Tex{child})+
    Type_and(Tex) < Tex{child} (br :'&' br Tex{child})+

    Type_prefix <
        / 'imut' / 'mut'
        / '&' / '?' / '!'
        / '[' br ']'
        / '[' br '$' br Expression br ']'

## Lexing
    # Type_name < name_type
    Variable < name_value
    
    name_value <~ [a-z] alphanumeric* ('-' alphanumeric+)*
    name_type  <~ [A-Z] alphanumeric* ('-' alphanumeric+)*
    lit_number <~ number_dec / number_hex / number_bin

    alphanumeric <- [a-z0-9]

    number_dec <~ [0-9]+
    number_hex <~ '0x' [0-9A-F_]+
    number_bin <~ '0b' [0-1_]+
`));
// todo Implement what I have as a C transpiler

// auto il = &inline;
ParseTree child(ParseTree node_) @safe {
    // import std.algorithm : map, joiner;
    // import std.array : array;

    ParseTree node = Gram.decimateTree(node_);
    switch (node.children.length) {
        case 1:
            return node.children[0];
        default:
            writeln(node.name);
            return node;
    }
    // tree.children = tree.children.map!((child) {
    //     if (child.name == type_name) {
    //         return child.children;} else {
    //             return [child];}
    //         }).joiner.array;
    //         return tree;
    //     }
}
