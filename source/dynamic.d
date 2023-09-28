module dynamic;

import nodes: Expression, Subtypes, Define_function, Statement;
import symbols: Scope;
import internal_type;

import std.algorithm: map;
import std.array: array;
import std.conv: to;
import std.format;



interface Value : Expression {
    /// Class for values that have been resolved
}

// Type as a value
class Type_node: Value {
    Type this_type;
    
    override Type get_type(Scope context) => Type.type_type;
    override string gen_c_expression(Scope context) => "Type_stand_in";
    override Type determine_type(Scope context) => Type.type_type;
    override Value evaluate(Scope context) => this;
}

struct Argument {
    string name;
    Argument_type type;
}
immutable shared anon_name = "ANON";

class Value_func: Value {
    string c_usage() => throw new Error("idk lol");

    string name;
    Argument[] arguments_in;
    Argument[] arguments_out;
    Statement[] block;
    this() {}
    this(Define_function func, Scope context) {
        arguments_in  = func.arguments_in 
            .map!(a => a.as_argument(context)).array;
        arguments_out = func.arguments_out
            .map!(a => a.as_argument(context)).array;
        name = func.name;
    }

    static typeof(this) anon(Define_function func, Scope context) {
        auto ret = new Value_func();
        ret.arguments_in  = func.arguments_in 
            .map!(a => a.as_argument(context)).array;
        ret.arguments_out = func.arguments_out
            .map!(a => a.as_argument(context)).array;
        ret.name = anon_name;
        return ret;
    }

    override Type get_type(Scope context) {
        return Type.func(this);
    }
    override string gen_c_expression(Scope context) => throw new Error("Not yet implemented. Needs to spit out a generated function name.");
    override Type determine_type(Scope context) => Type.func(this);
    override Value evaluate(Scope context) => this;
    Value call(Scope context) => throw new Error("OwO");
}


class Value_int_word : Value {
    long value;
    this(string val) {value = val.to!long;}
    
    override Type get_type(Scope context) => Type.int_word;
    override string gen_c_expression(Scope context) => value.to!string;
    override Type determine_type(Scope context) => Type.int_word;
    override Value evaluate(Scope context) => this;
}

class Value_bool : Value {
    bool value;
    this(string val) {
        if (val == "true") {
            value = true;
        } else
        if (val == "false") {
            value = true;
        } else {
            throw new Error(format!"'%s' is not a valid boolean value."(val));
        }
    }
    this(bool val) {value = val;}
    
    override Type get_type(Scope context) => Type.boolean;
    override string gen_c_expression(Scope context) => 
        (cast(int) value).to!string;
    override Type determine_type(Scope context) => Type.boolean;
    override Value evaluate(Scope context) => this;
}
// class Address_value : Value {
//     Type type = Type.address(Type.unresolved);
//     void* value;
// }



// class Function_value : Value {
//     import std.algorithm: map;
//     import std.array: array;
//     import nodes: Function_parameter;
//     string name;

//     Function_parameter[] inputs;
//     Function_parameter[] outputs;



//     // this(
//     //     Function_parameter[] arguments_in, 
//     //     Function_parameter[] arguments_out
//     // ) {
//     //     input_types  = arguments_in .map!(a => a.get_type).array;
//     //     output_types = arguments_out.map!(a => a.get_type).array;
//     // }
// }



