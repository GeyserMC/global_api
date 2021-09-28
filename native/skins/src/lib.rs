extern crate rustler;

use rustler::{Env, Term, OwnedBinary, Binary};

mod skin_convert;
mod skin_render;
mod site_preview;

fn as_binary<'a>(env: Env<'a>, data: &[u8]) -> Term<'a> {
    let mut erl_bin: OwnedBinary = OwnedBinary::new(data.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(data);
    Binary::from_owned(erl_bin, env).to_term(env)
}

rustler::init!("Elixir.GlobalApi.SkinsNif", [skin_convert::validate_and_get_png, site_preview::render_link_preview]);
