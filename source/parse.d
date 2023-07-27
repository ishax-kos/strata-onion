module parse;

import nodes: Module;

import pegged.grammar;

import std.stdio;
import std.format;
import std.algorithm;
import std.array;
import std.conv;

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

Module parse_code(string code) {
    import std.exception: enforce;
    ParseTree gram = Gram(code);
    enforce(gram.successful, gram.to!string);
    return Module.create(gram.children[0]);
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

    Statement_list < "" Statement (Separator Statement)*

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

    Assign < Expression br '=' br Expression


## Control flow

    If_expression < 
        'if' br Expression br Value_scope br 'else' br Value_scope

    If_statement < 
        'if' Expression Statement_block (br 'else' br Statement_block)?

    Loop_statement < 
        'loop' br Statement_block

    Each_expression < 
        'each' br (Prototype_argument_list br)?
            Expression br (Value_scope / Statement_block)


## Declarations
    Define_variable < ';' br Value_name br '=' br Expression
    Define_function <
        / 'fun' 
            br Value_name 
            br Prototype_argument_list 
            br Prototype_argument_list
            br Statement_block
    
    Prototype_argument_list <
        / '(' "" br ')'
        / '(' br Function_parameter (Separator Function_parameter)* br ')'

    Function_parameter < Declare_uninit / Parameter_init / Value_name / Type_name

    Declare_uninit < Value_name br ':' br Type
    Parameter_init < Value_name br '=' br Expression

    Statement_block < '{' br (Statement_list br)? '}'
    Value_scope < '{' br (Expression br)? '}'

## Value expressions
    Expression < _Ex80

    _Ex80 < 
        / Type_annotation(_Ex70)
        / _Ex60
    _Ex70 < 
        / Compare(Type)
        / Compare(_Ex60)
        / _Ex60
    _Ex60 < 
        / Op_and(_Ex20) 
        / Op_or(_Ex20) 
        / Op_xor(_Ex20) 
        / Sum_op(_Ex20)
        / Product_op(_Ex20)
        / _Ex20

    _Ex20 < 
        / Negate(_Ex20)    
        / Invert(_Ex20)    
        / Complement(_Ex20) 
        / _Ex10

    _Ex10 < 
        / Function_call
        / Indexing
        / If_expression
        / Grouping_expression
        / Lit_number 
        / Value_name

    Type_annotation(Ex) < (Type br ':' br)+ Ex
    Op_and(Ex)     < Ex (br '&' br Ex)+
    Op_xor(Ex)     < Ex (br '+|' br Ex)+
    Op_or(Ex)      < Ex (br '|' br Ex)+ 
    Compare(Ex)    < Ex (br (^'<=' / ^'<' / ^'>=' / ^'>' / ^'=' / ^'!=') br Ex)+
    Sum_op(Ex)          < Ex (br '+' br Ex)+
    Product_op(Ex)      < Ex (br '*' br Ex)+
    Negate(Ex)          < '-' br Ex
    Invert(Ex)          < '/' br Ex
    Complement(Ex)      < '!' br Ex
    Try                 < 'try' br Function_call
    Function_call < (Value_name / Grouping_expression) Call_arg_list
    Indexing < (Value_name / Grouping_expression) '[' br Expression br ']'

    
    Grouping_expression < '(' br Expression br ')'

    Call_arg_list < 
        '(' br (
            Expression (Separator Expression)* br / ""
        ) ')'


## Type expressions
    Type <
        / Union_dumb 
        / Union      
        / Struct     
        / Mutable / Immutable
        / Optional / Pointer 
        / Slice_type / Small_array
        / Type_grouping
        / Unit_literal
        / Type_name

    Unit_literal < "Void"

    Type_grouping < '(' br Type br ')'


    Union_dumb < (Union_dumb_field) (br '|' br Union_dumb_field)+
    Union      < Union_field (br '+' br Union_field)+
    Struct     < 
        / Static_array
        / Struct_field (br '*' br Struct_field)+

    Struct_field < Type_name / Declare_uninit
    Union_field < Type_name / Declare_uninit / Value_name
    Union_dumb_field < Type_name / Declare_uninit

    Mutable         < 'mut' br Type
    Immutable       < 'imut' br Type
    Optional        < '?' br Type
    Pointer         < '&' br Type
    Slice_type      < '[' br ']' br Type
    Small_array     < '[' br '$' br Expression br ']' br Type
    Error_capture   < '!' br Type
    
    Static_array < Type br '^' br Expression


## Lexing
    Value_name <~ [a-z] alphanumeric* ('-' alphanumeric+)*
    Type_name  <~ [A-Z] alphanumeric* ('-' alphanumeric+)*
    Lit_number <~ number_dec / number_hex / number_bin


    alphanumeric <- [a-z0-9]

    number_dec <~ [0-9]+
    number_hex <~ '0x' [0-9A-F_]+
    number_bin <~ '0b' [0-1_]+
`));

        // todo Implement what I have as a C transpiler

        // ParseTree child(ParseTree node_) @safe {
        //     ParseTree node = Gram.decimateTree(node_);
        //     switch (node.children.length) {
        //         case 1:
        //             return node.children[0];
        //         default:
        //             writeln(node.name);
        //             return node;
        //     }
        // }
