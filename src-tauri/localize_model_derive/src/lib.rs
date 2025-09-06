use proc_macro::TokenStream;
use quote::quote;
use syn::{Data, DeriveInput, PathArguments, Type, parse_macro_input};

#[proc_macro_derive(LocalizeModel)]
pub fn derive_localize_model(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = input.ident;

    let fields = match input.data {
        Data::Struct(data) => data.fields,
        _ => panic!("#[derive(LocalizeModel)] only works on structs"),
    };

    let mut assigns = Vec::new();

    for field in fields {
        let field_name = field.ident.unwrap();
        let ty = field.ty;

        let assign = if is_datetime_with_timezone(&ty) {
            // 将 chrono::DateTime<Tz> 转换为 chrono::DateTime<FixedOffset>
            quote! { #field_name: self.#field_name.with_timezone(&tz).fixed_offset() }
        } else if is_option_datetime_with_timezone(&ty) {
            // 处理 Option<DateTimeWithTimeZone>
            quote! { #field_name: self.#field_name.as_ref().map(|dt| dt.with_timezone(&tz).fixed_offset()) }
        } else {
            quote! { #field_name: self.#field_name.clone() }
        };

        assigns.push(assign);
    }

    let expanded = quote! {
        impl LocalizeModel for #name {
            type Output = #name;

            fn to_local_in(&self, tz: chrono_tz::Tz) -> Self::Output {
                #name {
                    #(#assigns, )*
                }
            }
        }
    };

    expanded.into()
}

fn is_datetime_with_timezone(ty: &Type) -> bool {
    matches!(ty, Type::Path(tp) if tp.path.segments.last().unwrap().ident == "DateTimeWithTimeZone")
}

fn is_option_datetime_with_timezone(ty: &Type) -> bool {
    matches!(
        ty,
        Type::Path(tp)
            if tp.path.segments.last().unwrap().ident == "Option"
                && matches!(
                    &tp.path.segments.last().unwrap().arguments,
                    PathArguments::AngleBracketed(args)
                        if matches!(
                            args.args.first(),
                            Some(syn::GenericArgument::Type(Type::Path(inner_tp)))
                                if inner_tp.path.segments.last().unwrap().ident == "DateTimeWithTimeZone"
                        )
                )
    )
}
