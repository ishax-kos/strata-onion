module dynamic;

import typechecking;


// private
// enum Dyn_discriminant {
//     unresolved,
//     unit,
//     type_t,
//     int_word,
//     boolean,
//     slice,
//     structure,
//     sumtype,
//     c_union,
// }


// struct Value_dyn {
//     immutable Type type;
    
//     enum types = AliasSeq!(
//         int[0], Discriminant.unit,
//         Type, Discriminant.type_t,
//         long, Discriminant.int_word,
//         bool, Discriminant.boolean,
//         Dyn_value_slice, Discriminant.slice,
//     );
    
// }

// alias Type_set = AliasSeq!(Uninitialized, Int_word, Address, Unit, Type);

interface Value {
    Type type();
}

class Type : Value {
    // Discriminant discriminant = Discriminant.unresolved;
    bool is_const = false;
    
    Type type() => Type.type_t;

    // union {
    //     // Type type_t;
    //     Type_unresolved unresolved_;
    //     // Type_int_word int_word_;
    //     // Type_boolean boolean_;
    //     Type_aggregate structure_;
    //     Type_aggregate sumtype_;
    //     Type_aggregate c_union_;
    // }
    static:
    Type not_checked = new Type(Discriminant.not_checked);
    Type unresolved = new Type(Discriminant.unresolved);
    Type int_word = new Type(Discriminant.int_word);
    Type stand_in = new Type(Discriminant.int_word);
    Type boolean = new Type(Discriminant.boolean);
    Type type_t = new Type(Discriminant.type_t);
    Type func = new Type(Discriminant.func);
    Type unit = new Type(Discriminant.unit);
}

class Type_uchecked: Type {}
class Type_int_word: Type {
    Value_int_word instance(long value) {
        auto ret = new Value_int_word();
        ret.value = value;
        return ret;
    }
    
}
auto type_int_word = new Type_int_word();
class Type_void: Type {}
class Type_boolean: Type {}
class Type_address : Type {
    Type type() => Type.type_t;
}
class Value_address : Type {
    Type type() => value.type();
    Expression value;
}
class Value_int_word : Type {
    Type type() => new Type_int_word();
    long value;
}
class Value_function : Value {
    Type type() => new Type_function(arguments_in, arguments_out);
    SumType!Type_set[] argument_types;
    string[] gen_c_declare();
    
    Function_parameter[] arguments_in;
    Function_parameter[] arguments_out;
    Scope block;
}

class Type_function : Type {
    Type[] input_types;
    Type[] output_types;

    this(
        Function_parameter[] arguments_in, 
        Function_parameter[] arguments_out
    ) {
        input_types  = arguments_in .map!(a => a.type).array;
        output_types = arguments_out.map!(a => a.type).array;
    }
}



// struct Dyn_slice {
//     Type base_type;
//     void* pointer;
//     size_t length;
// }
// struct Dyn_structure {
//     Value_dyn[] field_types;
// }
// struct Dyn_sumtype {
//     // Dyn_discriminant[] option_types;
//     // Value_dyn;
// }
// struct Dyn_cunion {
//     // Dyn_discriminant[] option_types;
//     // Value_dyn;
// }

// fun do-stuff(fishes: Int)(ret: Int) {
//     ret = fishes
// }




// struct Dyn_type_slice  {
//     Type base_type;
// }
// struct Dyn_type_aggregate  {
//     Field[] field_types;
//     struct Field {
//         string name = [];
//         Type type;
//     }
// }
// struct Dyn_type_unresolved {
//     Type* suspect;// = new Type;
//     this(Type t) {
//         import std.algorithm: copy;
//         suspect = new Type;
//         *suspect = t;
//     } 
//     // Discriminant discriminant = Discriminant.unresolved;
// }

// class Type_floating