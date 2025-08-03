// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           lib.rs
// Description:    About macro
// Create   Date:  2025-05-29 12:37:03
// Last Modified:  2025-05-29 19:52:09
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

extern crate proc_macro;

use proc_macro::TokenStream;
use quote::quote;
use syn::{Data, DeriveInput, Fields};

#[proc_macro_derive(CodeMessage)]
pub fn derive_code_message_derive(item: TokenStream) -> TokenStream {
    let input = syn::parse_macro_input!(item as syn::DeriveInput);
    impl_code_message(&input)
}

fn impl_code_message(ast: &DeriveInput) -> TokenStream {
    let struct_ident = &ast.ident;

    // 将 match_arms 收集到 Vec 中，避免被消耗
    let match_arms_vec = if let Data::Enum(data_enum) = &ast.data {
        data_enum
            .variants
            .iter()
            .map(|variant| {
                let variant_ident = &variant.ident;
                if let Fields::Named(_fields) = &variant.fields {
                    quote! {
                        Self::#variant_ident { code, message, .. } => (*code, message.as_str()),
                    }
                } else {
                    panic!("CodeMessage derive only supports enums with named fields");
                }
            })
            .collect::<Vec<_>>()
    } else {
        panic!("CodeMessage can only be derived for enums");
    };

    let r#gen = quote! {
        impl CodeMessage for #struct_ident {
            fn code(&self) -> i32 {
                let (code, _) = match self {
                    #(#match_arms_vec)*
                };
                code.into()
            }

            fn message(&self) -> &str {
                let (_, message) = match self {
                    #(#match_arms_vec)*
                };
                message
            }
        }
    };

    r#gen.into()
}
