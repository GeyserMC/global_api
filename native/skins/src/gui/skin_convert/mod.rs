use std::collections::HashMap;
use std::ops::DerefMut;
use std::sync::{Arc, Mutex};
use egui::{ColorImage, Context, Label, Sense, SidePanel, TextureFilter, TextureHandle, Window};
use json::JsonValue;
use lazy_static::lazy_static;
use serde_json::Value;
use crate::common::geometry::BoneType;
use crate::common::OffsetAndDimension;
use crate::convert_single;
use crate::gui::skin_convert::geometry_entry::{SkinDebugGeometryEntry, update};
use crate::gui::SkinWindowContext;
use crate::skin_convert::skin_codec::SKIN_CHANNELS;

pub mod geometry_entry;

lazy_static! {
    pub static ref INSTANCE: Arc<Mutex<SkinConvertData>> = Arc::new(Mutex::new(SkinConvertData::default()));
}

pub struct SkinConvertData {
    context: Option<Arc<Context>>,
    raw_client_data: String,
    raw_client_data_error: String,
    client_data: Vec<u8>,
    client_claims: Option<String>,
    geometry_data: Option<String>,
    resource_patch: Option<String>,
    current_entry: Option<String>,
    selected_entries: Vec<String>,
    geometry_entries: HashMap<String, SkinDebugGeometryEntry>,
}

impl Default for SkinConvertData {
    fn default() -> Self {
        Self {
            context: None,
            raw_client_data: "".to_string(),
            raw_client_data_error: "".to_string(),
            client_data: Vec::new(),
            client_claims: None,
            geometry_data: None,
            resource_patch: None,
            current_entry: None,
            selected_entries: Vec::new(),
            geometry_entries: HashMap::new(),
        }
    }
}

impl SkinConvertData {
    fn clear(&mut self) {
        self.raw_client_data_error.clear();
        self.client_data.clear();
        self.client_claims = None;
        self.geometry_data = None;
        self.resource_patch = None;
        self.current_entry = None;
        self.selected_entries.clear();
        self.geometry_entries.clear();
    }

    pub fn initialized(&mut self) -> bool {
        self.context.is_some()
    }

    pub fn start_convert(
        &mut self,
        client_claims: &Value,
        geometry_data: &JsonValue,
        resource_patch: &JsonValue
    ) {
        let mut client_claims = client_claims.clone();
        client_claims["SkinData"] = Value::String("see dedicated window".to_string());
        client_claims["SkinGeometryData"] = Value::String("see dedicated window".to_string());
        client_claims["SkinResourcePatch"] = Value::String("see dedicated window".to_string());

        self.client_claims = Some(serde_json::to_string_pretty(&client_claims).unwrap());
        self.geometry_data = Some(geometry_data.pretty(4));
        self.resource_patch = Some(resource_patch.pretty(4));
    }

    pub fn change_geometry_entry(
        &mut self,
        geometry_name: &str,
        geometry_entry: &JsonValue,
        source_image: &[u8],
        image_width: usize
    ) {
        let source_image = self.load_texture(
            "raw_image",
            [image_width, source_image.len() / SKIN_CHANNELS / image_width],
            source_image
        );

        let short_name = char::from('a' as u8 + self.geometry_entries.len() as u8).to_string();

        let entry = SkinDebugGeometryEntry::new(
            geometry_name.to_string(), short_name, geometry_entry.pretty(4), source_image
        );

        self.current_entry = Some(geometry_name.to_string());
        if self.geometry_entries.insert(geometry_name.to_string(), entry).is_some() {
            panic!("got the same geometry ({:}) twice", geometry_name);
        }
    }

    fn get_entry(&mut self) -> &mut SkinDebugGeometryEntry {
        let entry_name = self.current_entry.as_ref().expect("no geometry entry was selected!");
        self.geometry_entries.get_mut(entry_name.as_str()).unwrap()
    }

    pub fn found_bone(&mut self, name: &str, bone_type: BoneType, geometry: &JsonValue) {
        self.get_entry().found_bone(name, bone_type, geometry);
    }

