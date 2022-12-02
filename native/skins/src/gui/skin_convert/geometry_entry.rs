use std::collections::HashMap;
use std::ops::Mul;

use egui::{Context, Slider, TextureHandle, Window};
use json::JsonValue;

use crate::common::geometry::BoneType;
use crate::common::{OffsetAndDimension, RGBA_CHANNELS};
use crate::common::texture::{scale_and_fill_texture, set_rgb_pixel};
use crate::gui::scale;
use crate::gui::skin_convert::load_texture;

pub struct SkinDebugGeometryEntry {
    name: String,
    short_name: String,
    geometry_entry: String,
    source_image: TextureHandle,
    source_image_highlights: HashMap<usize, TextureHandle>,
    bones: Vec<u8>,
    bone_names: Vec<String>,
    bone_types: Vec<BoneType>,
    bone_geometry: Vec<String>,
    bone_images: HashMap<usize, TextureHandle>,
    selected_bone: i32,
    step_image: HashMap<usize, TextureHandle>,
    image_scale: f32,
    final_image: Option<TextureHandle>
}

impl SkinDebugGeometryEntry {
    pub fn new(
        name: String,
        short_name: String,
        geometry_entry: String,
        source_image: TextureHandle
    ) -> SkinDebugGeometryEntry {
        Self {
            name,
            short_name,
            geometry_entry,
            source_image,
            source_image_highlights: HashMap::new(),
            bones: Vec::new(),
            bone_types: Vec::new(),
            bone_names: Vec::new(),
            bone_geometry: Vec::new(),
            bone_images: HashMap::new(),
            selected_bone: -1,
            step_image: HashMap::new(),
            image_scale: 5.0,
            final_image: None
        }
    }

    pub fn found_bone(&mut self, name: &str, bone_type: BoneType, geometry: &JsonValue) {
        self.bone_names.push(name.to_string());
        self.bone_types.push(bone_type);
        self.bone_geometry.push(geometry.pretty(4));
    }

    pub fn bone_handled(
        &mut self,
        context: &Context,
        name: &str,
        source: &[u8],
        source_width: usize,
        source_section: &OffsetAndDimension,
        step_image: &[u8]
    ) {
        let step_texture = load_texture(context, "step_".to_owned() + name, [64, 64], step_image);

        let mut section_data = vec![0; source_section.width * source_section.height * RGBA_CHANNELS];
        scale_and_fill_texture(
            source, &mut section_data, source_width,
            source_section.width,
            source_section,
            &OffsetAndDimension::new(0, 0, source_section.width, source_section.height)
        );

        let bone_texture = load_texture(
            context,
            "bone_".to_owned() + name, [source_section.width, source_section.height], &section_data
        );


        let mut highlight = Vec::from(source);

        let (w, h, x_offset, y_offset) = (
            source_section.width, source_section.height,
            source_section.x_offset, source_section.y_offset
        );
        let source_height = source.len() / RGBA_CHANNELS / source_width;

        for x in 0..w {
            if y_offset > 0 {
                set_rgb_pixel(&mut highlight, source_width, x_offset + x, y_offset, 255, 0, 0);
            }
            if y_offset + h < source_height {
                set_rgb_pixel(&mut highlight, source_width, x_offset + x, y_offset + h - 1, 255, 0, 0);
            }
        }
        for y in 0..h {
            if x_offset > 0 {
                set_rgb_pixel(&mut highlight, source_width, x_offset, y_offset + y, 255, 0, 0);
            }
            if (x_offset + w - 1) < source_width {
                set_rgb_pixel(&mut highlight, source_width, x_offset + w - 1, y_offset + y, 255, 0, 0);
            }
        }

        let highlight_texture = load_texture(
            context,
            "highlight_".to_owned() + name, [source_width, source_height], &highlight
        );

        let index =
            self.bone_names.iter()
                .position(|s| s.as_str() == name)
                .expect("could not find bone");

        self.step_image.insert(index, step_texture);
        self.bone_images.insert(index, bone_texture);
        self.source_image_highlights.insert(index, highlight_texture);
    }

    pub fn finish_convert(&mut self, context: &Context, final_image: &[u8]) {
        let final_texture = load_texture(context, "final_image", [64, 64], final_image);
        self.final_image = Some(final_texture);
    }

    pub fn short_name(&self) -> String {
        self.short_name.to_string()
    }
}

pub fn update(ctx: &Context, entry: &mut SkinDebugGeometryEntry) {
    Window::new(format!("geometry entry - {:}", entry.short_name)).vscroll(true).show(ctx, |ui| {
        ui.label(&entry.geometry_entry);
    });

    Window::new(format!("source image - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        let image = &entry.source_image;
        ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
    });

    Window::new(format!("converted image - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        if let Some(image) = &entry.final_image {
            ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
        } else {
            ui.label("Please insert client_data first!");
        }
    });

    Window::new(format!("bone names - {}", entry.short_name)).show(ctx, |ui| {
        for (index, bone_name) in entry.bone_names.iter().enumerate() {
            let display_name = format!("{:} ({:?})", bone_name, entry.bone_types.get(index).unwrap());
            let index = index as i32;
            if ui.selectable_label(entry.selected_bone == index, display_name).clicked() {
                entry.selected_bone = index
            }
        }
    });

    Window::new(format!("bone geometry - {}", entry.short_name)).vscroll(true).show(ctx, |ui| {
        if entry.selected_bone == -1 {
            ui.label("Please select a bone first!");
        } else {
            ui.label(entry.bone_geometry.get(entry.selected_bone as usize).unwrap());
        }
    });

    Window::new(format!("after bone (step image) - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        if entry.selected_bone == -1 {
            ui.label("Please select a bone first!");
        } else if let Some(image) = entry.step_image.get(&(entry.selected_bone as usize)) {
            ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
        }
    });

    Window::new(format!("before bone (step image) - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        if entry.selected_bone == -1 {
            ui.label("Please select a bone first!");
        } else if entry.selected_bone == 0 {
            ui.label("There is no bone before the first");
        } else if let Some(image) = entry.step_image.get(&((entry.selected_bone - 1) as usize)) {
            ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
        }
    });

    Window::new(format!("bone image - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        if entry.selected_bone == -1 {
            ui.label("Please select a bone first!");
        } else if let Some(image) = entry.bone_images.get(&(entry.selected_bone as usize)) {
            ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
        }
    });

    Window::new(format!("bone source image - {}", entry.short_name)).show(ctx, |ui| {
        ui.add(Slider::new(&mut entry.image_scale, 1.0..=15.0).text("image scale"));
        if entry.selected_bone == -1 {
            ui.label("Please select a bone first!");
        } else if let Some(image) = entry.source_image_highlights.get(&(entry.selected_bone as usize)) {
            ui.image(image.id(), image.size_vec2().mul(scale(entry.image_scale)));
        }
    });
}