import pegged.grammar;

import std.stdio;

void main() {
    // auto gram = _("
    //     foo()
    // ");
    auto gram = _("

        ; foo = F64|I32 23 + 2
        ; bar = foo + 3
        + 5, foo + baz( )
        a = 11
    ");
    writeln(gram);
}

// * Because of how things work, you need to explicitly declare everywhere a 
// * non semantic line-break is allowed. Just roll with it.
mixin(grammar(`
_:
    File < :(eol*) Statement_list :(eol*) eoi

    Statement_list < Statement (Separator Statement)*

    # space that can go between statements
    br <- :(eol?)

    Separator <- :(',' / eol+)

    Spacing <- :(' ')*

    
    #Next_statement < eol "Statement"
    #Nl <- '/n' / '/r/n' / '/r'
    
    Statement < Define_variable / Define_function / Assign / Expression 

    Assign < Expression br :'=' br Expression

## Declarations
    Define_variable < :';' br name_value br :'=' br Expression
    Define_function < Function_prototype br Function_body
    
    Function_prototype < :'fun' br name_value br Prototype_argument_list br Prototype_argument_list
    Prototype_argument_list <
        / :'(' "" br :')'
        / :'(' br Declare_parameter (Separator Declare_parameter)* br :')'
    Function_body < 
        / :'{' br Expression br :'}'
        / :'{' br Statement_list br :'}'
    Declare_parameter < name_value br Type_expression (br :'=' br Expression)?

## Value expressions
    Expression < Ex50
    Ex50 < Type_expression? br Ex40
    Ex40 < Ex30 (br '+' br Ex30)*
    Ex30 < Ex20 (br '*' br Ex20)*
    Ex20 < (('-' / '/') br)? Ex10
    Ex10 < Ex1 (br Call_arg_list)?
    Ex1 < 
        / '(' br Expression br ')' 
        / lit_number 
        / Variable


    Call_arg_list <
        / :'(' "" br :')'
        / :'(' br Expression (Separator Expression)* br :')'


## Type expressions
    Type_expression < Te50
    Te50 < Type (br ('|'/'&') br Type)*
    Te10 < (Type_prefixes br)? Te1
    Te1 < 
        / '(' br Type_expression br ')' 
        / Type

    Type_prefixes < 
        / 'imut' 
        / 'mut' 
        / '&' 
        / '[' br ']'
        / '[' br '$' br Expression br ']'
        / '?'
        / '!'

## Lexing
    Type < name_type
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