    pub fn bone_handled(&mut self, name: &str, source: &[u8], source_width: usize, source_section: &OffsetAndDimension, step_image: &[u8]) {
        let ctx = self.context.as_ref().unwrap().clone();
        let context = ctx.as_ref();
        self.get_entry().bone_handled(context, name, source, source_width, source_section, step_image);
    }

    pub fn finish_convert(&mut self, final_image: &[u8]) {
        let ctx = self.context.as_ref().unwrap().clone();
        let context = ctx.as_ref();
        self.get_entry().finish_convert(context, final_image);
    }

    pub fn context(&self) -> Arc<Context> {
        self.context.as_ref().unwrap().clone()
    }

    pub fn load_texture(&mut self, name: impl Into<String>, size: [usize; 2], rgba: &[u8]) -> TextureHandle {
        load_texture(self.context().as_ref(), name, size, rgba)
    }
}

pub fn load_texture(context: &Context, name: impl Into<String>, size: [usize; 2], rgba: &[u8]) -> TextureHandle {
    context.load_texture(
        name,
        ColorImage::from_rgba_unmultiplied(size, rgba),
        TextureFilter::Nearest
    )
}

impl SkinWindowContext for SkinConvertData {
    fn update(&mut self, ctx: &Context) {
        let mut guard = INSTANCE.lock().unwrap();

        if guard.context.is_none() {
            guard.context = Some(Arc::new(ctx.to_owned()));
        }

        let client_data: String;
        let mut changed: bool = false;

        {
            let data = guard.deref_mut();
            for s in &data.selected_entries {
                let entry = data.geometry_entries.get_mut(s).unwrap();
                update(data.context.as_ref().unwrap().as_ref(), entry);
            }

            Window::new("client claims").vscroll(true).show(ctx, |ui| {
                if let Some(data) = &data.client_claims {
                    if ui.add(Label::new(data).sense(Sense::click())).clicked() {
                        ui.output().copied_text = data.to_owned();
                    }
                } else {
                    ui.label("Please insert client_data first!");
                }
            });

            Window::new("geometry data").vscroll(true).show(ctx, |ui| {
                if let Some(data) = &data.geometry_data {
                    if ui.add(Label::new(data).sense(Sense::click())).clicked() {
                        ui.output().copied_text = data.to_owned();
                    }
                } else {
                    ui.label("Please insert client_data first!");
                }
            });

            Window::new("selected geometry entries").show(ctx, |ui| {
                for (entry, value) in data.geometry_entries.iter() {
                    let checked = data.selected_entries.contains(entry);
                    if ui.selectable_label(checked, value.short_name() + " - " + entry).clicked() {
                        if checked {
                            data.selected_entries.remove(
                                data.selected_entries.iter().position(|s| s == entry).unwrap()
                            );
                        } else {
                            data.selected_entries.push(entry.clone());
                        }
                    }
                }
            });

            Window::new("resource patch").vscroll(true).show(ctx, |ui| {
                if let Some(data) = &data.resource_patch {
                    if ui.add(Label::new(data).sense(Sense::click())).clicked() {
                        ui.output().copied_text = data.to_owned();
                    }
                } else {
                    ui.label("Please insert client_data first!");
                }
            });

            Window::new("client_data").vscroll(true).show(ctx, |ui| {
                ui.label("Paste the client_data below:");
                if data.raw_client_data_error.is_empty() {
                    ui.label("No errors have been found in the client_data!");
                } else {
                    ui.label("There was an error in the client_data: ".to_owned() + &data.raw_client_data_error);
                }
                changed = ui.code_editor(&mut data.raw_client_data).changed();
            });

            client_data = data.raw_client_data.clone();

            SidePanel::right("window_manager")
                .resizable(false)
                .default_width(150.0)
                .show(ctx, |ui| {
                    ui.vertical_centered(|ui| {
                        ui.heading("Open windows")
                    })
                });
        }

        if !changed {
            return;
        }

        guard.clear();
        drop(guard);

        // can't do this before dropping the guard because otherwise it's still locked
        if let Err(reason) = convert_single(client_data) {
            INSTANCE.lock().unwrap().raw_client_data_error = reason;
        }
    }
}
