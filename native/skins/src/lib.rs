extern crate rustler;

use rustler::{Binary, Env, OwnedBinary, Term};

mod skin_render;
mod skin_convert;

fn as_binary<'a>(env: Env<'a>, data: &[u8]) -> Term<'a> {
    let mut erl_bin: OwnedBinary = OwnedBinary::new(data.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(data);
    Binary::from_owned(erl_bin, env).to_term(env)
}

rustler::init!("Elixir.GlobalApi.SkinsNif", [skin_convert::validate_and_get_png]);
